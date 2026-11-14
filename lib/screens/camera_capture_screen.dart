import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pod_media_record.dart';
import '../services/pod_storage_service.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  final PodStorageService _storage = PodStorageService();
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _initializing = true;
  bool _recording = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(controller.dispose());
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw CameraException('NoCamera', 'Kamera tidak ditemukan');
      _cameraIndex = _cameraIndex.clamp(0, _cameras.length - 1).toInt();
      final controller = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _initializing = false);
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = _cameraMessage(error);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'Kamera gagal dibuka: $error';
        });
      }
    }
  }

  String _cameraMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Izin kamera ditolak. Aktifkan izin kamera melalui Pengaturan Android.';
      case 'AudioAccessDenied':
        return 'Izin mikrofon ditolak. Aktifkan izin mikrofon untuk merekam video.';
      default:
        return 'Kamera tidak dapat digunakan (${error.code}).';
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized ||
        controller.value.isTakingPicture || _saving) return;
    setState(() => _saving = true);
    try {
      final capturedAt = DateTime.now();
      final image = await controller.takePicture();
      final record = await _storage.importCapture(
        sourcePath: image.path,
        video: false,
        capturedAt: capturedAt,
      );
      if (!mounted) return;
      _showSaved(record);
    } catch (error) {
      _showError('Foto gagal disimpan: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleVideo() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _saving) return;
    if (!_recording) {
      try {
        await controller.startVideoRecording();
        if (mounted) setState(() => _recording = true);
      } catch (error) {
        _showError('Rekaman video gagal dimulai: $error');
      }
      return;
    }

    setState(() {
      _recording = false;
      _saving = true;
    });
    try {
      final capturedAt = DateTime.now();
      final video = await controller.stopVideoRecording();
      final record = await _storage.importCapture(
        sourcePath: video.path,
        video: true,
        capturedAt: capturedAt,
      );
      if (!mounted) return;
      _showSaved(record);
    } catch (error) {
      _showError('Video gagal disimpan: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSaved(PodMediaRecord record) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(record.isVideo ? 'Video tersimpan di Riwayat' : 'Foto tersimpan di Riwayat')),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _recording || _saving) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    final old = _controller;
    _controller = null;
    await old?.dispose();
    await _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        title: const Text('Kamera POD'),
        actions: [
          IconButton(
            tooltip: 'Ganti kamera',
            onPressed: _switchCamera,
            icon: const Icon(Icons.flip_camera_android),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _initializing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white)),
                        )
                      : controller != null && controller.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: controller.value.aspectRatio,
                              child: CameraPreview(controller),
                            )
                          : const Text('Kamera tidak tersedia',
                              style: TextStyle(color: Colors.white)),
            ),
          ),
          Container(
            color: const Color(0xFF111111),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              children: [
                Text(
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      tooltip: 'Foto',
                      onPressed: _initializing || _error != null || _recording || _saving
                          ? null : _capturePhoto,
                      iconSize: 38,
                      color: Colors.white,
                      icon: const Icon(Icons.camera_alt),
                    ),
                    GestureDetector(
                      onTap: _initializing || _error != null || _saving
                          ? null : _toggleVideo,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Center(
                          child: Container(
                            width: _recording ? 25 : 48,
                            height: _recording ? 25 : 48,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(_recording ? 6 : 30),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Riwayat',
                      onPressed: () => Navigator.pop(context, true),
                      iconSize: 34,
                      color: Colors.white,
                      icon: const Icon(Icons.photo_library_outlined),
                    ),
                  ],
                ),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (_recording)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('MEREKAM VIDEO', style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
