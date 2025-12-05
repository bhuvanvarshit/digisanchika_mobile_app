// lib/services/document_opener_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path; // Fixed import
import 'package:path_provider/path_provider.dart';
import 'package:digi_sanchika/models/document.dart';
import 'package:digi_sanchika/services/api_service.dart';
import 'package:digi_sanchika/services/my_documents_service.dart';
import 'package:digi_sanchika/local_storage.dart';
import 'package:digi_sanchika/presentations/screens/document_open_options.dart'; // Add this import

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
      print('Download error: $e');
      return null;
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
      builder: (context) => DocumentOpenOptionsDialog(
        // Fixed class name
        document: document,
        fileType: fileType,
      ),
    );
  }
}
