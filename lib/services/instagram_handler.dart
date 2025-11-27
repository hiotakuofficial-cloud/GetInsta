import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../services/notification_service.dart';

class InstagramHandler {
  static const String _apiBaseUrl = 'https://v1-w3sc.onrender.com/insta/api.php';
  
  // Check if URL is valid Instagram URL
  static bool isValidInstagramUrl(String url) {
    if (url.isEmpty) return false;
    
    final patterns = [
      r'https?://(?:www\.)?instagram\.com/p/[A-Za-z0-9_-]+',
      r'https?://(?:www\.)?instagram\.com/reel/[A-Za-z0-9_-]+',
    ];
    
    return patterns.any((pattern) => RegExp(pattern).hasMatch(url));
  }
  
  // Get content type from URL
  static String getContentType(String url) {
    if (url.contains('/p/')) return 'post'; // Multiple images/videos possible
    if (url.contains('/reel/')) return 'reel'; // Single video only
    return 'unknown';
  }
  
  // Process Instagram URL using real API
  static Future<Map<String, dynamic>?> processUrl(String url) async {
    try {
      if (!isValidInstagramUrl(url)) {
        throw Exception('Invalid Instagram URL');
      }
      
      final contentType = getContentType(url);
      
      // Call real API
      final apiUrl = '$_apiBaseUrl?action=url&url=${Uri.encodeComponent(url)}';
      final response = await http.get(Uri.parse(apiUrl));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          // Analyze download links to determine media types
          List<String> downloadLinks = List<String>.from(data['download_links'] ?? []);
          List<Map<String, dynamic>> mediaItems = [];
          
          for (int i = 0; i < downloadLinks.length; i++) {
            String link = downloadLinks[i];
            String mediaType = link.contains('.mp4') ? 'video' : 'image';
            
            mediaItems.add({
              'url': link,
              'type': mediaType,
              'index': i,
              'filename': _generateFilename(data['username'], contentType, mediaType, i, data['caption'] ?? ''),
            });
          }
          
          return {
            'success': true,
            'contentType': contentType,
            'username': data['username'],
            'caption': data['caption'],
            'thumbnail': data['thumbnail'],
            'mediaCount': mediaItems.length,
            'mediaItems': mediaItems,
            'hasMultipleMedia': mediaItems.length > 1,
            'hasVideo': mediaItems.any((item) => item['type'] == 'video'),
            'hasImages': mediaItems.any((item) => item['type'] == 'image'),
          };
        } else {
          throw Exception('API returned error: ${data['message'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Generate filename based on content
  static String _generateFilename(String username, String contentType, String mediaType, int index, String caption) {
    final extension = mediaType == 'video' ? 'mp4' : 'jpg';
    
    // Extract first 5 words from caption
    String filename = '';
    if (caption.isNotEmpty) {
      List<String> words = caption.split(' ')
          .where((word) => word.isNotEmpty && !word.startsWith('#') && !word.startsWith('@'))
          .take(5)
          .toList();
      
      if (words.isNotEmpty) {
        filename = words.join('_')
            .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove special characters
            .replaceAll(RegExp(r'\s+'), '_') // Replace spaces with underscores
            .toLowerCase();
      }
    }
    
    // Fallback to username if no valid caption words
    if (filename.isEmpty) {
      filename = '${username}_${contentType}';
    }
    
    // Add index for multiple files
    if (contentType == 'post' && index > 0) {
      filename += '_${index + 1}';
    }
    
    return '$filename.$extension';
  }
  
  // Download single media file with progress notifications
  static Future<Map<String, dynamic>> downloadMedia(String mediaUrl, String fileName) async {
    try {
      // Show download started notification
      await NotificationService.showDownloadStarted(fileName);
      
      final request = http.Request('GET', Uri.parse(mediaUrl));
      final response = await request.send();
      
      if (response.statusCode == 200) {
        // Get app's download directory
        final directory = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory('${directory.path}/GetInsta/Downloads');
        
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        
        // Save file with progress tracking
        final file = File('${downloadsDir.path}/$fileName');
        final sink = file.openWrite();
        
        int downloaded = 0;
        final total = response.contentLength ?? 0;
        
        await response.stream.listen(
          (chunk) {
            sink.add(chunk);
            downloaded += chunk.length;
            
            if (total > 0) {
              final progress = ((downloaded / total) * 100).round();
              // Update notification progress
              NotificationService.updateDownloadProgress(progress, fileName);
            }
          },
          onDone: () async {
            await sink.close();
            // Show completion notification
            await NotificationService.showDownloadComplete(fileName, true);
          },
          onError: (error) async {
            await sink.close();
            await NotificationService.showDownloadComplete(fileName, false);
          },
        ).asFuture();
        
        return {
          'success': true,
          'filePath': file.path,
          'fileName': fileName,
          'size': '${(downloaded / 1024 / 1024).toStringAsFixed(2)} MB',
        };
      } else {
        await NotificationService.showDownloadComplete(fileName, false);
        throw Exception('Download failed: ${response.statusCode}');
      }
    } catch (e) {
      await NotificationService.showDownloadComplete(fileName, false);
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Show processing dialog
  static void showProcessingDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF6C63FF),
            ),
            const SizedBox(height: 16),
            const Text(
              'Processing Instagram URL...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analyzing content type and media...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Show media preview and download options
  static void showMediaPreview(BuildContext context, Map<String, dynamic> result) {
    Navigator.of(context).pop(); // Close processing dialog
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Container();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(animation.value),
          child: FadeTransition(
            opacity: animation,
            child: AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    result['contentType'] == 'reel' ? Icons.play_circle : Icons.photo_library,
                    color: const Color(0xFF6C63FF),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '@${result['username']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content type info
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${result['contentType'].toUpperCase()} • ${result['mediaCount']} ${result['mediaCount'] == 1 ? 'item' : 'items'}',
                      style: const TextStyle(
                        color: Color(0xFF6C63FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Media info
                  if (result['hasVideo'] && result['hasImages'])
                    const Text(
                      '📹 Videos + 📷 Images',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    )
                  else if (result['hasVideo'])
                    const Text(
                      '📹 Video content',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    )
                  else
                    const Text(
                      '📷 Image content',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // Caption preview
                  if (result['caption'] != null && result['caption'].isNotEmpty)
                    Text(
                      result['caption'],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _startDownload(context, result);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                  ),
                  child: Text(
                    'Download ${result['mediaCount'] == 1 ? '' : 'All (${result['mediaCount']})'}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Start download process
  static void _startDownload(BuildContext context, Map<String, dynamic> result) async {
    // Show download progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF6C63FF),
            ),
            const SizedBox(height: 16),
            Text(
              'Downloading ${result['mediaCount']} ${result['mediaCount'] == 1 ? 'file' : 'files'}...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
    
    // Download all media files
    List<Map<String, dynamic>> downloadResults = [];
    List<Map<String, dynamic>> mediaItems = List<Map<String, dynamic>>.from(result['mediaItems']);
    
    for (var mediaItem in mediaItems) {
      final downloadResult = await downloadMedia(mediaItem['url'], mediaItem['filename']);
      downloadResults.add(downloadResult);
    }
    
    // Close progress dialog
    Navigator.of(context).pop();
    
    // Show results
    _showDownloadComplete(context, result, downloadResults);
  }
  
  // Show download completion
  static void _showDownloadComplete(BuildContext context, Map<String, dynamic> result, List<Map<String, dynamic>> downloadResults) {
    int successCount = downloadResults.where((r) => r['success'] == true).length;
    int failCount = downloadResults.length - successCount;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              successCount > 0 ? Icons.check_circle : Icons.error,
              color: successCount > 0 ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              successCount > 0 ? 'Download Complete!' : 'Download Failed',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (successCount > 0)
              Text(
                'Successfully downloaded $successCount ${successCount == 1 ? 'file' : 'files'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            if (failCount > 0)
              Text(
                'Failed to download $failCount ${failCount == 1 ? 'file' : 'files'}',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Files saved to: /Android/data/com.example.getinsta/files/GetInsta/Downloads/',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF6C63FF)),
            ),
          ),
        ],
      ),
    );
  }
}
