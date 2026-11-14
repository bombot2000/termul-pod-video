import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../models/pod_media_record.dart';
import '../services/location_address_service.dart';
import '../services/photo_watermark_service.dart';
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
  bool _videoMode = false;
  DateTime? _recordingStartedAt;
  String? _error;
  DateTime _clock = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _videoMode = widget.initialVideoMode;
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) { setState(() => _clock = DateTime.now()); }
    });
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }
    try {
      final cameras = await availableCameras();
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
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } on CameraException catch (exception) {
      if (mounted) {
        setState(() {
          _error = _cameraErrorMessage(exception);
          _initializing = false;
        });
      }
    } catch (exception) {
      if (mounted) {
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
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) { return; }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(controller.dispose());
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<Position?> _readPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) { return null; }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _saving) {
      return;
    }

    if (_videoMode && !_recording) {
      try {
        await controller.startVideoRecording();
        _recordingStartedAt = DateTime.now();
        if (mounted) { setState(() => _recording = true); }
      } on CameraException catch (exception) {
        _showMessage(_cameraErrorMessage(exception));
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final type = _videoMode ? 'video' : 'photo';
      final capturedAt = type == 'video'
          ? (_recordingStartedAt ?? DateTime.now())
          : DateTime.now();
      final XFile media;
      if (_videoMode) {
        if (!controller.value.isRecordingVideo) { return; }
        media = await controller.stopVideoRecording();
        _recordingStartedAt = null;
        if (mounted) { setState(() => _recording = false); }
      } else {
        media = await controller.takePicture();
      }

      final position = await _readPosition();
      final address = position == null
          ? null
          : await LocationAddressService().resolveAddress(
              latitude: position.latitude,
              longitude: position.longitude,
            );
      var sourcePath = media.path;
      String? watermarkedPath;
      var watermarkApplied = false;
      if (type == 'photo') {
        try {
          watermarkedPath = await PhotoWatermarkService().createWatermarkedCopy(
            sourcePath: media.path,
            capturedAt: capturedAt,
            latitude: position?.latitude,
            longitude: position?.longitude,
            accuracy: position?.accuracy,
            address: address,
          );
          sourcePath = watermarkedPath;
          watermarkApplied = true;
        } catch (exception) {
          _showMessage(
            'Foto tetap disimpan, tetapi watermark gagal diterapkan: $exception',
          );
        }
      }

      final PodMediaRecord record;
      try {
        record = await PodStorageService().saveMedia(
          sourcePath: sourcePath,
          type: type,
          createdAt: capturedAt,
          latitude: position?.latitude,
          longitude: position?.longitude,
          accuracy: position?.accuracy,
          address: address,
          watermarkApplied: type == 'photo' ? watermarkApplied : null,
        );
      } finally {
        if (watermarkedPath != null) {
          final temporaryWatermark = File(watermarkedPath);
          if (await temporaryWatermark.exists()) {
            await temporaryWatermark.delete();
          }
        }
      }
      if (!mounted) { return; }
      Navigator.of(context).pop<PodMediaRecord>(record);
    } catch (exception) {
      _showMessage('Gagal menyimpan dokumentasi: $exception');
    } finally {
      if (mounted) { setState(() => _saving = false); }
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
    _clockTimer?.cancel();
    _controller?.dispose();
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
                                          Text(
                                            DateFormat('dd MMM yyyy  HH:mm:ss')
                                                .format(_clock),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700),
                                          ),
                                          const Text(
                                            'TERMUL POD • GPS dicatat saat disimpan',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11),
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
              child: Row(
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
            ),
          ],
        ),
      ),
    );
  }
}
