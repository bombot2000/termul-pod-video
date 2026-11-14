import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../models/pod_media_record.dart';

class MediaPreviewScreen extends StatefulWidget {
  const MediaPreviewScreen({super.key, required this.record});

  final PodMediaRecord record;

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  VideoPlayerController? _videoController;
  Object? _videoError;
  bool _initializingVideo = true;

  bool get _isVideo => widget.record.type == 'video';

  @override
  void initState() {
    super.initState();
    if (_isVideo) _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.file(File(widget.record.path));
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _initializingVideo = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _videoError = error;
        _initializingVideo = false;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_isVideo ? 'Preview Video POD' : 'Preview Foto POD'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _isVideo ? _buildVideo() : _buildPhoto(),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              color: const Color(0xFF151A18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('dd MMM yyyy • HH:mm:ss').format(record.createdAt),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (record.address?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(record.address!, style: const TextStyle(color: Colors.white70)),
                  ],
                  if (record.latitude != null && record.longitude != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '\${record.latitude!.toStringAsFixed(6)}, \${record.longitude!.toStringAsFixed(6)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto() {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 5,
      child: Image.file(
        File(widget.record.path),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _PreviewError(
          message: 'Foto tidak dapat dibuka.',
        ),
      ),
    );
  }

  Widget _buildVideo() {
    if (_initializingVideo) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    if (_videoError != null) {
      return const _PreviewError(message: 'Video tidak dapat diputar.');
    }
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const _PreviewError(message: 'Video tidak tersedia.');
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          const SizedBox(height: 12),
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Color(0xFF65D6B0),
              bufferedColor: Colors.white38,
              backgroundColor: Colors.white24,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, child) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  color: Colors.white,
                  iconSize: 42,
                  onPressed: () => value.isPlaying
                      ? controller.pause()
                      : controller.play(),
                  icon: Icon(value.isPlaying ? Icons.pause_circle : Icons.play_circle),
                ),
                Text(
                  '\${_formatDuration(value.position)} / \${_formatDuration(value.duration)}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      );
