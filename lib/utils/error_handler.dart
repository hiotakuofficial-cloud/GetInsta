import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';
import 'dart:io';

enum ErrorType {
  network,
  timeout,
  server,
  invalidUrl,
  permissionDenied,
  fileNotFound,
  unknown,
}

class AppError {
  final ErrorType type;
  final String message;
  final String? details;
  final dynamic originalError;

  AppError({
    required this.type,
    required this.message,
    this.details,
    this.originalError,
  });

  String get userFriendlyMessage {
    switch (type) {
      case ErrorType.network:
        return 'No internet connection. Please check your network.';
      case ErrorType.timeout:
        return 'Request timed out. Please try again.';
      case ErrorType.server:
        return 'Server error. Please try again later.';
      case ErrorType.invalidUrl:
        return 'Invalid URL. Please check and try again.';
      case ErrorType.permissionDenied:
        return 'Permission denied. Please grant required permissions.';
      case ErrorType.fileNotFound:
        return 'File not found. It may have been moved or deleted.';
      case ErrorType.unknown:
        return 'Something went wrong. Please try again.';
    }
  }

  IconData get icon {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off_rounded;
      case ErrorType.timeout:
        return Icons.hourglass_empty_rounded;
      case ErrorType.server:
        return Icons.cloud_off_rounded;
      case ErrorType.invalidUrl:
        return Icons.link_off_rounded;
      case ErrorType.permissionDenied:
        return Icons.lock_rounded;
      case ErrorType.fileNotFound:
        return Icons.insert_drive_file_outlined;
      case ErrorType.unknown:
        return Icons.error_outline_rounded;
    }
  }

  Color get color {
    switch (type) {
      case ErrorType.network:
        return Colors.orange;
      case ErrorType.timeout:
        return Colors.amber;
      case ErrorType.server:
        return Colors.red;
      case ErrorType.invalidUrl:
        return Colors.deepOrange;
      case ErrorType.permissionDenied:
        return Colors.deepPurple;
      case ErrorType.fileNotFound:
        return Colors.grey;
      case ErrorType.unknown:
        return Colors.red;
    }
  }
}

class ErrorHandler {
  static AppError handleError(dynamic error) {
    if (error is SocketException) {
      return AppError(
        type: ErrorType.network,
        message: 'Network connection failed',
        details: error.message,
        originalError: error,
      );
    } else if (error is TimeoutException) {
      return AppError(
        type: ErrorType.timeout,
        message: 'Request timed out',
        details: error.message,
        originalError: error,
      );
    } else if (error is HttpException) {
      return AppError(
        type: ErrorType.server,
        message: 'Server error occurred',
        details: error.message,
        originalError: error,
      );
    } else if (error is FormatException) {
      return AppError(
        type: ErrorType.invalidUrl,
        message: 'Invalid format',
        details: error.message,
        originalError: error,
      );
    } else if (error is FileSystemException) {
      return AppError(
        type: ErrorType.fileNotFound,
        message: 'File system error',
        details: error.message,
        originalError: error,
      );
    } else {
      return AppError(
        type: ErrorType.unknown,
        message: 'An unexpected error occurred',
        details: error.toString(),
        originalError: error,
      );
    }
  }

  static void showErrorDialog(BuildContext context, AppError error,
      {VoidCallback? onRetry}) {
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
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: error.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      error.icon,
                      color: error.color,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    error.type.toString().split('.').last.toUpperCase(),
                    style: TextStyle(
                      color: error.color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    error.userFriendlyMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  if (error.details != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        error.details!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (onRetry != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onRetry();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: error.color,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Retry',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void showErrorSnackbar(BuildContext context, AppError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(error.icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error.userFriendlyMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: error.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void showErrorToast(AppError error) {
    Fluttertoast.showToast(
      msg: error.userFriendlyMessage,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
      backgroundColor: error.color,
      textColor: Colors.white,
      fontSize: 14,
    );
  }

  static void showCustomErrorOverlay(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 400),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -50 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            onEnd: () {
              Future.delayed(duration, () {
                overlayEntry.remove();
              });
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: error.color.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: error.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      error.icon,
                      color: error.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          error.type.toString().split('.').last.toUpperCase(),
                          style: TextStyle(
                            color: error.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          error.userFriendlyMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        overlayEntry.remove();
                        onRetry();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: error.color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
  }
}

class SafeOperation {
  static Future<T?> execute<T>({
    required Future<T> Function() operation,
    required BuildContext context,
    String? loadingMessage,
    bool showErrorDialog = false,
    bool showErrorSnackbar = true,
    VoidCallback? onError,
  }) async {
    try {
      return await operation();
    } catch (error) {
      final appError = ErrorHandler.handleError(error);

      if (showErrorDialog) {
        ErrorHandler.showErrorDialog(
          context,
          appError,
          onRetry: onError,
        );
      } else if (showErrorSnackbar) {
        ErrorHandler.showErrorSnackbar(context, appError);
      } else {
        ErrorHandler.showErrorToast(appError);
      }

      onError?.call();
      return null;
    }
  }
}

Future<T?> withRetry<T>({
  required Future<T> Function() operation,
  int maxAttempts = 3,
  Duration delay = const Duration(seconds: 2),
  bool Function(dynamic)? shouldRetry,
}) async {
  int attempt = 0;

  while (attempt < maxAttempts) {
    try {
      return await operation();
    } catch (error) {
      attempt++;

      if (attempt >= maxAttempts) {
        rethrow;
      }

      if (shouldRetry != null && !shouldRetry(error)) {
        rethrow;
      }

      await Future.delayed(delay * attempt);
    }
  }

  return null;
}
