import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../widgets/modern_components.dart';
import '../utils/error_handler.dart';
import '../utils/animations.dart';
import '../services/instagram_handler.dart';
import '../services/notification_service.dart';
import '../services/download_history.dart';
import '../services/instagram_cache.dart';
import '../services/youtube_pinterest_handler.dart';
import 'history_screen.dart';
import 'professional_video_player.dart';
import 'dart:io';

class EnhancedHomeScreen extends StatefulWidget {
  const EnhancedHomeScreen({super.key});

  @override
  State<EnhancedHomeScreen> createState() => _EnhancedHomeScreenState();
}

class _EnhancedHomeScreenState extends State<EnhancedHomeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _pulseController;
  late AnimationController _searchBarController;

  bool _isLoading = false;
  bool _hasText = false;
  bool _isQuickAction = false;
  List<Map<String, dynamic>> _cachedPosts = [];
  List<Map<String, dynamic>> _recentDownloads = [];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _searchBarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _searchController.addListener(() {
      setState(() => _hasText = _searchController.text.isNotEmpty);
    });

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await NotificationService.initialize();
    await _requestPermissions();
    await _loadCachedPosts();
    await _loadRecentDownloads();
  }

  Future<void> _requestPermissions() async {
    if (await Permission.manageExternalStorage.isGranted) return;

    final statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.notification,
    ].request();

    if (statuses[Permission.storage] == PermissionStatus.denied ||
        statuses[Permission.manageExternalStorage] == PermissionStatus.denied) {
      if (mounted) {
        final error = AppError(
          type: ErrorType.permissionDenied,
          message: 'Storage permission required',
        );
        ErrorHandler.showErrorDialog(
          context,
          error,
          onRetry: openAppSettings,
        );
      }
    }
  }

  Future<void> _loadCachedPosts() async {
    try {
      final cached = await InstagramCache.getCache();
      if (mounted) {
        setState(() => _cachedPosts = cached);
      }
    } catch (e) {
      debugPrint('Error loading cache: $e');
    }
  }

  Future<void> _loadRecentDownloads() async {
    try {
      final downloads = await DownloadHistory.getRecentDownloads(limit: 5);
      if (mounted) {
        setState(() => _recentDownloads = downloads);
      }
    } catch (e) {
      debugPrint('Error loading downloads: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pulseController.dispose();
    _searchBarController.dispose();
    super.dispose();
  }

  Future<void> _onPastePressed() async {
    if (_hasText) {
      _processUrl(_searchController.text, isQuickAction: false);
    } else {
      try {
        ClipboardData? data = await Clipboard.getData('text/plain');
        if (data?.text != null) {
          _searchController.text = data!.text!;
          _searchBarController.forward().then((_) => _searchBarController.reverse());
          await Future.delayed(const Duration(milliseconds: 300));
          _processUrl(data.text!, isQuickAction: true);
        }
      } catch (e) {
        if (mounted) {
          final error = ErrorHandler.handleError(e);
          ErrorHandler.showErrorSnackbar(context, error);
        }
      }
    }
  }

  Future<void> _processUrl(String url, {required bool isQuickAction}) async {
    _isQuickAction = isQuickAction;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (mounted) {
        final error = AppError(
          type: ErrorType.network,
          message: 'No internet connection',
        );
        ErrorHandler.showCustomErrorOverlay(context, error);
      }
      return;
    }

    if (YouTubePinterestHandler.isYouTubeUrl(url)) {
      await _processYouTube(url);
      return;
    }

    if (YouTubePinterestHandler.isPinterestUrl(url)) {
      await _processPinterest(url);
      return;
    }

    if (!InstagramHandler.isValidInstagramUrl(url)) {
      if (mounted) {
        final error = AppError(
          type: ErrorType.invalidUrl,
          message: 'Invalid URL format',
          details: 'Please enter a valid Instagram, YouTube, or Pinterest URL',
        );
        ErrorHandler.showErrorSnackbar(context, error);
      }
      return;
    }

    await _processInstagram(url);
  }

  Future<void> _processInstagram(String url) async {
    setState(() => _isLoading = true);

    final result = await SafeOperation.execute(
      operation: () => withRetry(
        operation: () => InstagramHandler.processUrl(url),
        maxAttempts: 3,
      ),
      context: context,
      showErrorDialog: true,
      onError: () => setState(() => _isLoading = false),
    );

    setState(() => _isLoading = false);

    if (result != null && result['success'] == true) {
      final cacheData = Map<String, dynamic>.from(result);
      cacheData['url'] = url;
      await InstagramCache.addToCache(cacheData);
      await _loadCachedPosts();

      if (mounted) {
        _showMediaBottomSheet(result);
      }
    }
  }

  Future<void> _processYouTube(String url) async {
    setState(() => _isLoading = true);

    try {
      if (_isQuickAction) {
        final result = await YouTubePinterestHandler.quickDownloadYouTube(url);
        if (result['success'] == true) {
          await InstagramHandler.downloadMedia(
            result['downloadUrl'],
            result['filename'],
            username: 'YouTube',
            caption: result['filename'],
          );
        }
      } else {
        final result = await YouTubePinterestHandler.getYouTubeInfo(url);
        if (result['success'] == true && mounted) {
          _showYouTubeOptions(result['data'], url);
        }
      }
    } catch (e) {
      if (mounted) {
        final error = ErrorHandler.handleError(e);
        ErrorHandler.showErrorDialog(context, error);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processPinterest(String url) async {
    setState(() => _isLoading = true);

    try {
      final result = await YouTubePinterestHandler.quickDownloadPinterest(url);
      if (result['success'] == true) {
        await InstagramHandler.downloadMedia(
          result['downloadUrl'],
          result['filename'],
          thumbnailUrl: result['thumbnail'],
          username: 'Pinterest',
          caption: result['title'],
        );
      }
    } catch (e) {
      if (mounted) {
        final error = ErrorHandler.handleError(e);
        ErrorHandler.showErrorDialog(context, error);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMediaBottomSheet(Map<String, dynamic> result) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 24),

            if (result['thumbnail'] != null && result['thumbnail'].isNotEmpty)
              GlassmorphicCard(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    result['thumbnail'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            Row(
              children: [
                Icon(
                  result['contentType'] == 'reel'
                      ? Icons.play_circle_rounded
                      : Icons.photo_library_rounded,
                  color: const Color(0xFF6C63FF),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${result['username']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${result['mediaCount']} ${result['mediaCount'] == 1 ? 'item' : 'items'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AnimatedGradientButton(
                    text: 'Download',
                    icon: Icons.download_rounded,
                    onPressed: () {
                      Navigator.pop(context);
                      _startDownload(result);
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
          ],
        ),
      ),
    );
  }

  void _showYouTubeOptions(Map<String, dynamic> data, String url) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              data['title'] ?? 'YouTube Video',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'AUDIO',
                        style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedGradientButton(
                        text: '128kbps',
                        gradientColors: const [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadYouTubeAudio(url, '128');
                        },
                      ),
                      const SizedBox(height: 8),
                      AnimatedGradientButton(
                        text: '320kbps',
                        gradientColors: const [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadYouTubeAudio(url, '320');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'VIDEO',
                        style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedGradientButton(
                        text: '720p',
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadYouTubeVideo(url, '720');
                        },
                      ),
                      const SizedBox(height: 8),
                      AnimatedGradientButton(
                        text: '480p',
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadYouTubeVideo(url, '480');
                        },
                      ),
                      const SizedBox(height: 8),
                      AnimatedGradientButton(
                        text: '360p',
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadYouTubeVideo(url, '360');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
          ],
        ),
      ),
    );
  }

  Future<void> _startDownload(Map<String, dynamic> result) async {
    if (result['mediaItems'] == null) return;

    final mediaItems = result['mediaItems'] as List<dynamic>;
    for (var item in mediaItems) {
      await SafeOperation.execute(
        operation: () => InstagramHandler.downloadMedia(
          item['url'],
          item['filename'],
          thumbnailUrl: result['thumbnail'],
          username: result['username'],
          caption: result['caption'],
        ),
        context: context,
        showErrorDialog: false,
      );
    }
  }

  Future<void> _downloadYouTubeAudio(String url, String quality) async {
    await SafeOperation.execute(
      operation: () async {
        final result = await YouTubePinterestHandler.downloadYouTubeAudio(url, quality);
        if (result['success'] == true) {
          await InstagramHandler.downloadMedia(
            result['downloadUrl'],
            result['filename'],
            username: 'YouTube',
            caption: result['filename'],
          );
        }
        return result;
      },
      context: context,
      showErrorDialog: true,
    );
  }

  Future<void> _downloadYouTubeVideo(String url, String quality) async {
    await SafeOperation.execute(
      operation: () async {
        final result = await YouTubePinterestHandler.downloadYouTubeVideo(url, quality);
        if (result['success'] == true) {
          await InstagramHandler.downloadMedia(
            result['downloadUrl'],
            result['filename'],
            username: 'YouTube',
            caption: result['filename'],
          );
        }
        return result;
      },
      context: context,
      showErrorDialog: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await _loadCachedPosts();
              await _loadRecentDownloads();
            },
            color: const Color(0xFF6C63FF),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 40),
                    _buildSearchBar(),
                    const SizedBox(height: 30),
                    if (_cachedPosts.isEmpty)
                      _buildEmptyState()
                    else
                      _buildCachedPosts(),
                    const SizedBox(height: 30),
                    if (_recentDownloads.isNotEmpty) _buildRecentDownloads(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Powered by Nehu',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.3),
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButtonExtended(
        text: 'History',
        icon: Icons.history_rounded,
        onPressed: () {
          Navigator.push(
            context,
            CustomPageRoute(
              child: const HistoryScreen(),
              direction: AxisDirection.left,
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return FadeInSlide(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const Spacer(),
          AnimatedTextKit(
            animatedTexts: [
              TypewriterAnimatedText(
                'GetInsta',
                textStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
                speed: const Duration(milliseconds: 200),
              ),
            ],
            isRepeatingAnimation: false,
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              try {
                final url = Uri.parse(
                    'https://www.instagram.com/yourhoneydewie?igsh=eWZvdzJqdjkxdDBq');
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } catch (e) {
                if (mounted) {
                  final error = ErrorHandler.handleError(e);
                  ErrorHandler.showErrorToast(error);
                }
              }
            },
            child: AnimatedGradientButton(
              text: 'Follow',
              onPressed: () {},
              width: 90,
              height: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return ScaleInFade(
      delay: const Duration(milliseconds: 200),
      child: GlassmorphicCard(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: Icon(
                Icons.search_rounded,
                color: const Color(0xFF6C63FF).withValues(alpha: 0.7),
                size: 24,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Paste Instagram, YouTube, or Pinterest URL...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onSubmitted: (url) {
                  if (url.isNotEmpty) {
                    _processUrl(url, isQuickAction: false);
                  }
                },
              ),
            ),
            GestureDetector(
              onTap: _isLoading ? null : _onPastePressed,
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                child: _isLoading
                    ? const WaveLoadingIndicator(size: 24)
                    : Icon(
                        _hasText ? Icons.download_rounded : Icons.content_paste_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeInSlide(
      delay: const Duration(milliseconds: 400),
      child: Center(
        child: Column(
          children: [
            const SizedBox(height: 60),
            PulsingDot(size: 12),
            const SizedBox(height: 24),
            Text(
              'Paste a URL to get started',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCachedPosts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeInSlide(
          delay: const Duration(milliseconds: 300),
          child: const Text(
            'Recent Searches',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        StaggeredListAnimation(
          itemCount: _cachedPosts.length > 5 ? 5 : _cachedPosts.length,
          itemBuilder: (context, index) {
            final post = _cachedPosts[index];
            return GestureDetector(
              onTap: () => _showMediaBottomSheet(post),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: GlassmorphicCard(
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFF2A2A2A),
                        ),
                        child: post['thumbnail'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  post['thumbnail'],
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.video_library, color: Colors.white54),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@${post['username'] ?? 'Unknown'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              post['caption'] ?? 'No caption',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (post['hasMultipleMedia'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${post['mediaCount'] ?? 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentDownloads() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Downloads',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _recentDownloads.length,
            itemBuilder: (context, index) {
              final download = _recentDownloads[index];
              return GestureDetector(
                onTap: () async {
                  final filePath = download['filePath'];
                  if (filePath != null) {
                    final file = File(filePath);
                    if (await file.exists()) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfessionalVideoPlayer(
                            videoPath: filePath,
                            title: download['filename'] ?? 'Video',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  width: 180,
                  margin: const EdgeInsets.only(right: 12),
                  child: GlassmorphicCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(16)),
                            color: const Color(0xFF2A2A2A),
                          ),
                          child: Stack(
                            children: [
                              if (download['thumbnailUrl'] != null)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16)),
                                  child: Image.network(
                                    download['thumbnailUrl'],
                                    width: double.infinity,
                                    height: 90,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              const Center(
                                child: Icon(
                                  Icons.play_circle_filled_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            download['filename'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
