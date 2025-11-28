import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:pip_view/pip_view.dart';
import 'dart:io';
import 'dart:async';

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final String? title;

  const VideoPlayerScreen({
    super.key,
    required this.videoPath,
    this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _showControls = true;
  Timer? _hideTimer;
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _initializeSystemControls();
  }

  Future<void> _initializeSystemControls() async {
    try {
      _currentBrightness = await ScreenBrightness().current;
      VolumeController().getVolume().then((volume) {
        _currentVolume = volume;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.file(File(widget.videoPath));
      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControlsOnInitialize: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF6C63FF),
          handleColor: const Color(0xFF6C63FF),
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF6C63FF),
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error playing video',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      setState(() {
        _isLoading = false;
      });

      // Auto-hide controls after 3 seconds
      _startHideTimer();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });
    _startHideTimer();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapPosition = details.globalPosition.dx;
    
    if (tapPosition < screenWidth / 2) {
      // Left side - seek backward 10 seconds
      final currentPosition = _videoPlayerController.value.position;
      final newPosition = currentPosition - const Duration(seconds: 10);
      _videoPlayerController.seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
    } else {
      // Right side - seek forward 10 seconds
      final currentPosition = _videoPlayerController.value.position;
      final duration = _videoPlayerController.value.duration;
      final newPosition = currentPosition + const Duration(seconds: 10);
      _videoPlayerController.seekTo(newPosition < duration ? newPosition : duration);
    }
    _showControlsTemporarily();
  }

  void _handleVerticalDrag(DragUpdateDetails details, bool isLeftSide) async {
    final delta = details.delta.dy;
    
    if (isLeftSide) {
      // Brightness control
      _currentBrightness = (_currentBrightness - delta / 300).clamp(0.0, 1.0);
      try {
        await ScreenBrightness().setScreenBrightness(_currentBrightness);
      } catch (e) {
        // Handle error silently
      }
    } else {
      // Volume control
      _currentVolume = (_currentVolume - delta / 300).clamp(0.0, 1.0);
      try {
        VolumeController().setVolume(_currentVolume);
      } catch (e) {
        // Handle error silently
      }
    }
  }

  void _enterPiPMode() {
    PIPView.of(context)?.presentBelow(
      const VideoPlayerPiPWidget(),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PIPView(
      builder: (context, isFloating) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: _showControls && !isFloating ? AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.title ?? 'Video Player',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
                onPressed: _enterPiPMode,
              ),
            ],
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ) : null,
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF6C63FF),
                  ),
                )
              : _chewieController != null
                  ? GestureDetector(
                      onTap: _showControlsTemporarily,
                      onDoubleTapDown: _handleDoubleTap,
                      onPanUpdate: (details) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final isLeftSide = details.globalPosition.dx < screenWidth / 2;
                        _handleVerticalDrag(details, isLeftSide);
                      },
                      child: Stack(
                        children: [
                          Chewie(controller: _chewieController!),
                          
                          // Brightness/Volume indicators
                          if (_showControls)
                            Positioned(
                              top: 100,
                              left: 20,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.brightness_6, color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(_currentBrightness * 100).round()}%',
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          if (_showControls)
                            Positioned(
                              top: 100,
                              right: 20,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.volume_up, color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(_currentVolume * 100).round()}%',
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 64,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Failed to load video',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
        );
      },
    );
  }
}

class VideoPlayerPiPWidget extends StatelessWidget {
  const VideoPlayerPiPWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'PiP Mode',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
