import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'screens/history_screen.dart';
import 'screens/professional_video_player.dart';
import 'services/instagram_handler.dart';
import 'services/notification_service.dart';
import 'services/download_history.dart';
import 'services/instagram_cache.dart';
import 'services/youtube_pinterest_handler.dart';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _pasteController;
  late AnimationController _searchController2;
  late Animation<double> _pasteAnimation;
  late Animation<double> _searchAnimation;
  bool _isLoading = false;
  bool _hasText = false; // Track if input has text
  bool _isQuickAction = false; // Flag for share/quick downloads
  Set<int> _selectedMediaIndices = {}; // For multiple media selection
  List<Map<String, dynamic>> _cachedPosts = []; // Cached Instagram posts

  @override
  void initState() {
    super.initState();
    
    // Set notification context for click handling
    NotificationService.setContext(context);
    
    // Transparent status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    _pasteController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _searchController2 = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _pasteAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _pasteController, curve: Curves.elasticOut),
    );

    _searchAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _searchController2, curve: Curves.easeInOut),
    );
    
    // Listen to text changes
    _searchController.addListener(() {
      setState(() {
        _hasText = _searchController.text.isNotEmpty;
      });
    });
    
    // Initialize notifications
    NotificationService.initialize();
    
    // Load cached posts
    _loadCachedPosts();

    // Request permissions
    _requestPermissions();
    
    // Initialize notifications
    NotificationService.initialize();
  }

  Future<void> _requestPermissions() async {
    // Request storage permissions based on Android version
    if (await Permission.manageExternalStorage.isGranted) {
      // Already have manage external storage
      return;
    }
    
    // Request permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.notification,
    ].request();
    
    // Check if storage permission was denied
    if (statuses[Permission.storage] == PermissionStatus.denied ||
        statuses[Permission.manageExternalStorage] == PermissionStatus.denied) {
      // Show dialog to user
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Storage Permission Required',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'This app needs storage permission to download Instagram media files.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: const Text('Settings', style: TextStyle(color: Color(0xFF6C63FF))),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pasteController.dispose();
    _searchController2.dispose();
    super.dispose();
  }

  Future<void> _loadCachedPosts() async {
    final cached = await InstagramCache.getCache();
    setState(() {
      _cachedPosts = cached;
    });
  }

  void _onPastePressed() async {
    Fluttertoast.showToast(
      msg: "📋 DEBUG: Paste pressed, hasText: $_hasText",
      backgroundColor: Colors.grey,
      toastLength: Toast.LENGTH_LONG
    );

    if (_hasText) {
      // If text exists, treat as download action (manual input)
      final url = _searchController.text;
      if (url.isNotEmpty) {
        _isQuickAction = false; // Manual input = show options
        Fluttertoast.showToast(
          msg: "⌨️ DEBUG: Manual input detected, Quick: $_isQuickAction",
          backgroundColor: Colors.indigo,
          toastLength: Toast.LENGTH_LONG
        );
        _processInstagramUrl(url);
      }
    } else {
      // If no text, paste from clipboard (quick action)
      _pasteController.forward().then((_) {
        _pasteController.reverse();
      });
      
      ClipboardData? data = await Clipboard.getData('text/plain');
      if (data != null && data.text != null) {
        _searchController.text = data.text!;
        _searchController2.forward().then((_) {
          _searchController2.reverse();
        });
        
        // Auto-process for quick action
        _isQuickAction = true; // Paste from clipboard = quick download
        Fluttertoast.showToast(
          msg: "📋 DEBUG: Clipboard paste detected, Quick: $_isQuickAction, URL: ${data.text!.substring(0, data.text!.length > 30 ? 30 : data.text!.length)}...",
          backgroundColor: Colors.teal,
          toastLength: Toast.LENGTH_LONG
        );
        _processInstagramUrl(data.text!);
      } else {
        Fluttertoast.showToast(
          msg: "❌ DEBUG: No clipboard data found",
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG
        );
      }
    }
  }

  void _processInstagramUrl(String url) async {
    // Debug toast to see what URL is received
    Fluttertoast.showToast(
      msg: "🔍 DEBUG: Received URL: ${url.substring(0, url.length > 50 ? 50 : url.length)}...",
      backgroundColor: Colors.orange,
      toastLength: Toast.LENGTH_LONG
    );

    // Check if it's YouTube or Pinterest first
    if (YouTubePinterestHandler.isYouTubeUrl(url)) {
      Fluttertoast.showToast(
        msg: "🎥 DEBUG: Detected YouTube URL, Quick: $_isQuickAction",
        backgroundColor: Colors.blue,
        toastLength: Toast.LENGTH_LONG
      );
      _processYouTubeUrl(url);
      return;
    }
    
    if (YouTubePinterestHandler.isPinterestUrl(url)) {
      Fluttertoast.showToast(
        msg: "📌 DEBUG: Detected Pinterest URL, Quick: $_isQuickAction",
        backgroundColor: Colors.pink,
        toastLength: Toast.LENGTH_LONG
      );
      _processPinterestUrl(url);
      return;
    }

    // Debug for Instagram detection
    Fluttertoast.showToast(
      msg: "📷 DEBUG: Processing as Instagram URL",
      backgroundColor: Colors.purple,
      toastLength: Toast.LENGTH_LONG
    );

    // Original Instagram processing (unchanged)
    if (!InstagramHandler.isValidInstagramUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Instagram, YouTube, or Pinterest URL'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check network connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showNoInternetToast();
      return;
    }

    // Start loading
    setState(() {
      _isLoading = true;
    });

    // Process the URL
    final result = await InstagramHandler.processUrl(url);

    // Stop loading
    setState(() {
      _isLoading = false;
    });

    if (result != null && result['success'] == true) {
      // Save to cache with original URL
      final cacheData = Map<String, dynamic>.from(result);
      cacheData['url'] = url; // Add original URL for cache identification
      await InstagramCache.addToCache(cacheData);
      
      // Reload cached posts to show the new one
      await _loadCachedPosts();
      
      // Show bottom sheet instead of popup
      _showMediaBottomSheet(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result?['error'] ?? 'Failed to process Instagram URL'),
          backgroundColor: Colors.red,
        ),
      );
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Thumbnail
            if (result['thumbnail'] != null && result['thumbnail'].isNotEmpty)
              Container(
                width: double.infinity,
                height: 200,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF2A2A2A),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    result['thumbnail'],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6C63FF),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            
            // Header
            Row(
              children: [
                Icon(
                  result['contentType'] == 'reel' ? Icons.play_circle : Icons.photo_library,
                  color: const Color(0xFF6C63FF),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '@${result['username']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Content info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${result['contentType'].toUpperCase()} • ${result['mediaCount']} ${result['mediaCount'] == 1 ? 'item' : 'items'}',
                style: const TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Media info
            if (result['hasVideo'] && result['hasImages'])
              const Text(
                '📹 Videos + 📷 Images',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              )
            else if (result['hasVideo'])
              const Text(
                '📹 Video content',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              )
            else
              const Text(
                '📷 Image content',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            
            const SizedBox(height: 12),
            
            // Caption preview
            if (result['caption'] != null && result['caption'].isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  result['caption'],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Call actual download function
                      _startDownload(result);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Download ${result['mediaCount'] == 1 ? '' : 'All (${result['mediaCount']})'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

  void _showNoInternetToast() {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.1,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: Curves.easeOutBack.transform(value),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.red.withOpacity(0.8),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'No Internet Connection',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            onEnd: () {
              // Auto dismiss after 2 seconds
              Future.delayed(const Duration(seconds: 2), () {
                overlayEntry.remove();
              });
            },
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
  }

  void _startDownload(Map<String, dynamic> result) async {
    // Show simple toast instead of dialog
    Fluttertoast.showToast(msg: "Downloading...");

    // Download all media files
    List<Map<String, dynamic>> downloadResults = [];
    
    try {
      // Check if mediaItems exists
      if (result['mediaItems'] == null) {
        return;
      }
      
      List<dynamic> mediaItems = result['mediaItems'];
      
      // For multiple media, use selected indices, otherwise download all
      List<int> indicesToDownload = [];
      if (result['hasMultipleMedia'] == true && _selectedMediaIndices.isNotEmpty) {
        indicesToDownload = _selectedMediaIndices.toList();
      } else {
        // Download all media
        for (int i = 0; i < mediaItems.length; i++) {
          indicesToDownload.add(i);
        }
      }
      
      if (indicesToDownload.isEmpty) {
        return;
      }
      
      for (int index in indicesToDownload) {
        final mediaItem = mediaItems[index];
        final mediaUrl = mediaItem['url'];
        final fileName = mediaItem['filename'];
        
        final downloadResult = await InstagramHandler.downloadMedia(
          mediaUrl, 
          fileName,
          thumbnailUrl: result['thumbnail'],
          username: result['username'],
          caption: result['caption'],
        );
        downloadResults.add(downloadResult);
      }
    } catch (e) {
      // Download error - silent fail
    }
    
    // Show results (removed dialog, just notifications now)
    int successCount = downloadResults.where((r) => r['success'] == true).length;
    int failCount = downloadResults.length - successCount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! < -500) {
                // Swipe left (negative velocity = left swipe)
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const HistoryScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;
                      
                      var tween = Tween(begin: begin, end: end).chain(
                        CurveTween(curve: curve),
                      );
                      
                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                );
              }
            },
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.delayed(const Duration(seconds: 1));
              },
              color: const Color(0xFF6C63FF),
              backgroundColor: const Color(0xFF1E1E1E),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      children: [
                        // Header
                        Row(
                          children: [
                            // Left Logo
                            Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/logo.png',
                                  width: 45,
                                  height: 45,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            // Center Title
                            Expanded(
                              child: Center(
                                child: Text(
                                  'GetInsta',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontFamily: 'Cursive',
                                    letterSpacing: 1.2,
                                    shadows: [
                                      Shadow(
                                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            // Right Follow Button
                            GestureDetector(
                              onTap: () async {
                                try {
                                  final Uri url = Uri.parse('https://www.instagram.com/yourhoneydewie?igsh=eWZvdzJqdjkxdDBq');
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url, mode: LaunchMode.externalApplication);
                                  } else {
                                    // Fallback to browser
                                    await launchUrl(url, mode: LaunchMode.platformDefault);
                                  }
                                } catch (e) {
                                  // Show error message
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Could not open Instagram'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'Follow',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Search Bar
                        AnimatedBuilder(
                          animation: _searchAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _searchAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF6C63FF).withOpacity(0.4),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6C63FF).withOpacity(0.15),
                                      blurRadius: 25,
                                      spreadRadius: 0,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF6C63FF).withOpacity(0.1),
                                      blurRadius: 50,
                                      spreadRadius: 5,
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      offset: const Offset(0, 8),
                                      blurRadius: 16,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Left Search Icon
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16, right: 12),
                                      child: Icon(
                                        Icons.search_rounded,
                                        color: const Color(0xFF6C63FF).withOpacity(0.7),
                                        size: 24,
                                      ),
                                    ),
                                    
                                    // Search Input
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Paste Instagram URL here...',
                                          hintStyle: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 16,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                        ),
                                        onSubmitted: (url) {
                                          if (url.isNotEmpty) {
                                            _processInstagramUrl(url);
                                          }
                                        },
                                      ),
                                    ),
                                    
                                    // Dynamic Right Icon (Paste/Download)
                                    GestureDetector(
                                      onTap: _isLoading ? null : _onPastePressed,
                                      child: AnimatedBuilder(
                                        animation: _pasteAnimation,
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale: _pasteAnimation.value,
                                            child: Container(
                                              margin: const EdgeInsets.only(right: 12),
                                              padding: const EdgeInsets.all(12),
                                              child: _isLoading
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor: AlwaysStoppedAnimation<Color>(
                                                          Color(0xFF6C63FF),
                                                        ),
                                                      ),
                                                    )
                                                  : Icon(
                                                      _hasText ? Icons.download : Icons.content_paste,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        
                        // Conditional text - show only when no cached posts
                        if (_cachedPosts.isEmpty) ...[
                          const SizedBox(height: 40),
                          Text(
                            'Paste Instagram URL to start downloading',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        
                        // Cached Posts Section
                        if (_cachedPosts.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Recent Searches',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Cached posts list
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _cachedPosts.length > 5 ? 5 : _cachedPosts.length,
                            itemBuilder: (context, index) {
                              final post = _cachedPosts[index];
                              return GestureDetector(
                                onTap: () {
                                  _showMediaBottomSheet(post);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      // Thumbnail
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: const Color(0xFF2A2A2A),
                                        ),
                                        child: post['thumbnail'] != null
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  post['thumbnail'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return const Icon(
                                                      Icons.video_library,
                                                      color: Colors.white54,
                                                      size: 20,
                                                    );
                                                  },
                                                ),
                                              )
                                            : const Icon(
                                                Icons.video_library,
                                                color: Colors.white54,
                                                size: 20,
                                              ),
                                      ),
                                      
                                      const SizedBox(width: 12),
                                      
                                      // Post info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '@${post['username'] ?? 'Unknown'}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              post['caption'] ?? 'No caption',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.7),
                                                fontSize: 12,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Media count indicator
                                      if (post['hasMultipleMedia'] == true)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6C63FF),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${post['mediaCount'] ?? 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        
                        SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                        
                        // Recently Downloaded Section
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: DownloadHistory.getRecentDownloads(limit: 5),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Recently Downloaded',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Horizontal scrollable list
                                  SizedBox(
                                    height: 120,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: snapshot.data!.length,
                                      itemBuilder: (context, index) {
                                        final download = snapshot.data![index];
                                        return GestureDetector(
                                          onTap: () {
                                            // Play video directly in custom player
                                            _playVideoFromRecent(download);
                                          },
                                          child: Container(
                                            width: 160,
                                            margin: const EdgeInsets.only(right: 12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E1E1E),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Thumbnail
                                                Container(
                                                  height: 80,
                                                  decoration: BoxDecoration(
                                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                                    color: const Color(0xFF2A2A2A),
                                                  ),
                                                  child: Stack(
                                                    children: [
                                                      if (download['thumbnailUrl'] != null && download['thumbnailUrl'].isNotEmpty)
                                                        ClipRRect(
                                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                                          child: Image.network(
                                                            download['thumbnailUrl'],
                                                            width: double.infinity,
                                                            height: 80,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (context, error, stackTrace) {
                                                              return const Center(
                                                                child: Icon(Icons.video_library, color: Colors.white54),
                                                              );
                                                            },
                                                          ),
                                                        )
                                                      else
                                                        const Center(
                                                          child: Icon(Icons.video_library, color: Colors.white54),
                                                        ),
                                                      
                                                      // Play overlay
                                                      const Center(
                                                        child: Icon(
                                                          Icons.play_circle_filled,
                                                          color: Colors.white,
                                                          size: 32,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                
                                                // Title
                                                Padding(
                                                  padding: const EdgeInsets.all(8),
                                                  child: Text(
                                                    download['filename'] ?? 'Unknown',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ),
            
            // Powered by Nehu text at bottom
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Powered by Nehu',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }
  
  void _playVideo(String? filePath) {
    if (filePath != null) {
      // Open video with system video player
      launchUrl(Uri.file(filePath));
    }
  }

  void _playVideoFromRecent(Map<String, dynamic> download) async {
    final filePath = download['filePath'];
    if (filePath != null) {
      try {
        // Check if file exists
        final file = File(filePath);
        if (await file.exists()) {
          // Navigate to custom video player
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfessionalVideoPlayer(
                videoPath: filePath,
                title: download['filename'] ?? 'Downloaded Video',
              ),
            ),
          );
        } else {
          Fluttertoast.showToast(msg: "Video file not found");
        }
      } catch (e) {
        Fluttertoast.showToast(msg: "Error opening video");
      }
    } else {
      Fluttertoast.showToast(msg: "File path is null");
    }
  }

  void _showHistoryVideoOptions(Map<String, dynamic> download) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white54,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Video info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Thumbnail
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF2A2A2A),
                    ),
                    child: download['thumbnailUrl'] != null && download['thumbnailUrl'].isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              download['thumbnailUrl'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.video_library, color: Colors.white54);
                              },
                            ),
                          )
                        : const Icon(Icons.video_library, color: Colors.white54),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // File info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          download['filename'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (download['username'] != null)
                          Text(
                            '@${download['username']}',
                            style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Play button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _playVideo(download['filePath']);
                      },
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      label: const Text('Play Video', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Download Again button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Fluttertoast.showToast(msg: "Downloading...");
                        // Re-download the video
                        if (download['videoUrl'] != null) {
                          InstagramHandler.downloadMedia(
                            download['videoUrl'],
                            download['filename'],
                            thumbnailUrl: download['thumbnailUrl'],
                            username: download['username'],
                            caption: download['caption'],
                          );
                        }
                      },
                      icon: const Icon(Icons.download, color: Colors.white70),
                      label: const Text('Download Again', style: TextStyle(color: Colors.white70)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2A2A2A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // YouTube processing
  void _processYouTubeUrl(String url) async {
    Fluttertoast.showToast(
      msg: "🎥 DEBUG: YouTube processing started, Quick: $_isQuickAction",
      backgroundColor: Colors.blue,
      toastLength: Toast.LENGTH_LONG
    );

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showNoInternetToast();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use the quick action flag instead of text field check
      if (_isQuickAction) {
        Fluttertoast.showToast(
          msg: "⚡ DEBUG: Starting quick YouTube download...",
          backgroundColor: Colors.green,
          toastLength: Toast.LENGTH_LONG
        );
        
        // Quick download 360p
        final result = await YouTubePinterestHandler.quickDownloadYouTube(url);
        
        Fluttertoast.showToast(
          msg: "📊 DEBUG: Quick download result: ${result['success']}",
          backgroundColor: Colors.yellow,
          toastLength: Toast.LENGTH_LONG
        );
        
        if (result['success'] == true) {
          final downloadResult = await InstagramHandler.downloadMedia(
            result['downloadUrl'],
            result['filename'],
            thumbnailUrl: null,
            username: 'YouTube',
            caption: result['filename'],
          );
          
          if (downloadResult['success'] == true) {
            Fluttertoast.showToast(
              msg: "✅ Quick YouTube download completed!", 
              backgroundColor: Colors.green,
              toastLength: Toast.LENGTH_LONG
            );
          } else {
            Fluttertoast.showToast(
              msg: "❌ Download failed: ${downloadResult['error']}", 
              backgroundColor: Colors.red,
              toastLength: Toast.LENGTH_LONG
            );
          }
        } else {
          Fluttertoast.showToast(
            msg: "❌ Quick download failed: ${result['error']}", 
            backgroundColor: Colors.red,
            toastLength: Toast.LENGTH_LONG
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: "🎛️ DEBUG: Showing YouTube options UI...",
          backgroundColor: Colors.cyan,
          toastLength: Toast.LENGTH_LONG
        );
        
        // Show quality selection bottom sheet
        final result = await YouTubePinterestHandler.getYouTubeInfo(url);
        
        if (result['success'] == true) {
          _showYouTubeOptions(result['data'], url);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('YouTube Error: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _processPinterestUrl(String url) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showNoInternetToast();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use the quick action flag instead of text field check
      if (_isQuickAction) {
        // Quick download
        final result = await YouTubePinterestHandler.quickDownloadPinterest(url);
        
        if (result['success'] == true) {
          final downloadResult = await InstagramHandler.downloadMedia(
            result['downloadUrl'],
            result['filename'],
            thumbnailUrl: result['thumbnail'],
            username: 'Pinterest',
            caption: result['title'],
          );
          
          if (downloadResult['success'] == true) {
            Fluttertoast.showToast(
              msg: "✅ Quick Pinterest download completed!", 
              backgroundColor: Colors.green,
              toastLength: Toast.LENGTH_LONG
            );
          } else {
            Fluttertoast.showToast(
              msg: "❌ Download failed: ${downloadResult['error']}", 
              backgroundColor: Colors.red,
              toastLength: Toast.LENGTH_LONG
            );
          }
        }
      } else {
        // Normal Pinterest processing (direct download)
        final result = await YouTubePinterestHandler.getPinterestInfo(url);
        
        if (result['success'] == true) {
          _downloadPinterestMedia(result['data']);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pinterest Error: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showYouTubeOptions(Map<String, dynamic> data, String url) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              data['title'] ?? 'YouTube Video',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // Author
            Text(
              data['author'] ?? 'Unknown',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            
            // Format selection
            Row(
              children: [
                // MP3 Section
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '🎵 MP3 Audio',
                          style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // MP3 Quality buttons
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadYouTubeAudio(url, '128');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('128kbps', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadYouTubeAudio(url, '320');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('320kbps', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // MP4 Section
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '🎥 MP4 Video',
                          style: TextStyle(
                            color: Color(0xFF6C63FF),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // MP4 Quality buttons
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadYouTubeVideo(url, '720');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('720p', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadYouTubeVideo(url, '480');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('480p', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadYouTubeVideo(url, '360');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('360p', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _downloadYouTubeAudio(String url, String quality) async {
    try {
      final result = await YouTubePinterestHandler.downloadYouTubeAudio(url, quality);
      
      if (result['success'] == true) {
        Fluttertoast.showToast(msg: "⬇️ Downloading audio...", backgroundColor: Colors.blue);
        
        final downloadResult = await InstagramHandler.downloadMedia(
          result['downloadUrl'],
          result['filename'],
          thumbnailUrl: null,
          username: 'YouTube',
          caption: result['filename'],
        );
        
        if (downloadResult['success'] == true) {
          Fluttertoast.showToast(
            msg: "✅ YouTube audio downloaded (${quality}kbps)!", 
            backgroundColor: Colors.green,
            toastLength: Toast.LENGTH_LONG
          );
        } else {
          Fluttertoast.showToast(
            msg: "❌ Download failed: ${downloadResult['error']}", 
            backgroundColor: Colors.red,
            toastLength: Toast.LENGTH_LONG
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: "❌ Failed to get audio link: ${result['error']}", 
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "❌ Audio download error: $e", 
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG
      );
    }
  }

  void _downloadYouTubeVideo(String url, String quality) async {
    try {
      final result = await YouTubePinterestHandler.downloadYouTubeVideo(url, quality);
      
      if (result['success'] == true) {
        Fluttertoast.showToast(msg: "⬇️ Downloading video...", backgroundColor: Colors.blue);
        
        final downloadResult = await InstagramHandler.downloadMedia(
          result['downloadUrl'],
          result['filename'],
          thumbnailUrl: null,
          username: 'YouTube',
          caption: result['filename'],
        );
        
        if (downloadResult['success'] == true) {
          Fluttertoast.showToast(
            msg: "✅ YouTube video downloaded (${quality}p)!", 
            backgroundColor: Colors.green,
            toastLength: Toast.LENGTH_LONG
          );
        } else {
          Fluttertoast.showToast(
            msg: "❌ Download failed: ${downloadResult['error']}", 
            backgroundColor: Colors.red,
            toastLength: Toast.LENGTH_LONG
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: "❌ Failed to get video link: ${result['error']}", 
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "❌ Video download error: $e", 
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG
      );
    }
  }

  void _downloadPinterestMedia(Map<String, dynamic> data) async {
    try {
      Fluttertoast.showToast(msg: "⬇️ Downloading Pinterest media...", backgroundColor: Colors.pink);
      
      final downloadUrl = data['video_url'] ?? data['image_url'];
      final mediaType = data['type'] ?? 'unknown';
      
      // Get proper extension from URL or type
      String extension = 'jpg'; // default
      if (mediaType == 'video') {
        extension = 'mp4';
      } else if (downloadUrl != null) {
        // Try to get extension from URL
        final uri = Uri.parse(downloadUrl);
        final path = uri.path.toLowerCase();
        if (path.contains('.mp4')) extension = 'mp4';
        else if (path.contains('.webm')) extension = 'webm';
        else if (path.contains('.png')) extension = 'png';
        else if (path.contains('.gif')) extension = 'gif';
        else if (path.contains('.jpeg')) extension = 'jpeg';
      }
      
      final filename = 'Downloaded From GetInsta By Nehu.$extension';
      
      if (downloadUrl != null) {
        final result = await InstagramHandler.downloadMedia(
          downloadUrl,
          filename,
          thumbnailUrl: data['thumbnail'],
          username: 'Pinterest',
          caption: data['title'] ?? 'Pinterest Media',
        );
        
        if (result['success'] == true) {
          Fluttertoast.showToast(
            msg: "✅ Pinterest ${mediaType} downloaded (.$extension)!", 
            backgroundColor: Colors.green,
            toastLength: Toast.LENGTH_LONG
          );
        } else {
          Fluttertoast.showToast(
            msg: "❌ Download failed: ${result['error']}", 
            backgroundColor: Colors.red,
            toastLength: Toast.LENGTH_LONG
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: "❌ No download URL found", 
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "❌ Pinterest download error: $e", 
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG
      );
    }
  }
}
