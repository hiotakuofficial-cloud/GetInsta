import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui';

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

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  
  // State management
  bool _isLoading = true;
  bool _showControls = true;
  bool _isPlaying = false;
  bool _isBuffering = false;
  
  // Timers and animations
  Timer? _hideTimer;
  late AnimationController _controlsAnimationController;
  late AnimationController _seekAnimationController;
  late Animation<double> _controlsAnimation;
  late Animation<double> _seekAnimation;
  
  // System controls
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  
  // Playback controls
  double _playbackSpeed = 1.0;
  bool _isLooping = false;
  
  // Gesture feedback
  String _seekFeedback = '';
  bool _showSeekFeedback = false;
  
  // Progress tracking
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializePlayer();
    _initializeSystemControls();
    _lockOrientation();
  }

  void _initializeAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _seekAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _controlsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _seekAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _seekAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _controlsAnimationController.forward();
  }

  Future<void> _lockOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  Future<void> _initializeSystemControls() async {
    try {
      _currentBrightness = await ScreenBrightness().current;
      VolumeController().getVolume().then((volume) {
        setState(() {
          _currentVolume = volume;
        });
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.file(File(widget.videoPath));
      await _videoPlayerController.initialize();

      // Listen to player state changes
      _videoPlayerController.addListener(_videoListener);

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: _isLooping,
        allowFullScreen: false, // We handle fullscreen manually
        allowMuting: true,
        allowPlaybackSpeedChanging: false, // We handle speed manually
        showControlsOnInitialize: false,
        showControls: false, // We use custom controls
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.white,
          handleColor: Colors.white,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
        placeholder: _buildLoadingWidget(),
        errorBuilder: (context, errorMessage) => _buildErrorWidget(errorMessage),
      );

      setState(() {
        _isLoading = false;
        _isPlaying = _videoPlayerController.value.isPlaying;
        _totalDuration = _videoPlayerController.value.duration;
      });

      _startHideTimer();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _videoListener() {
    if (mounted) {
      setState(() {
        _isPlaying = _videoPlayerController.value.isPlaying;
        _isBuffering = _videoPlayerController.value.isBuffering;
        _currentPosition = _videoPlayerController.value.position;
      });
    }
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // iOS-style loading animation
            Container(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.8)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading video...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String errorMessage) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.red.withOpacity(0.8),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Unable to play video',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            _buildIOSButton(
              'Try Again',
              onPressed: () => _initializePlayer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSButton(String text, {required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        _hideControls();
      }
    });
  }

  void _showControls() {
    setState(() {
      _showControls = true;
    });
    _controlsAnimationController.forward();
    _startHideTimer();
  }

  void _hideControls() {
    _controlsAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    if (_showControls) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapPosition = details.globalPosition.dx;
    
    if (tapPosition < screenWidth / 2) {
      _seekBackward();
    } else {
      _seekForward();
    }
  }

  void _seekBackward() {
    final currentPosition = _videoPlayerController.value.position;
    final newPosition = currentPosition - const Duration(seconds: 10);
    final seekTo = newPosition > Duration.zero ? newPosition : Duration.zero;
    
    _videoPlayerController.seekTo(seekTo);
    _showSeekFeedback('-10s');
  }

  void _seekForward() {
    final currentPosition = _videoPlayerController.value.position;
    final duration = _videoPlayerController.value.duration;
    final newPosition = currentPosition + const Duration(seconds: 10);
    final seekTo = newPosition < duration ? newPosition : duration;
    
    _videoPlayerController.seekTo(seekTo);
    _showSeekFeedback('+10s');
  }

  void _showSeekFeedback(String feedback) {
    setState(() {
      _seekFeedback = feedback;
      _showSeekFeedback = true;
    });
    
    _seekAnimationController.forward().then((_) {
      Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          _seekAnimationController.reverse().then((_) {
            setState(() {
              _showSeekFeedback = false;
            });
          });
        }
      });
    });
  }

  void _handleVerticalDrag(DragUpdateDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLeftSide = details.globalPosition.dx < screenWidth / 2;
    final delta = details.delta.dy;
    
    if (isLeftSide) {
      // Brightness control
      _currentBrightness = (_currentBrightness - delta / 300).clamp(0.0, 1.0);
      ScreenBrightness().setScreenBrightness(_currentBrightness);
    } else {
      // Volume control
      _currentVolume = (_currentVolume - delta / 300).clamp(0.0, 1.0);
      VolumeController().setVolume(_currentVolume);
    }
    
    setState(() {});
  }

  void _togglePlayPause() {
    if (_videoPlayerController.value.isPlaying) {
      _videoPlayerController.pause();
    } else {
      _videoPlayerController.play();
    }
  }

  void _changePlaybackSpeed() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentIndex = speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    
    setState(() {
      _playbackSpeed = speeds[nextIndex];
    });
    
    _videoPlayerController.setPlaybackSpeed(_playbackSpeed);
  }

  void _toggleLoop() {
    setState(() {
      _isLooping = !_isLooping;
    });
    
    _chewieController?.dispose();
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: _isPlaying,
      looping: _isLooping,
      allowFullScreen: false,
      allowMuting: true,
      allowPlaybackSpeedChanging: false,
      showControlsOnInitialize: false,
      showControls: false,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.white,
        handleColor: Colors.white,
        backgroundColor: Colors.white24,
        bufferedColor: Colors.white38,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _exitPlayer() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
    
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controlsAnimationController.dispose();
    _seekAnimationController.dispose();
    _videoPlayerController.removeListener(_videoListener);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    
    // Reset orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? _buildLoadingWidget()
          : _chewieController != null
              ? _buildVideoPlayer()
              : _buildErrorWidget('Failed to initialize player'),
    );
  }

  Widget _buildVideoPlayer() {
    return GestureDetector(
      onTap: _toggleControls,
      onDoubleTapDown: _handleDoubleTap,
      onPanUpdate: _handleVerticalDrag,
      onVerticalDragEnd: (_) {
        // Swipe down to close
        _exitPlayer();
      },
      child: Stack(
        children: [
          // Video player
          Center(
            child: AspectRatio(
              aspectRatio: _videoPlayerController.value.aspectRatio,
              child: Chewie(controller: _chewieController!),
            ),
          ),
          
          // Seek feedback overlay
          if (_showSeekFeedback)
            Center(
              child: AnimatedBuilder(
                animation: _seekAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _seekAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        _seekFeedback,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          
          // Controls overlay
          AnimatedBuilder(
            animation: _controlsAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _controlsAnimation.value,
                child: _showControls ? _buildControls() : const SizedBox(),
              );
            },
          ),
          
          // System indicators
          _buildSystemIndicators(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top controls
            _buildTopControls(),
            
            const Spacer(),
            
            // Center play/pause
            if (_isBuffering)
              Container(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.8),
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(35),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 35,
                  ),
                ),
              ),
            
            const Spacer(),
            
            // Bottom controls
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: _exitPlayer,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Title
          Expanded(
            child: Text(
              widget.title ?? 'Video Player',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Speed control
          GestureDetector(
            onTap: _changePlaybackSpeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                '${_playbackSpeed}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Loop toggle
          GestureDetector(
            onTap: _toggleLoop,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isLooping 
                    ? Colors.white.withOpacity(0.2)
                    : Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.repeat_rounded,
                color: _isLooping ? Colors.white : Colors.white.withOpacity(0.7),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress bar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              trackHeight: 3,
            ),
            child: Slider(
              value: _totalDuration.inMilliseconds > 0
                  ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
                  : 0.0,
              onChanged: (value) {
                final position = Duration(
                  milliseconds: (value * _totalDuration.inMilliseconds).round(),
                );
                _videoPlayerController.seekTo(position);
              },
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Time indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDuration(_totalDuration),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemIndicators() {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brightness indicator
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.brightness_6_rounded,
                      color: Colors.white.withOpacity(0.8),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${(_currentBrightness * 100).round()}%',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Volume indicator
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _currentVolume > 0.5
                          ? Icons.volume_up_rounded
                          : _currentVolume > 0
                              ? Icons.volume_down_rounded
                              : Icons.volume_off_rounded,
                      color: Colors.white.withOpacity(0.8),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${(_currentVolume * 100).round()}%',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
