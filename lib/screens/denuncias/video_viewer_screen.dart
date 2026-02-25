import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import '../../settings/session.dart';

class VideoViewerScreen extends StatefulWidget {
  final String url;
  const VideoViewerScreen({super.key, required this.url});

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  static const Color primaryBlue = Color(0xFF2C64C4);

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final token = await Session.access();
      final headers = <String, String>{};
      if (token != null && token.trim().isNotEmpty) {
        headers["Authorization"] = "Bearer $token";
      }

      final vc = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: headers, // ✅ JWT para BIN protegido
      );

      await vc.initialize();

      final cc = ChewieController(
        videoPlayerController: vc,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: primaryBlue,
          handleColor: primaryBlue,
        ),
      );

      if (!mounted) return;
      setState(() {
        _videoController = vc;
        _chewieController = cc;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Video evidencia",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryBlue,
        elevation: 0,
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : (_error != null)
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "No se pudo reproducir el video:\n$_error",
                  textAlign: TextAlign.center,
                ),
              )
            : AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: Chewie(controller: _chewieController!),
              ),
      ),
    );
  }
}
