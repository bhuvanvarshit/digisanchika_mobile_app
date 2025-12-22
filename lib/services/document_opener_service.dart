// lib/services/document_opener_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:digi_sanchika/models/document.dart';
import 'package:digi_sanchika/services/api_service.dart';
import 'package:digi_sanchika/services/my_documents_service.dart';
import 'package:digi_sanchika/local_storage.dart';
import 'package:digi_sanchika/presentations/screens/document_open_options.dart';

/// Service to handle document opening with double-tap
class DocumentOpenerService {
  static final DocumentOpenerService _instance =
      DocumentOpenerService._internal();
  factory DocumentOpenerService() => _instance;
  DocumentOpenerService._internal();

  // Double-tap tracking
  Document? _lastTappedDocument;
  DateTime? _lastTapTime;
  static const int _doubleTapThreshold = 350; // milliseconds

  /// Check if double-tap
  bool isDoubleTap(Document document) {
    final now = DateTime.now();
    final isSameDoc = _lastTappedDocument?.id == document.id;
    final isWithinThreshold =
        _lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < _doubleTapThreshold;

    _lastTappedDocument = document;
    _lastTapTime = now;

    return isSameDoc && isWithinThreshold;
  }

  /// Extract file type (matches your existing method)
  String getFileType(Document document) {
    final filename = document.name.toLowerCase();
    final ext = path.extension(filename);

    switch (ext) {
      case '.pdf':
        return 'PDF';
      case '.doc':
      case '.docx':
        return 'DOCX';
      case '.xls':
      case '.xlsx':
        return 'XLSX';
      case '.ppt':
      case '.pptx':
        return 'PPTX';
      case '.txt':
        return 'TXT';
      default:
        return ext.replaceAll('.', '').toUpperCase();
    }
  }

  /// Check if file exists locally
  Future<bool> isFileLocal(Document document) async {
    try {
      // Check your LocalStorageService
      final localDocs = await LocalStorageService.loadDocuments();
      return localDocs.any((doc) => doc.id == document.id);
    } catch (e) {
      return false;
    }
  }

  /// Download file using your existing service
  Future<File?> downloadDocument(Document document) async {
    try {
      if (!ApiService.isConnected) return null;

      final result = await MyDocumentsService.downloadDocument(document.id);

      if (result['success'] == true && result['data'] != null) {
        final tempDir = await getTemporaryDirectory();
        final safeName = document.name.replaceAll(RegExp(r'[^\w\.]'), '_');
        final filePath = '${tempDir.path}/$safeName';
        final file = File(filePath);

        await file.writeAsBytes(result['data'] as List<int>);
        return file;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Download error: $e');
      }
      return null;
    }
  }

  /// Open a specific version of a document
  Future<void> openDocumentVersion({
    required BuildContext context,
    required String documentId,
    required String versionNumber,
    required String originalFileName,
  }) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Downloading version $versionNumber...'),
            ],
          ),
          duration: const Duration(seconds: 30), // Long duration for download
        ),
      );

      // Download the specific version
      final result = await MyDocumentsService.downloadDocumentVersion(
        documentId: documentId,
        versionNumber: versionNumber,
      );

      // Clear loading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result['success'] == true) {
        // Get directory for saving
        final directory = await getTemporaryDirectory();

        // Create filename with version number
        String fileName = originalFileName;
        if (result['filename'] != null) {
          fileName = result['filename']!;
        } else {
          // Add version number to filename if not provided by server
          final extIndex = originalFileName.lastIndexOf('.');
          if (extIndex != -1) {
            final name = originalFileName.substring(0, extIndex);
            final ext = originalFileName.substring(extIndex);
            fileName = '${name}_v$versionNumber$ext';
          } else {
            fileName = '${originalFileName}_v$versionNumber';
          }
        }

        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);

        // Save the file
        await file.writeAsBytes(result['data'] as List<int>);

        // Open the file
        await _openFileWithFallback(context, filePath);
      } else {
        throw Exception(result['error'] ?? 'Failed to download version');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open version: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Helper method to open file with fallback for Android
  Future<void> _openFileWithFallback(
    BuildContext context,
    String filePath,
  ) async {
    try {
      final uriToOpen = Platform.isAndroid
          ? _getFileProviderUri(filePath)
          : filePath;

      if (kDebugMode) {
        print('📂 Opening file: $uriToOpen');
      }

      final result = await OpenFilex.open(uriToOpen);

      if (result.type != ResultType.done) {
        if (kDebugMode) {
          print('⚠ Could not open file automatically: ${result.message}');
        }

        // Try fallback
        if (Platform.isAndroid) {
          try {
            await OpenFilex.open(filePath);
          } catch (e) {
            _showOpenError(context, result.message);
          }
        } else {
          _showOpenError(context, result.message);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Generate FileProvider URI for Android
  String _getFileProviderUri(String filePath) {
    if (Platform.isAndroid) {
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          final fileName = file.path.split('/').last;
          return 'content://com.example.digi_sanchika.fileprovider/files/$fileName';
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠ Error creating FileProvider URI: $e');
        }
      }
    }
    return filePath;
  }

  /// Show error when file cannot be opened
  void _showOpenError(BuildContext context, String? message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not open file: ${message ?? 'Unknown error'}'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  /// Open document directly (without options dialog)
  Future<void> openDocumentDirectly({
    required BuildContext context,
    required Document document,
  }) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Downloading ${document.name}...'),
            ],
          ),
          duration: const Duration(seconds: 30),
        ),
      );

      final result = await MyDocumentsService.downloadDocument(document.id);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result['success'] == true && result['data'] != null) {
        final tempDir = await getTemporaryDirectory();
        final safeName = document.name.replaceAll(RegExp(r'[^\w\.]'), '_');
        final filePath = '${tempDir.path}/$safeName';
        final file = File(filePath);

        await file.writeAsBytes(result['data'] as List<int>);
        await _openFileWithFallback(context, filePath);
      } else {
        throw Exception(result['error'] ?? 'Failed to download document');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Main handler for double-tap
  void handleDoubleTap({
    required BuildContext context,
    required Document document,
  }) {
    final fileType = getFileType(document);

    // Show opening options
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) =>
          DocumentOpenOptionsDialog(document: document, fileType: fileType),
    );
  }
}
