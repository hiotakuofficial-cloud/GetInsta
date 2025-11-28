import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../services/download_history.dart';
import '../services/instagram_handler.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> downloads = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Transparent status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    try {
      final history = await DownloadHistory.getHistory();
      final folderFiles = await DownloadHistory.getDownloadsFromFolder();
      
      // Combine history and folder files
      final allDownloads = <Map<String, dynamic>>[];
      allDownloads.addAll(history);
      
      // Add folder files that aren't in history
      for (var file in folderFiles) {
        final exists = history.any((h) => h['filename'] == file['filename']);
        if (!exists) {
          allDownloads.add(file);
        }
      }
      
      // Sort by download time
      allDownloads.sort((a, b) {
        final aTime = DateTime.tryParse(a['downloadTime'] ?? '') ?? DateTime.now();
        final bTime = DateTime.tryParse(b['downloadTime'] ?? '') ?? DateTime.now();
        return bTime.compareTo(aTime);
      });
      
      setState(() {
        downloads = allDownloads;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe right to go back
          if (details.primaryVelocity! > 500) {
            Navigator.of(context).pop();
          }
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            child: Column(
              children: [
                // Header (removed refresh button)
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Download History',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // Downloads list with iOS elastic effect
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF6C63FF),
                          ),
                        )
                      : downloads.isEmpty
                          ? RefreshIndicator(
                              onRefresh: _loadDownloads,
                              color: const Color(0xFF6C63FF),
                              child: ListView(
                                physics: const BouncingScrollPhysics(), // iOS elastic effect
                                children: [
                                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                                  const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.download_outlined,
                                          size: 64,
                                          color: Colors.white54,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'No downloads yet',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.white54,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Pull down to refresh',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadDownloads,
                              color: const Color(0xFF6C63FF),
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(), // iOS elastic effect
                                itemCount: downloads.length,
                                itemBuilder: (context, index) {
                                  final download = downloads[index];
                                  return GestureDetector(
                                    onTap: () {
                                      // Play video directly
                                      _playVideo(download['filePath']);
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E1E1E),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                      children: [
                                        // Video thumbnail
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
                                                      return const Icon(
                                                        Icons.video_library,
                                                        color: Colors.white54,
                                                        size: 24,
                                                      );
                                                    },
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.video_library,
                                                  color: Colors.white54,
                                                  size: 24,
                                                ),
                                        ),
                                        
                                        const SizedBox(width: 16),
                                        
                                        // Details
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
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              if (download['username'] != null)
                                                Text(
                                                  '@${download['username']}',
                                                  style: const TextStyle(
                                                    color: Color(0xFF6C63FF),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatDate(download['downloadTime']),
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        // Three dots menu
                                        GestureDetector(
                                          onTap: () {
                                            _showOptionsBottomSheet(context, download);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2A2A2A),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.more_vert,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showOptionsBottomSheet(BuildContext context, Map<String, dynamic> download) {
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
            
            // Video thumbnail and info
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
                  // Download Again button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _downloadAgain(download);
                      },
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text('Download Again', style: TextStyle(color: Colors.white)),
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
                  
                  // Delete button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation(context, download);
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
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

  void _downloadAgain(Map<String, dynamic> download) {
    Fluttertoast.showToast(msg: "Downloading...");
    // Re-download the video using the stored video URL
    if (download['videoUrl'] != null) {
      InstagramHandler.downloadMedia(
        download['videoUrl'],
        download['filename'],
        thumbnailUrl: download['thumbnailUrl'],
        username: download['username'],
        caption: download['caption'],
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context, Map<String, dynamic> download) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Video',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Are you sure you want to delete this video? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteVideo(download);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteVideo(Map<String, dynamic> download) async {
    try {
      // Delete physical file
      if (download['filePath'] != null) {
        final file = File(download['filePath']);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      // Remove from history
      await DownloadHistory.removeDownload(download['filename']);
      
      // Reload the list
      await _loadDownloads();
      
      Fluttertoast.showToast(msg: "Video deleted successfully");
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to delete video");
    }
  }

  void _playVideo(String? filePath) async {
    if (filePath != null) {
      try {
        // Open video with system video player chooser
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication, // Shows app suggestions
          );
        } else {
          Fluttertoast.showToast(msg: "No video player found");
        }
      } catch (e) {
        Fluttertoast.showToast(msg: "Failed to open video");
      }
    }
  }
}
