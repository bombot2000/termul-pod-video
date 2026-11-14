import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../models/pod_media_record.dart';
import '../services/location_address_service.dart';
import '../services/pod_location_tracker.dart';
import '../services/photo_watermark_service.dart';
import '../services/video_watermark_service.dart';
import '../services/pod_storage_service.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key, this.initialVideoMode = false});

  final bool initialVideoMode;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _initializing = true;
  bool _recording = false;
  bool _saving = false;
  bool _processingVideo = false;
  double _processingProgress = 0;
  bool _videoMode = false;
  DateTime? _recordingStartedAt;
  String? _error;
  final PodLocationTracker _locationTracker = PodLocationTracker();
  final CachedAddressResolver _addressResolver = CachedAddressResolver();
  Future<PodLocationFix?>? _recordingFix;
  Future<String?>? _recordingAddress;
  bool _appPaused = false;
  bool _startingRecording = false;
  int _cameraInitGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _videoMode = widget.initialVideoMode;
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_appPaused) return;
    final generation = ++_cameraInitGeneration;
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }
    try {
      final cameras = await availableCameras();
      if (!mounted || _appPaused || generation != _cameraInitGeneration) {
        return;
      }
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'Kamera tidak ditemukan.');
      }
      final selected = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.veryHigh,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted || _appPaused || generation != _cameraInitGeneration) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
      // Location is requested only after the camera is up, so the two
      // permission dialogs never stack, and GPS is warm before the shutter.
      unawaited(_locationTracker.start());
    } on CameraException catch (exception) {
      if (mounted && !_appPaused && generation == _cameraInitGeneration) {
        setState(() {
          _error = _cameraErrorMessage(exception);
          _initializing = false;
        });
      }
    } catch (exception) {
      if (mounted && !_appPaused && generation == _cameraInitGeneration) {
        setState(() {
          _error = 'Kamera tidak dapat dibuka: $exception';
          _initializing = false;
        });
      }
    }
  }

  String _cameraErrorMessage(CameraException exception) {
    switch (exception.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Izin kamera ditolak. Aktifkan izin kamera di Pengaturan Android.';
      case 'AudioAccessDenied':
        return 'Izin mikrofon diperlukan untuk merekam video.';
      case 'no_camera':
        return exception.description ?? 'Kamera tidak ditemukan.';
      default:
        return exception.description ??
            'Terjadi masalah saat membuka kamera (${exception.code}).';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android may emit inactive for permission dialogs and the notification
    // shade. Keep the camera alive until the app is actually backgrounded.
    if (state == AppLifecycleState.paused) {
      _appPaused = true;
      // Invalidate any camera initialization still waiting on the plugin.
      // Its eventual result must be disposed rather than attached in background.
      _cameraInitGeneration++;
      _initializing = false;
      unawaited(_locationTracker.stop());
      // Do not dispose a controller while a camera plugin operation or the
      // capture/save pipeline still owns it. The operation releases it later.
      if (_saving || _startingRecording) return;
      final controller = _controller;
      if (_recording && !_saving && controller != null &&
          controller.value.isRecordingVideo) {
        // Stop and persist the active clip before releasing the camera.
        // The helper also handles returning to the foreground mid-save.
        unawaited(_finishRecordingAndReleaseCamera(controller));
        return;
      }
      _controller = null;
      if (controller != null) unawaited(controller.dispose());
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _appPaused = false;
      if (_controller == null && !_initializing && !_saving) {
        unawaited(_initializeCamera());
      }
    }
  }

  Future<void> _finishRecordingAndReleaseCamera(
    CameraController controller,
  ) async {
    await _capture();
    if (!identical(_controller, controller)) return;

    _controller = null;
    await controller.dispose();

    // The app may have resumed while the clip was being finalized. In that
    // case, reopen the camera now instead of leaving the preview permanently
    // blank after the delayed dispose.
    if (mounted && !_appPaused && !_saving) {
      unawaited(_initializeCamera());
    }
  }

  Future<String?> _addressFor(PodLocationFix? fix) async {
    if (fix == null) return null;
    return _addressResolver.resolve(
      latitude: fix.latitude,
      longitude: fix.longitude,
    );
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _saving) {
      return;
    }

    if (_videoMode && !_recording) {
      // Snapshot the position at the moment recording starts. acquire()
      // returns a fresh live fix immediately, or waits briefly in the
      // background while the clip is being recorded.
      final fixFuture = _locationTracker.acquire();
      _startingRecording = true;
      try {
        await controller.startVideoRecording();
        _recordingStartedAt = DateTime.now();
        _recordingFix = fixFuture;
        _recordingAddress = fixFuture.then(_addressFor);
        if (mounted) { setState(() => _recording = true); }
        if (_appPaused) {
          // The pause callback may have arrived while startVideoRecording()
          // was pending. Finalize the clip now that recording has actually
          // started, rather than disposing the active camera underneath it.
          unawaited(_finishRecordingAndReleaseCamera(controller));
        }
      } on CameraException catch (exception) {
        _showMessage(_cameraErrorMessage(exception));
      } finally {
        _startingRecording = false;
        if (_appPaused && !_recording && identical(_controller, controller)) {
          _controller = null;
          await controller.dispose();
        }
      }
      return;
    }

    setState(() => _saving = true);
    String? rawPath;
    try {
      final type = _videoMode ? 'video' : 'photo';
      final capturedAt = type == 'video'
          ? (_recordingStartedAt ?? DateTime.now())
          : DateTime.now();
      final Future<PodLocationFix?> fixFuture;
      final Future<String?> addressFuture;
      final XFile media;
      if (_videoMode) {
        if (!controller.value.isRecordingVideo) {
          if (mounted) { setState(() => _recording = false); }
          return;
        }
        fixFuture = _recordingFix ?? _locationTracker.acquire();
        addressFuture = _recordingAddress ?? fixFuture.then(_addressFor);
        media = await controller.stopVideoRecording();
        _recordingStartedAt = null;
        _recordingFix = null;
        _recordingAddress = null;
        if (mounted) { setState(() => _recording = false); }
      } else {
        // The position and address lookups start at the shutter and run
        // while the picture is being taken, not after it.
        fixFuture = _locationTracker.acquire();
        addressFuture = fixFuture.then(_addressFor);
        media = await controller.takePicture();
      }
      rawPath = media.path;

      final fix = await fixFuture;
      final address = await addressFuture;
      var sourcePath = media.path;
      String? watermarkedPath;
      var watermarkApplied = false;
      if (type == 'photo') {
        try {
          watermarkedPath = await PhotoWatermarkService().createWatermarkedCopy(
            sourcePath: media.path,
            capturedAt: capturedAt,
            latitude: fix?.latitude,
            longitude: fix?.longitude,
            accuracy: fix?.accuracy,
            address: address,
          );
          sourcePath = watermarkedPath;
          watermarkApplied = true;
        } catch (exception) {
          _showMessage(
            'Foto tetap disimpan, tetapi watermark gagal diterapkan: $exception',
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _processingVideo = true;
            _processingProgress = 0;
          });
        }
        try {
          watermarkedPath = await VideoWatermarkService().createWatermarkedCopy(
            sourcePath: media.path,
            capturedAt: capturedAt,
            latitude: fix?.latitude,
            longitude: fix?.longitude,
            accuracy: fix?.accuracy,
            address: address,
            onProgress: (progress) {
              if (mounted) {
                setState(() => _processingProgress = progress);
              }
            },
          );
          sourcePath = watermarkedPath;
          watermarkApplied = true;
        } catch (exception) {
          _showMessage(
            'Video tetap disimpan, tetapi watermark gagal diterapkan: $exception',
          );
        } finally {
          if (mounted) setState(() => _processingVideo = false);
        }
      }

      final PodMediaRecord record;
      try {
        record = await PodStorageService().saveMedia(
          sourcePath: sourcePath,
          type: type,
          createdAt: capturedAt,
          latitude: fix?.latitude,
          longitude: fix?.longitude,
          accuracy: fix?.accuracy,
          address: address,
          watermarkApplied: watermarkApplied,
          locationMocked: fix?.isMocked,
          locationAgeSeconds: fix?.ageSeconds,
          moveSource: true,
        );
      } catch (_) {
        // Remove only the derived file. The raw capture is kept because it
        // may be the only copy if the index could not be written.
        await _deleteQuietly(watermarkedPath);
        rethrow;
      }
      // The saved file was moved or copied; drop whatever is left in cache.
      await _deleteQuietly(watermarkedPath);
      await _deleteQuietly(rawPath);
      if (!mounted) { return; }
      Navigator.of(context).pop<PodMediaRecord>(record);
    } catch (exception) {
      if (_videoMode && mounted && !controller.value.isRecordingVideo) {
        setState(() {
          _recording = false;
          _recordingStartedAt = null;
        });
      }
      _showMessage('Gagal menyimpan dokumentasi: $exception');
    } finally {
      if (mounted) { setState(() => _saving = false); }
      if (_appPaused) {
        // Lifecycle pause deferred disposal while capture/save was in flight.
        // Release only after the media has been safely persisted (or failed).
        final pausedController = _controller;
        _controller = null;
        if (pausedController != null) await pausedController.dispose();
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) { return; }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTracker.dispose();
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_videoMode ? 'Video POD' : 'Foto POD'),
        actions: [
          IconButton(
            tooltip: 'Ganti mode foto/video',
            onPressed: _saving || _recording
                ? null
                : () => setState(() => _videoMode = !_videoMode),
            icon: Icon(_videoMode
                ? Icons.photo_camera_outlined
                : Icons.videocam_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _initializing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : _error != null
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.no_photography_outlined,
                                    color: Colors.white70, size: 52),
                                const SizedBox(height: 12),
                                Text(_error!,
                                    textAlign: TextAlign.center,
                                    style:
                                        const TextStyle(color: Colors.white)),
                                const SizedBox(height: 16),
                                FilledButton(
                                    onPressed: _initializeCamera,
                                    child: const Text('Coba lagi')),
                              ],
                            ),
                          )
                        : controller != null &&
                                controller.value.isInitialized
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  CameraPreview(controller),
                                  Positioned(
                                    left: 16,
                                    right: 16,
                                    bottom: 16,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.58),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const _ClockText(),
                                          ValueListenableBuilder<
                                              PodLocationStatus>(
                                            valueListenable:
                                                _locationTracker.status,
                                            builder: (context, status, _) =>
                                                _GpsStatusLine(status: status),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : const Text('Menyiapkan kamera...',
                                style: TextStyle(color: Colors.white)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_saving)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _processingVideo
                            ? 'Menerapkan watermark video ${(_processingProgress * 100).round()}%'
                            : 'Menyimpan dokumentasi...',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 54),
                  GestureDetector(
                    onTap: _saving ? null : _capture,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 5),
                        color: _recording ? Colors.red : Colors.transparent,
                      ),
                      child: Center(
                        child: _saving
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Icon(
                                _recording
                                    ? Icons.stop
                                    : (_videoMode
                                        ? Icons.fiber_manual_record
                                        : Icons.camera_alt),
                                color: Colors.white,
                                size: 32),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _videoMode ? 'Mode video' : 'Mode foto',
                    onPressed: _saving || _recording
                        ? null
                        : () => setState(() => _videoMode = !_videoMode),
                    icon: Icon(
                        _videoMode ? Icons.videocam : Icons.camera_alt,
                        color: Colors.white,
                        size: 30),
                  ),
                ],
                  ),
                  if (_processingVideo)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SizedBox(
                        width: 220,
                        child: LinearProgressIndicator(value: _processingProgress),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _deleteQuietly(String? path) async {
  if (path == null) return;
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } on FileSystemException {
    // Best effort; the startup sweep removes leftovers later.
  }
}

/// Ticks on its own so the camera preview is not rebuilt every second.
class _ClockText extends StatefulWidget {
  const _ClockText();

  @override
  State<_ClockText> createState() => _ClockTextState();
}

class _ClockTextState extends State<_ClockText> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      DateFormat('dd MMM yyyy  HH:mm:ss').format(_now),
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _GpsStatusLine extends StatelessWidget {
  const _GpsStatusLine({required this.status});

  final PodLocationStatus status;

  @override
  Widget build(BuildContext context) {
    final fix = status.fix;
    final String text;
    final Color color;
    switch (status.state) {
      case PodLocationState.idle:
      case PodLocationState.searching:
        text = 'GPS: mencari sinyal...';
        color = Colors.white70;
      case PodLocationState.serviceDisabled:
        text = 'GPS: layanan lokasi mati. Dokumentasi tanpa koordinat.';
        color = Colors.orangeAccent;
      case PodLocationState.denied:
        text = 'GPS: izin lokasi ditolak. Dokumentasi tanpa koordinat.';
        color = Colors.orangeAccent;
      case PodLocationState.deniedForever:
        text = 'GPS: izin ditolak permanen. Aktifkan di Pengaturan Android.';
        color = Colors.orangeAccent;
      case PodLocationState.ready:
        if (fix == null) {
          text = 'GPS: mencari sinyal...';
          color = Colors.white70;
        } else if (fix.isMocked) {
          text = 'GPS: terindikasi lokasi palsu (mock)';
          color = Colors.redAccent;
        } else if (fix.isPoor) {
          text = 'GPS lemah \u00b1${fix.accuracy.round()} m';
          color = Colors.orangeAccent;
        } else {
          text = 'GPS siap \u00b1${fix.accuracy.round()} m';
          color = const Color(0xFF7DEBC7);
        }
    }
    return Text(text, style: TextStyle(color: color, fontSize: 11));
  }
}
