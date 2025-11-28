import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'dart:convert';

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
  bool _isMiniPlayer = false;
  
  // Timers and animations
  Timer? _hideTimer;
  late AnimationController _controlsAnimationController;
  late AnimationController _seekAnimationController;
  late Animation<double> _controlsAnimation;
  late Animation<double> _seekAnimation;
  
  // System controls
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  bool _showVolumeSlider = false;
  bool _showBrightnessSlider = false;
  
  // Playback controls
  double _playbackSpeed = 1.0;
  bool _isLooping = false;
  
  // Enhanced features
  double _aspectRatio = 0.0; // 0=original, 1=16:9, 2=4:3, 3=fill
  double _zoomLevel = 1.0;
  Offset _panOffset = Offset.zero;
  Duration? _aPoint;
  Duration? _bPoint;
  bool _isABLooping = false;
  
  // Gesture feedback
  String _seekFeedback = '';
  bool _showSeekFeedback = false;
  
  // Progress tracking
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  
  // Call handling
  bool _wasPlayingBeforeCall = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializePlayer();
    _initializeSystemControls();
    _lockOrientation();
    _setupCallHandling();
    _loadPlaybackHistory();
  }

  void _setupCallHandling() {
    // Listen to app lifecycle changes for call handling
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(
      onPaused: () {
        if (_videoPlayerController.value.isPlaying) {
          _wasPlayingBeforeCall = true;
          _videoPlayerController.pause();
        }
      },
      onResumed: () {
        if (_wasPlayingBeforeCall) {
          _videoPlayerController.play();
          _wasPlayingBeforeCall = false;
        }
      },
    ));
  }

  Future<void> _loadPlaybackHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPosition = prefs.getInt('video_${widget.videoPath.hashCode}') ?? 0;
    if (savedPosition > 0) {
      _videoPlayerController.seekTo(Duration(milliseconds: savedPosition));
    }
  }

  Future<void> _savePlaybackHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'video_${widget.videoPath.hashCode}',
      _currentPosition.inMilliseconds,
    );
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
      
      // Save progress every 5 seconds
      if (_currentPosition.inSeconds % 5 == 0) {
        _savePlaybackHistory();
      }
      
      // Handle A-B loop
      if (_isABLooping && _bPoint != null && _currentPosition >= _bPoint!) {
        if (_aPoint != null) {
          _videoPlayerController.seekTo(_aPoint!);
        }
      }
    }
  }

  // Enhanced controls
  void _toggleAspectRatio() {
    setState(() {
      _aspectRatio = (_aspectRatio + 1) % 4;
    });
  }

  void _setAPoint() {
    setState(() {
      _aPoint = _currentPosition;
    });
    showSeekFeedbackUI('A Point Set');
  }

  void _setBPoint() {
    setState(() {
      _bPoint = _currentPosition;
      if (_aPoint != null) {
        _isABLooping = true;
        showSeekFeedbackUI('A-B Loop Active');
      }
    });
  }

  void _clearABLoop() {
    setState(() {
      _aPoint = null;
      _bPoint = null;
      _isABLooping = false;
    });
    showSeekFeedbackUI('A-B Loop Cleared');
  }

  void _stepFrame(bool forward) {
    if (_videoPlayerController.value.isPlaying) {
      _videoPlayerController.pause();
    }
    
    final currentMs = _currentPosition.inMilliseconds;
    final frameMs = (1000 / 30).round(); // Assuming 30fps
    final newPosition = Duration(
      milliseconds: forward ? currentMs + frameMs : currentMs - frameMs,
    );
    
    if (newPosition >= Duration.zero && newPosition <= _totalDuration) {
      _videoPlayerController.seekTo(newPosition);
    }
  }

  void _toggleMiniPlayer() {
    setState(() {
      _isMiniPlayer = !_isMiniPlayer;
    });
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium iOS-style loading animation
            Container(
              width: 80,
              height: 80,
              child: Stack(
                children: [
                  // Outer ring
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.3),
                      ),
                      value: 1.0,
                    ),
                  ),
                  // Inner animated ring
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Animated dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 600 + (index * 200)),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 17,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
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
            // Premium error icon with glow effect
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.play_disabled_rounded,
                  color: Colors.red.withOpacity(0.9),
                  size: 50,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Unable to play video',
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                errorMessage.length > 100 
                    ? '${errorMessage.substring(0, 100)}...'
                    : errorMessage,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 15,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            // Premium glass button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => _initializePlayer(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          color: Colors.white.withOpacity(0.9),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Try Again',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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

  void showControlsUI() {
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
      showControlsUI();
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
    showSeekFeedbackUI('-10s');
  }

  void _seekForward() {
    final currentPosition = _videoPlayerController.value.position;
    final duration = _videoPlayerController.value.duration;
    final newPosition = currentPosition + const Duration(seconds: 10);
    final seekTo = newPosition < duration ? newPosition : duration;
    
    _videoPlayerController.seekTo(seekTo);
    showSeekFeedbackUI('+10s');
  }

  void showSeekFeedbackUI(String feedback) {
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
      setState(() {
        _showBrightnessSlider = true;
      });
      _hideSlidersAfterDelay();
    } else {
      // Volume control
      _currentVolume = (_currentVolume - delta / 300).clamp(0.0, 1.0);
      VolumeController().setVolume(_currentVolume);
      setState(() {
        _showVolumeSlider = true;
      });
      _hideSlidersAfterDelay();
    }
  }

  void _hideSlidersAfterDelay() {
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showBrightnessSlider = false;
          _showVolumeSlider = false;
        });
      }
    });
  }

  void _handleZoom(ScaleUpdateDetails details) {
    setState(() {
      _zoomLevel = (_zoomLevel * details.scale).clamp(1.0, 4.0);
    });
  }

  void _handlePan(DragUpdateDetails details) {
    if (_zoomLevel > 1.0) {
      setState(() {
        _panOffset += details.delta;
      });
    }
  }

  void _resetZoomPan() {
    setState(() {
      _zoomLevel = 1.0;
      _panOffset = Offset.zero;
    });
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

  Widget _buildSeekFeedback() {
    return Center(
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
    );
  }

  Widget _buildVolumeSlider() {
    return Positioned(
      right: 30,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          height: 200,
          width: 60,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.volume_up_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: RotatedBox(
                  quarterTurns: -1,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white.withOpacity(0.3),
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _currentVolume,
                      onChanged: (value) {
                        setState(() {
                          _currentVolume = value;
                        });
                        VolumeController().setVolume(value);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${(_currentVolume * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrightnessSlider() {
    return Positioned(
      left: 30,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          height: 200,
          width: 60,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.brightness_6_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: RotatedBox(
                  quarterTurns: -1,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white.withOpacity(0.3),
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _currentBrightness,
                      onChanged: (value) {
                        setState(() {
                          _currentBrightness = value;
                        });
                        ScreenBrightness().setScreenBrightness(value);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${(_currentBrightness * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      onPanUpdate: _zoomLevel > 1.0 ? _handlePan : _handleVerticalDrag,
      onVerticalDragEnd: (_) {
        // Swipe down to close only if not zoomed
        if (_zoomLevel <= 1.0) {
          _exitPlayer();
        }
      },
      child: Stack(
        children: [
          // Video player with zoom/pan
          Center(
            child: GestureDetector(
              onScaleUpdate: _handleZoom,
              onDoubleTap: () {
                if (_zoomLevel > 1.0) {
                  _resetZoomPan();
                } else {
                  setState(() {
                    _zoomLevel = 2.0;
                  });
                }
              },
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scale(_zoomLevel)
                  ..translate(_panOffset.dx / _zoomLevel, _panOffset.dy / _zoomLevel),
                child: AspectRatio(
                  aspectRatio: _getAspectRatio(),
                  child: Chewie(controller: _chewieController!),
                ),
              ),
            ),
          ),
          
          // Volume/Brightness Sliders
          if (_showVolumeSlider) _buildVolumeSlider(),
          if (_showBrightnessSlider) _buildBrightnessSlider(),
          
          // Seek feedback overlay
          if (_showSeekFeedback) _buildSeekFeedback(),
          
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

  double _getAspectRatio() {
    switch (_aspectRatio.toInt()) {
      case 1: return 16/9;  // 16:9
      case 2: return 4/3;   // 4:3
      case 3: return MediaQuery.of(context).size.aspectRatio; // Fill
      default: return _videoPlayerController.value.aspectRatio; // Original
    }
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
            
            // Center play/pause with premium design
            if (_isBuffering)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          strokeCap: StrokeCap.round,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
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
          
          // Aspect ratio toggle
          GestureDetector(
            onTap: _toggleAspectRatio,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                _getAspectRatioText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Speed control with premium design
          GestureDetector(
            onTap: _changePlaybackSpeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${_playbackSpeed}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Loop toggle with premium design
          GestureDetector(
            onTap: _toggleLoop,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: _isLooping 
                    ? LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.3),
                          Colors.white.withOpacity(0.2),
                        ],
                      )
                    : LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _isLooping 
                      ? Colors.white.withOpacity(0.5)
                      : Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.repeat_rounded,
                color: _isLooping ? Colors.white : Colors.white.withOpacity(0.8),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getAspectRatioText() {
    switch (_aspectRatio.toInt()) {
      case 1: return '16:9';
      case 2: return '4:3';
      case 3: return 'FILL';
      default: return 'AUTO';
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress bar with premium iOS design
          Container(
            height: 40,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withOpacity(0.25),
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                overlayColor: Colors.white.withOpacity(0.2),
                trackHeight: 4,
                activeTickMarkColor: Colors.transparent,
                inactiveTickMarkColor: Colors.transparent,
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

// Call handling observer
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onPaused;
  final VoidCallback onResumed;

  _AppLifecycleObserver({required this.onPaused, required this.onResumed});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        onPaused();
        break;
      case AppLifecycleState.resumed:
        onResumed();
        break;
      default:
        break;
    }
  }
}
