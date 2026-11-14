import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/pod_media_record.dart';

class MediaPreviewScreen extends StatefulWidget {
  const MediaPreviewScreen({required this.record, super.key});

  final PodMediaRecord record;

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  VideoPlayerController? _videoController;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    if (widget.record.isVideo) _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.file(File(widget.record.path));
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(true);
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _videoError = 'Video tidak dapat diputar.');
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
      appBar: AppBar(title: Text(record.isVideo ? 'Video POD' : 'Foto POD')),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: record.isVideo ? _buildVideo() : InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Image.file(File(record.path), fit: BoxFit.contain),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: const Color(0xFF171717),
              padding: const EdgeInsets.all(16),
              child: Text(
                '${record.createdAt.toLocal()}\n${record.path}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    if (_videoError != null) {
      return Text(_videoError!, style: const TextStyle(color: Colors.white));
    }
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        IconButton(
          color: Colors.white,
          iconSize: 42,
          onPressed: () {
            setState(() {
              controller.value.isPlaying ? controller.pause() : controller.play();
            });
          },
          icon: Icon(controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle),
        ),
      ],
    );
  }
}
