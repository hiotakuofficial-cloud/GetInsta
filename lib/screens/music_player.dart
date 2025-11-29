import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'dart:async';

class MusicPlayer extends StatefulWidget {
  final String audioPath;
  final String? title;

  const MusicPlayer({
    super.key,
    required this.audioPath,
    this.title,
  });

  @override
  State<MusicPlayer> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Audio player
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  bool _isInitialized = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _positionTimer;
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializeAudioPlayer();
    _initializeNotifications();
    _setPortraitMode();
  }

  void _initializeAnimations() {
    _rotationController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeAudioPlayer() async {
    try {
      // Delay initialization to prevent crashes
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      _audioPlayer = AudioPlayer();
      
      // Simple listeners without complex logic
      _audioPlayer!.onPlayerStateChanged.listen((PlayerState state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
            _isInitialized = true;
          });
        }
      });
      
      _audioPlayer!.onDurationChanged.listen((Duration duration) {
        if (mounted) {
          setState(() {
            _duration = duration;
          });
        }
      });
      
      _audioPlayer!.onPositionChanged.listen((Duration position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });
      
      // Try to play the file
      final file = File(widget.audioPath);
      if (await file.exists()) {
        await _audioPlayer!.play(DeviceFileSource(widget.audioPath));
      }
    } catch (e) {
      print('Audio player error: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true; // Show UI even if audio fails
        });
      }
    }
  }

  void _startPositionTimer() {
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPlaying) {
        _updateNotificationProgress();
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle for background play
    switch (state) {
      case AppLifecycleState.paused:
        // Keep playing in background
        break;
      case AppLifecycleState.resumed:
        // Update UI when app comes back
        break;
      default:
        break;
    }
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/notification');
    const settings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(settings);
  }

  Future<void> _setPortraitMode() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF667eea),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F0F23),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 60),
              _buildAlbumArt(),
              const SizedBox(height: 50),
              _buildSongInfo(),
              const SizedBox(height: 40),
              _buildProgressSection(),
              const SizedBox(height: 50),
              _buildMainControls(),
              const Spacer(),
              _buildSecondaryControls(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _buildGlassButton(
            icon: Icons.keyboard_arrow_down_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          const Text(
            'Now Playing',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          _buildGlassButton(
            icon: Icons.more_vert_rounded,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt() {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationController.value * 2 * 3.14159,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isPlaying ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF667eea),
                        Color(0xFF764ba2),
                        Color(0xFF6B73FF),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.3),
                        blurRadius: 60,
                        spreadRadius: 0,
                        offset: const Offset(0, 30),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      size: 100,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSongInfo() {
    final fileName = widget.audioPath.split('/').last;
    final songName = fileName.replaceAll(RegExp(r'\.[^.]*$'), '');
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            songName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Text(
            'Unknown Artist',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 18,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          GestureDetector(
            onTapDown: (details) {
              // Seek to tapped position
              final RenderBox box = context.findRenderObject() as RenderBox;
              final localPosition = box.globalToLocal(details.globalPosition);
              final progress = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
              final seekPosition = Duration(
                milliseconds: (progress * _duration.inMilliseconds).round(),
              );
              _audioPlayer.seek(seekPosition);
            },
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: Colors.white.withOpacity(0.1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _duration.inMilliseconds > 0
                      ? _position.inMilliseconds / _duration.inMilliseconds
                      : 0.0,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
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

  Widget _buildMainControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          icon: Icons.skip_previous_rounded,
          size: 70,
          onTap: () => print('Previous'),
        ),
        const SizedBox(width: 40),
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF667eea),
                  Color(0xFF764ba2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 0,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 45,
            ),
          ),
        ),
        const SizedBox(width: 40),
        _buildControlButton(
          icon: Icons.skip_next_rounded,
          size: 70,
          onTap: () => print('Next'),
        ),
      ],
    );
  }

  Widget _buildSecondaryControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildGlassButton(icon: Icons.shuffle_rounded, onTap: () {}),
          _buildGlassButton(icon: Icons.favorite_border_rounded, onTap: () {}),
          _buildGlassButton(icon: Icons.repeat_rounded, onTap: () {}),
          _buildGlassButton(icon: Icons.queue_music_rounded, onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.05),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white.withOpacity(0.8),
          size: size * 0.4,
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: Colors.white.withOpacity(0.05),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white.withOpacity(0.7),
          size: 22,
        ),
      ),
    );
  }

  void _togglePlayPause() async {
    if (_audioPlayer == null) return;
    
    try {
      if (_isPlaying) {
        await _audioPlayer!.pause();
      } else {
        await _audioPlayer!.resume();
      }
    } catch (e) {
      print('Playback error: $e');
    }
  }

  Future<void> _showMusicNotification() async {
    try {
      final fileName = widget.audioPath.split('/').last;
      final songName = fileName.replaceAll(RegExp(r'\.[^.]*$'), '');
      
      const androidDetails = AndroidNotificationDetails(
        'music_channel',
        'Music Player',
        channelDescription: 'Music playback controls',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        icon: '@mipmap/notification',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/notification'),
        styleInformation: MediaStyleInformation(
          htmlFormatContent: true,
          htmlFormatTitle: true,
        ),
      );

      final details = NotificationDetails(android: androidDetails);

      await _notifications.show(
        100,
        songName,
        'GetInsta Music Player • Now Playing',
        details,
      );
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  Future<void> _updateNotificationProgress() async {
    try {
      if (_duration.inMilliseconds > 0) {
        final progress = (_position.inMilliseconds / _duration.inMilliseconds * 100).round();
        final fileName = widget.audioPath.split('/').last;
        final songName = fileName.replaceAll(RegExp(r'\.[^.]*$'), '');
        
        final androidDetails = AndroidNotificationDetails(
          'music_channel',
          'Music Player',
          channelDescription: 'Music playback controls',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          showWhen: false,
          showProgress: true,
          maxProgress: 100,
          progress: progress,
          icon: '@mipmap/notification',
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/notification'),
        );

        final details = NotificationDetails(android: androidDetails);

        await _notifications.show(
          100,
          songName,
          '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
          details,
        );
      }
    } catch (e) {
      print('Error updating notification: $e');
    }
  }

  Future<void> _hideMusicNotification() async {
    try {
      await _notifications.cancel(100);
    } catch (e) {
      print('Error hiding notification: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
      _rotationController.dispose();
      _pulseController.dispose();
      _positionTimer?.cancel();
      _audioPlayer?.dispose();
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } catch (e) {
      print('Dispose error: $e');
    }
    super.dispose();
  }
}
