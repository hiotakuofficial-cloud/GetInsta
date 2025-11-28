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

class ProfessionalVideoPlayer extends StatefulWidget {
  final String videoPath;
  final String? title;

  const ProfessionalVideoPlayer({
    super.key,
    required this.videoPath,
    this.title,
  });

  @override
  State<ProfessionalVideoPlayer> createState() => _ProfessionalVideoPlayerState();
}

class _ProfessionalVideoPlayerState extends State<ProfessionalVideoPlayer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  // Core video controllers
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  
  // Animation controllers
  late AnimationController _controlsAnimationController;
  late AnimationController _fadeAnimationController;
  late AnimationController _scaleAnimationController;
  
  // Animations
  late Animation<double> _controlsOpacity;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  // State management
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isDragging = false;
  
  // Playback state
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _isLooping = false;
  
  // Enhanced features
  double _aspectRatio = 0; // 0=auto, 1=16:9, 2=4:3, 3=fill
  double _zoomLevel = 1.0;
  Offset _panOffset = Offset.zero;
  
  // A-B Loop
  Duration? _pointA;
  Duration? _pointB;
  bool _isABLooping = false;
  
  // System controls
  double _brightness = 0.5;
  double _volume = 0.5;
  bool _showBrightnessOverlay = false;
  bool _showVolumeOverlay = false;
  
  // Timers
  Timer? _hideControlsTimer;
  Timer? _overlayTimer;
  
  // Call handling
  bool _wasPlayingBeforeCall = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializeVideo();
    _loadSystemSettings();
    _setOrientation();
  }

  void _initializeAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _controlsOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _controlsAnimationController.forward();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.file(File(widget.videoPath));
      await _videoController.initialize();
      
      _videoController.addListener(_videoListener);
      
      // Load saved position
      await _loadPlaybackPosition();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        showControls: false,
        allowFullScreen: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF007AFF),
          handleColor: const Color(0xFF007AFF),
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
      );
      
      setState(() {
        _isInitialized = true;
        _duration = _videoController.value.duration;
        _isPlaying = _videoController.value.isPlaying;
      });
      
      _startHideTimer();
    } catch (e) {
      debugPrint('Video initialization error: $e');
    }
  }

  void _videoListener() {
    if (!mounted) return;
    
    final value = _videoController.value;
    setState(() {
      _position = value.position;
      _isPlaying = value.isPlaying;
      _isBuffering = value.isBuffering;
    });
    
    // Auto-save position every 5 seconds
    if (_position.inSeconds % 5 == 0 && _position.inSeconds > 0) {
      _savePlaybackPosition();
    }
    
    // Handle A-B loop
    if (_isABLooping && _pointB != null && _position >= _pointB!) {
      if (_pointA != null) {
        _videoController.seekTo(_pointA!);
      }
    }
  }

  Future<void> _loadSystemSettings() async {
    try {
      _brightness = await ScreenBrightness().current;
      _volume = await VolumeController().getVolume();
      setState(() {});
    } catch (e) {
      debugPrint('System settings error: $e');
    }
  }

  Future<void> _loadPlaybackPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPosition = prefs.getInt('video_${widget.videoPath.hashCode}') ?? 0;
      if (savedPosition > 0) {
        await _videoController.seekTo(Duration(milliseconds: savedPosition));
      }
    } catch (e) {
      debugPrint('Load position error: $e');
    }
  }

  Future<void> _savePlaybackPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'video_${widget.videoPath.hashCode}',
        _position.inMilliseconds,
      );
    } catch (e) {
      debugPrint('Save position error: $e');
    }
  }

  Future<void> _setOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        if (_videoController.value.isPlaying) {
          _wasPlayingBeforeCall = true;
          _videoController.pause();
        }
        break;
      case AppLifecycleState.resumed:
        if (_wasPlayingBeforeCall) {
          _videoController.play();
          _wasPlayingBeforeCall = false;
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialized ? _buildVideoPlayer() : _buildLoadingScreen(),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF007AFF),
              ),
            ),
          ),
          const SizedBox(height: 24),
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
    );
  }

  Widget _buildVideoPlayer() {
    return Stack(
      children: [
        // Video layer
        _buildVideoLayer(),
        
        // Overlay controls
        if (_showBrightnessOverlay) _buildBrightnessOverlay(),
        if (_showVolumeOverlay) _buildVolumeOverlay(),
        
        // Main controls
        AnimatedBuilder(
          animation: _controlsOpacity,
          builder: (context, child) {
            return Opacity(
              opacity: _controlsOpacity.value,
              child: _showControls ? _buildControls() : const SizedBox(),
            );
          },
        ),
        
        // Gesture detector
        _buildGestureLayer(),
      ],
    );
  }

  Widget _buildVideoLayer() {
    return Center(
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
    );
  }

  Widget _buildGestureLayer() {
    return GestureDetector(
      onTap: _toggleControls,
      onDoubleTapDown: _handleDoubleTap,
      onScaleStart: (_) => setState(() => _isDragging = true),
      onScaleUpdate: _handleScaleUpdate,
      onScaleEnd: (_) => setState(() => _isDragging = false),
      onPanUpdate: _zoomLevel > 1.0 ? _handlePan : _handleVerticalPan,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
      ),
    );
  }

  Widget _buildBrightnessOverlay() {
    return Positioned(
      left: 40,
      top: 0,
      bottom: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _showBrightnessOverlay ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 70,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _brightness > 0.7
                      ? Icons.brightness_high_rounded
                      : _brightness > 0.3
                          ? Icons.brightness_medium_rounded
                          : Icons.brightness_low_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    width: 4,
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: Colors.white24,
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor: _brightness,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: const Color(0xFF007AFF),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${(_brightness * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeOverlay() {
    return Positioned(
      right: 40,
      top: 0,
      bottom: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _showVolumeOverlay ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 70,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _volume > 0.5
                      ? Icons.volume_up_rounded
                      : _volume > 0
                          ? Icons.volume_down_rounded
                          : Icons.volume_off_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    width: 4,
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: Colors.white24,
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor: _volume,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: const Color(0xFF007AFF),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${(_volume * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Gesture handlers
  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _controlsAnimationController.forward();
      _startHideTimer();
    } else {
      _controlsAnimationController.reverse();
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;
    
    if (tapX < screenWidth * 0.4) {
      _seekBackward();
    } else if (tapX > screenWidth * 0.6) {
      _seekForward();
    } else {
      _togglePlayPause();
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale != 1.0) {
      setState(() {
        _zoomLevel = (_zoomLevel * details.scale).clamp(1.0, 4.0);
      });
    }
  }

  void _handlePan(DragUpdateDetails details) {
    if (_zoomLevel > 1.0) {
      setState(() {
        _panOffset += details.delta;
      });
    }
  }

  void _handleVerticalPan(DragUpdateDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLeftSide = details.globalPosition.dx < screenWidth / 2;
    final delta = details.delta.dy / 200; // More sensitive
    
    if (isLeftSide) {
      // Brightness control
      setState(() {
        _brightness = (_brightness - delta).clamp(0.0, 1.0);
        _showBrightnessOverlay = true;
      });
      ScreenBrightness().setScreenBrightness(_brightness);
      _fadeAnimationController.forward();
      _startOverlayTimer();
    } else {
      // Volume control - prevent system UI
      setState(() {
        _volume = (_volume - delta).clamp(0.0, 1.0);
        _showVolumeOverlay = true;
      });
      // Use setVolume with showSystemUI: false to prevent system overlay
      VolumeController().setVolume(_volume, showSystemUI: false);
      _fadeAnimationController.forward();
      _startOverlayTimer();
    }
  }

  // Utility methods
  double _getAspectRatio() {
    switch (_aspectRatio.toInt()) {
      case 1: return 16 / 9;
      case 2: return 4 / 3;
      case 3: return MediaQuery.of(context).size.aspectRatio;
      default: return _videoController.value.aspectRatio;
    }
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls && !_isDragging) {
        setState(() => _showControls = false);
        _controlsAnimationController.reverse();
      }
    });
  }

  Widget _buildControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.6),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const Spacer(),
            if (_isBuffering) _buildBufferingIndicator(),
            if (!_isBuffering) _buildCenterControls(),
            const Spacer(),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: _exitPlayer,
          ),
          const SizedBox(width: 16),
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
          _buildIconButton(
            icon: Icons.aspect_ratio_rounded,
            onPressed: _toggleAspectRatio,
            badge: _getAspectRatioText(),
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.speed_rounded,
            onPressed: _changePlaybackSpeed,
            badge: '${_playbackSpeed}x',
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.repeat_rounded,
            onPressed: _toggleLoop,
            isActive: _isLooping,
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          icon: Icons.skip_previous_rounded,
          size: 64,
          onPressed: _previousVideo,
        ),
        const SizedBox(width: 40),
        _buildControlButton(
          icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 80,
          onPressed: _togglePlayPause,
          isPrimary: true,
        ),
        const SizedBox(width: 40),
        _buildControlButton(
          icon: Icons.skip_next_rounded,
          size: 64,
          onPressed: _nextVideo,
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // A-B Loop controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSmallButton('A', _setPointA, isActive: _pointA != null),
              const SizedBox(width: 8),
              _buildSmallButton('B', _setPointB, isActive: _pointB != null),
              const SizedBox(width: 8),
              if (_pointA != null || _pointB != null)
                _buildSmallButton('✕', _clearABLoop),
              const Spacer(),
              _buildIconButton(
                icon: Icons.skip_previous_rounded,
                onPressed: () => _stepFrame(false),
              ),
              const SizedBox(width: 8),
              _buildIconButton(
                icon: Icons.skip_next_rounded,
                onPressed: () => _stepFrame(true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          _buildProgressBar(),
          const SizedBox(height: 8),
          // Time display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_isABLooping)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF007AFF),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'A-B LOOP',
                    style: TextStyle(
                      color: Color(0xFF007AFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(
                  color: Colors.white,
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

  Widget _buildBufferingIndicator() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: const Color(0xFF007AFF),
        inactiveTrackColor: Colors.white24,
        thumbColor: const Color(0xFF007AFF),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        trackHeight: 4,
      ),
      child: Slider(
        value: _duration.inMilliseconds > 0
            ? _position.inMilliseconds / _duration.inMilliseconds
            : 0.0,
        onChanged: _onSeek,
        onChangeStart: (_) => setState(() => _isDragging = true),
        onChangeEnd: (_) => setState(() => _isDragging = false),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? badge,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF007AFF).withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFF007AFF)
                : Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: badge != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 16,
                  ),
                  Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required double size,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isPrimary
              ? const Color(0xFF007AFF).withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(
            color: isPrimary
                ? const Color(0xFF007AFF)
                : Colors.white.withOpacity(0.3),
            width: isPrimary ? 2 : 1,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.4,
        ),
      ),
    );
  }

  // Control functions
  void _togglePlayPause() {
    if (_videoController.value.isPlaying) {
      _videoController.pause();
    } else {
      _videoController.play();
    }
  }

  void _seekBackward() {
    final newPosition = _position - const Duration(seconds: 10);
    _videoController.seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
    _showSeekFeedback('-10s');
  }

  void _seekForward() {
    final newPosition = _position + const Duration(seconds: 10);
    _videoController.seekTo(newPosition < _duration ? newPosition : _duration);
    _showSeekFeedback('+10s');
  }

  void _previousVideo() {
    if (_position.inSeconds > 3) {
      _videoController.seekTo(Duration.zero);
      _showSeekFeedback('Restart');
    } else {
      _showSeekFeedback('Previous');
      // TODO: Implement playlist previous
    }
  }

  void _nextVideo() {
    _videoController.seekTo(_duration);
    _showSeekFeedback('Next');
    // TODO: Implement playlist next
  }

  void _onSeek(double value) {
    final position = Duration(milliseconds: (value * _duration.inMilliseconds).round());
    _videoController.seekTo(position);
  }

  void _toggleAspectRatio() {
    setState(() {
      _aspectRatio = (_aspectRatio + 1) % 4;
    });
  }

  void _changePlaybackSpeed() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentIndex = speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    
    setState(() {
      _playbackSpeed = speeds[nextIndex];
    });
    
    _videoController.setPlaybackSpeed(_playbackSpeed);
  }

  void _toggleLoop() {
    setState(() {
      _isLooping = !_isLooping;
    });
    
    // Recreate controller with new loop setting
    _chewieController?.dispose();
    _chewieController = ChewieController(
      videoPlayerController: _videoController,
      autoPlay: _isPlaying,
      looping: _isLooping,
      showControls: false,
      allowFullScreen: false,
      materialProgressColors: ChewieProgressColors(
        playedColor: const Color(0xFF007AFF),
        handleColor: const Color(0xFF007AFF),
        backgroundColor: Colors.white24,
        bufferedColor: Colors.white38,
      ),
    );
  }

  void _setPointA() {
    setState(() {
      _pointA = _position;
    });
    _showSeekFeedback('Point A Set');
  }

  void _setPointB() {
    setState(() {
      _pointB = _position;
      if (_pointA != null) {
        _isABLooping = true;
      }
    });
    _showSeekFeedback(_pointA != null ? 'A-B Loop Active' : 'Point B Set');
  }

  void _clearABLoop() {
    setState(() {
      _pointA = null;
      _pointB = null;
      _isABLooping = false;
    });
    _showSeekFeedback('A-B Loop Cleared');
  }

  void _stepFrame(bool forward) {
    if (_videoController.value.isPlaying) {
      _videoController.pause();
    }
    
    final frameMs = (1000 / 30).round(); // 30fps
    final newPosition = Duration(
      milliseconds: forward
          ? _position.inMilliseconds + frameMs
          : _position.inMilliseconds - frameMs,
    );
    
    if (newPosition >= Duration.zero && newPosition <= _duration) {
      _videoController.seekTo(newPosition);
    }
  }

  void _showSeekFeedback(String message) {
    // Show feedback overlay
    _scaleAnimationController.forward().then((_) {
      Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          _scaleAnimationController.reverse();
        }
      });
    });
  }

  Future<void> _exitPlayer() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.pop(context);
  }

  // Utility functions
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

  Widget _buildSmallButton(String text, VoidCallback onPressed, {bool isActive = false}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF007AFF).withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? const Color(0xFF007AFF)
                : Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isActive ? const Color(0xFF007AFF) : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _startOverlayTimer() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showBrightnessOverlay = false;
          _showVolumeOverlay = false;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _overlayTimer?.cancel();
    _controlsAnimationController.dispose();
    _fadeAnimationController.dispose();
    _scaleAnimationController.dispose();
    _videoController.removeListener(_videoListener);
    _videoController.dispose();
    _chewieController?.dispose();
    _savePlaybackPosition();
    
    // Reset orientation
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    super.dispose();
  }
}
