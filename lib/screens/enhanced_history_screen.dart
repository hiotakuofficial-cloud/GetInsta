import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../services/download_history.dart';
import '../services/instagram_handler.dart';
import '../widgets/modern_components.dart';
import '../utils/error_handler.dart';
import '../utils/animations.dart';
import 'professional_video_player.dart';
import 'about_screen.dart';

class EnhancedHistoryScreen extends StatefulWidget {
  const EnhancedHistoryScreen({super.key});

  @override
  State<EnhancedHistoryScreen> createState() => _EnhancedHistoryScreenState();
}

class _EnhancedHistoryScreenState extends State<EnhancedHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> downloads = [];
  List<Map<String, dynamic>> filteredDownloads = [];
  bool isLoading = true;
  String searchQuery = '';
  late AnimationController _refreshController;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _loadDownloads();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadDownloads() async {
    setState(() => isLoading = true);

    try {
      final history = await DownloadHistory.getHistory();
      final folderFiles = await DownloadHistory.getDownloadsFromFolder();

      final allDownloads = <Map<String, dynamic>>[];
      allDownloads.addAll(history);

      for (var file in folderFiles) {
        final exists = history.any((h) => h['filename'] == file['filename']);
        if (!exists) {
          allDownloads.add(file);
        }
      }

      allDownloads.sort((a, b) {
        final aTime = DateTime.tryParse(a['downloadTime'] ?? '') ?? DateTime.now();
        final bTime = DateTime.tryParse(b['downloadTime'] ?? '') ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          downloads = allDownloads;
          filteredDownloads = allDownloads;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        final error = ErrorHandler.handleError(e);
        ErrorHandler.showErrorSnackbar(context, error);
      }
    }
  }

  void _filterDownloads(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredDownloads = downloads;
      } else {
        filteredDownloads = downloads.where((download) {
          final filename = (download['filename'] ?? '').toLowerCase();
          final username = (download['username'] ?? '').toLowerCase();
          final caption = (download['caption'] ?? '').toLowerCase();
          final searchLower = query.toLowerCase();

          return filename.contains(searchLower) ||
              username.contains(searchLower) ||
              caption.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _playVideo(String? filePath) async {
    if (filePath == null) return;

    try {
      final file = File(filePath);
      if (await file.exists()) {
        Navigator.push(
          context,
          CustomPageRoute(
            child: ProfessionalVideoPlayer(
              videoPath: filePath,
              title: 'Downloaded Video',
            ),
            direction: AxisDirection.up,
          ),
        );
      } else {
        if (mounted) {
          final error = AppError(
            type: ErrorType.fileNotFound,
            message: 'Video file not found',
          );
          ErrorHandler.showErrorSnackbar(context, error);
        }
      }
    } catch (e) {
      if (mounted) {
        final error = ErrorHandler.handleError(e);
        ErrorHandler.showErrorDialog(context, error);
      }
    }
  }

  Future<void> _deleteVideo(Map<String, dynamic> download) async {
    try {
      if (download['filePath'] != null) {
        final file = File(download['filePath']);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await DownloadHistory.removeDownload(download['filename']);
      await _loadDownloads();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Video deleted successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final error = ErrorHandler.handleError(e);
        ErrorHandler.showErrorDialog(context, error);
      }
    }
  }

  Future<void> _downloadAgain(Map<String, dynamic> download) async {
    if (download['videoUrl'] == null) return;

    await SafeOperation.execute(
      operation: () => InstagramHandler.downloadMedia(
        download['videoUrl'],
        download['filename'],
        thumbnailUrl: download['thumbnailUrl'],
        username: download['username'],
        caption: download['caption'],
      ),
      context: context,
      showErrorDialog: true,
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 500) {
            Navigator.of(context).pop();
          }
        },
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildSearchBar(),
              const SizedBox(height: 20),
              Expanded(
                child: isLoading
                    ? _buildLoadingState()
                    : filteredDownloads.isEmpty
                        ? _buildEmptyState()
                        : _buildDownloadsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: FadeInSlide(
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: NeumorphicContainer(
                padding: const EdgeInsets.all(12),
                borderRadius: 14,
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Downloads',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  CustomPageRoute(
                    child: const AboutScreen(),
                    direction: AxisDirection.left,
                  ),
                );
              },
              child: NeumorphicContainer(
                padding: const EdgeInsets.all(12),
                borderRadius: 14,
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ScaleInFade(
        delay: const Duration(milliseconds: 150),
        child: GlassmorphicCard(
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 12),
                child: Icon(
                  Icons.search_rounded,
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.7),
                  size: 22,
                ),
              ),
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search downloads...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: _filterDownloads,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          WaveLoadingIndicator(size: 60),
          SizedBox(height: 24),
          Text(
            'Loading downloads...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _loadDownloads,
      color: const Color(0xFF6C63FF),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.download_outlined,
                  size: 80,
                  color: Colors.white24,
                ),
                const SizedBox(height: 24),
                Text(
                  searchQuery.isEmpty ? 'No downloads yet' : 'No results found',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  searchQuery.isEmpty
                      ? 'Pull down to refresh'
                      : 'Try a different search term',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadsList() {
    return RefreshIndicator(
      onRefresh: _loadDownloads,
      color: const Color(0xFF6C63FF),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filteredDownloads.length,
        itemBuilder: (context, index) {
          final download = filteredDownloads[index];
          return FadeInSlide(
            delay: Duration(milliseconds: 50 * index),
            child: GestureDetector(
              onTap: () => _playVideo(download['filePath']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: GlassmorphicCard(
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFF2A2A2A),
                        ),
                        child: Stack(
                          children: [
                            if (download['thumbnailUrl'] != null &&
                                download['thumbnailUrl'].isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  download['thumbnailUrl'],
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.video_library_rounded,
                                    color: Colors.white54,
                                    size: 30,
                                  ),
                                ),
                              )
                            else
                              const Center(
                                child: Icon(
                                  Icons.video_library_rounded,
                                  color: Colors.white54,
                                  size: 30,
                                ),
                              ),
                            const Center(
                              child: Icon(
                                Icons.play_circle_filled_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              download['filename'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            if (download['username'] != null)
                              Text(
                                '@${download['username']}',
                                style: const TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(download['downloadTime']),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showOptionsBottomSheet(download),
                        child: NeumorphicContainer(
                          padding: const EdgeInsets.all(10),
                          borderRadius: 12,
                          child: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showOptionsBottomSheet(Map<String, dynamic> download) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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

            Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF2A2A2A),
                  ),
                  child: download['thumbnailUrl'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            download['thumbnailUrl'],
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
                        download['filename'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            AnimatedGradientButton(
              text: 'Download Again',
              icon: Icons.download_rounded,
              onPressed: () {
                Navigator.pop(context);
                _downloadAgain(download);
              },
            ),

            const SizedBox(height: 12),

            AnimatedGradientButton(
              text: 'Delete',
              icon: Icons.delete_rounded,
              gradientColors: const [Colors.red, Colors.redAccent],
              onPressed: () {
                Navigator.pop(context);
                _showDeleteConfirmation(download);
              },
            ),

            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> download) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Delete Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Are you sure you want to delete this video? This action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedGradientButton(
                    text: 'Delete',
                    gradientColors: const [Colors.red, Colors.redAccent],
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteVideo(download);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
