import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import '../services/instagram_handler.dart';
import '../services/notification_service.dart';
import '../services/download_history.dart';

class ShareOverlayScreen extends StatefulWidget {
  final String sharedUrl;

  const ShareOverlayScreen({super.key, required this.sharedUrl});

  @override
  State<ShareOverlayScreen> createState() => _ShareOverlayScreenState();
}

class _ShareOverlayScreenState extends State<ShareOverlayScreen> {
  static const platform = MethodChannel('com.example.getinsta/share');
  bool _isDownloading = false;
  bool _checkingPermissions = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: GestureDetector(
        onTap: () => _closeOverlay(),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping sheet
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick Download',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'GetInsta',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _closeOverlay,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // URL Preview
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.link,
                                color: Color(0xFF6C63FF),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.sharedUrl,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Download Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_isDownloading || _checkingPermissions) ? null : _startDownload,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _checkingPermissions
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Checking Permissions...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : _isDownloading
                                    ? const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Starting Download...',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.download_rounded),
                                          SizedBox(width: 8),
                                          Text(
                                            'Download Now',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startDownload() async {
    // Check permissions first
    if (!await _checkPermissions()) {
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      // Validate Instagram URL
      if (!InstagramHandler.isValidInstagramUrl(widget.sharedUrl)) {
        throw Exception("Invalid Instagram URL");
      }

      // Process Instagram URL (same logic as home screen)
      await _processInstagramUrl(widget.sharedUrl);
      
      // Show toast
      Fluttertoast.showToast(
        msg: "Downloading...",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      
      // Auto close after 1 second
      await Future.delayed(const Duration(seconds: 1));
      _closeOverlay();
      
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      
      Fluttertoast.showToast(
        msg: "Download failed: ${e.toString()}",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _processInstagramUrl(String url) async {
    // Same logic as home screen _processInstagramUrl
    final response = await http.get(
      Uri.parse('https://v1-w3sc.onrender.com/insta/api.php?url=${Uri.encodeComponent(url)}'),
      headers: {'User-Agent': 'Mozilla/5.0 (compatible; InstagramDownloader/1.0)'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      if (data['status'] == 'success' && data['data'] != null) {
        final mediaData = data['data'];
        
        if (mediaData is List && mediaData.isNotEmpty) {
          // Download first media item
          final mediaItem = mediaData[0];
          final downloadUrl = mediaItem['url'];
          final isVideo = mediaItem['type'] == 'video';
          
          if (downloadUrl != null) {
            await _downloadMedia(downloadUrl, isVideo);
          }
        }
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch media');
      }
    } else {
      throw Exception('API request failed');
    }
  }

  Future<void> _downloadMedia(String url, bool isVideo) async {
    // Background download with notification
    final fileName = 'instagram_${DateTime.now().millisecondsSinceEpoch}.${isVideo ? 'mp4' : 'jpg'}';
    
    // Start notification
    await NotificationService.showDownloadProgress(0, fileName);
    
    // Download file (simplified version)
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final directory = await getExternalStorageDirectory();
      final file = File('${directory!.path}/Download/$fileName');
      await file.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);
      
      // Complete notification
      await NotificationService.showDownloadComplete(fileName, true);
      
      // Save to history
      await DownloadHistory.addDownload(
        url: widget.sharedUrl,
        filename: fileName,
        filePath: file.path,
        type: isVideo ? 'video' : 'image',
      );
    }
  }

  Future<bool> _checkPermissions() async {
    setState(() {
      _checkingPermissions = true;
    });

    try {
      // Check system alert window permission (for overlay)
      var systemAlertStatus = await Permission.systemAlertWindow.status;
      if (!systemAlertStatus.isGranted) {
        systemAlertStatus = await Permission.systemAlertWindow.request();
        if (!systemAlertStatus.isGranted) {
          Fluttertoast.showToast(msg: "Overlay permission required");
          setState(() {
            _checkingPermissions = false;
          });
          return false;
        }
      }

      // Check storage permission
      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          Fluttertoast.showToast(msg: "Storage permission required");
          setState(() {
            _checkingPermissions = false;
          });
          return false;
        }
      }

      // Check manage external storage permission (Android 11+)
      var manageStorageStatus = await Permission.manageExternalStorage.status;
      if (!manageStorageStatus.isGranted) {
        manageStorageStatus = await Permission.manageExternalStorage.request();
        if (!manageStorageStatus.isGranted) {
          Fluttertoast.showToast(msg: "File access permission required");
          setState(() {
            _checkingPermissions = false;
          });
          return false;
        }
      }

      // Check notification permission
      var notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        notificationStatus = await Permission.notification.request();
        // Notification permission is optional, don't block download
      }

      setState(() {
        _checkingPermissions = false;
      });
      return true;
    } catch (e) {
      setState(() {
        _checkingPermissions = false;
      });
      Fluttertoast.showToast(msg: "Permission check failed");
      return false;
    }
  }

  void _closeOverlay() async {
    try {
      await platform.invokeMethod('closeOverlay');
    } catch (e) {
      Navigator.of(context).pop();
    }
  }
}
