import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';

class ProfessionalVideoPlayer extends StatefulWidget {
  final String videoPath;
  final String? title;
  final List<String>? playlist;
  final int? currentIndex;

  const ProfessionalVideoPlayer({
    super.key,
    required this.videoPath,
    this.title,
    this.playlist,
    this.currentIndex,
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
  
  // Playlist handling
  List<String> _playlist = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize playlist
    _playlist = widget.playlist ?? [widget.videoPath];
    _currentIndex = widget.currentIndex ?? 0;
    
    _initializeAnimations();
    _initializeVideo();
    _loadSystemSettings();
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
    
    _controlsAnimationController.forward();
  }

  Future<void> _initializeVideo() async {
    try {
      final currentVideoPath = _playlist[_currentIndex];
      _videoController = VideoPlayerController.file(File(currentVideoPath));
      await _videoController.initialize();
      
      // Auto-detect orientation based on aspect ratio
      await _setAutoOrientation();
      
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

  Future<void> _setAutoOrientation() async {
    final aspectRatio = _videoController.value.aspectRatio;
    print('Video aspect ratio: $aspectRatio'); // Debug
    
    if (aspectRatio < 1.0) {
      // Vertical video (9:16, etc.) - Portrait mode
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      print('Set to Portrait mode for vertical video');
    } else {
      // Horizontal video (16:9, etc.) - Landscape mode  
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      print('Set to Landscape mode for horizontal video');
    }
    
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
              color: Colors.white.withValues(alpha: 0.8),
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
        // Video layer with tap detection
        GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.opaque,
          child: _buildVideoLayer(),
        ),
        
        // Overlay controls
        if (_showBrightnessOverlay) _buildBrightnessOverlay(),
        if (_showVolumeOverlay) _buildVolumeOverlay(),
        
        // Main controls - NO GESTURE BLOCKING
        IgnorePointer(
          ignoring: !_showControls,
          child: AnimatedBuilder(
            animation: _controlsOpacity,
            builder: (context, child) {
              return Opacity(
                opacity: _controlsOpacity.value,
                child: _showControls ? _buildControls() : const SizedBox(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoLayer() {
    return Center(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scaleByDouble(_zoomLevel, _zoomLevel, _zoomLevel, 1.0)
          ..translateByDouble(_panOffset.dx / _zoomLevel, _panOffset.dy / _zoomLevel, 0.0, 0.0),
        child: AspectRatio(
          aspectRatio: _getAspectRatio(),
          child: Chewie(controller: _chewieController!),
        ),
      ),
    );
  }

  Widget _buildBrightnessOverlay() {
    return Positioned(
      left: 30,
      top: 100,
      child: AnimatedOpacity(
        opacity: _showBrightnessOverlay ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.brightness_6_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${(_brightness * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeOverlay() {
    return Positioned(
      right: 30,
      top: 100,
      child: AnimatedOpacity(
        opacity: _showVolumeOverlay ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _volume > 0.5
                    ? Icons.volume_up_rounded
                    : _volume > 0
                        ? Icons.volume_down_rounded
                        : Icons.volume_off_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${(_volume * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.6),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: GestureDetector(
                onTap: _toggleControls,
                behavior: HitTestBehavior.translucent,
                child: Center(
                  child: _isBuffering 
                    ? _buildBufferingIndicator()
                    : _buildCenterControls(),
                ),
              ),
            ),
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
        // Previous button - FIXED
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: () {
              print('Previous button clicked!');
              _previousVideo();
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.skip_previous_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
        const SizedBox(width: 40),
        // Play/Pause button - FIXED
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () {
              print('Play/Pause button clicked!');
              _togglePlayPause();
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 50,
              ),
            ),
          ),
        ),
        const SizedBox(width: 40),
        // Next button - FIXED
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: () {
              print('Next button clicked!');
              _nextVideo();
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.skip_next_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
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
                    color: const Color(0xFF007AFF).withValues(alpha: 0.2),
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
        color: Colors.black.withValues(alpha: 0.5),
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
        onChanged: (value) {
          print('Slider changed to: $value');
          _onSeek(value);
        },
        onChangeStart: (_) {
          print('Slider drag started');
          setState(() => _isDragging = true);
        },
        onChangeEnd: (_) {
          print('Slider drag ended');
          setState(() => _isDragging = false);
        },
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? badge,
    bool isActive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          print('Icon button clicked: $icon');
          onPressed();
        },
        child: Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF007AFF).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF007AFF)
                  : Colors.white.withValues(alpha: 0.2),
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
                      size: 14,
                    ),
                    Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Icon(
                  icon,
                  color: Colors.white,
                  size: 18,
                ),
        ),
      ),
    );
  }

  // Control functions - ACTUALLY WORKING
  void _togglePlayPause() {
    setState(() {
      if (_videoController.value.isPlaying) {
        _videoController.pause();
        _isPlaying = false;
      } else {
        _videoController.play();
        _isPlaying = true;
      }
    });
    print('Play/Pause toggled: $_isPlaying'); // Debug
  }

  void _previousVideo() {
    if (_position.inSeconds > 3) {
      // If more than 3 seconds played, restart current video
      _videoController.seekTo(Duration.zero);
      _showSeekFeedback('Restart');
    } else if (_currentIndex > 0) {
      // Go to previous video in playlist
      _currentIndex--;
      _switchToVideo(_currentIndex);
      _showSeekFeedback('Previous Video');
    } else {
      // Already at first video, just restart
      _videoController.seekTo(Duration.zero);
      _showSeekFeedback('First Video');
    }
  }

  void _nextVideo() {
    if (_currentIndex < _playlist.length - 1) {
      // Go to next video in playlist
      _currentIndex++;
      _switchToVideo(_currentIndex);
      _showSeekFeedback('Next Video');
    } else {
      // Already at last video
      _showSeekFeedback('Last Video');
    }
  }

  Future<void> _switchToVideo(int index) async {
    // Dispose current video
    await _videoController.pause();
    _videoController.removeListener(_videoListener);
    await _videoController.dispose();
    _chewieController?.dispose();
    
    setState(() {
      _isInitialized = false;
      _currentIndex = index;
    });
    
    // Initialize new video (will auto-detect orientation)
    await _initializeVideo();
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
    print('Speed changed to: ${_playbackSpeed}x'); // Debug
  }

  void _toggleLoop() {
    setState(() {
      _isLooping = !_isLooping;
    });
    print('Loop toggled: $_isLooping'); // Debug
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          print('Small button clicked: $text');
          onPressed();
        },
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF007AFF).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF007AFF)
                  : Colors.white.withValues(alpha: 0.3),
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
      ),
    );
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
