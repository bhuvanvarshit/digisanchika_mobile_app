// lib/presentations/screens/document_preview_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart'; // For PDF viewing
import 'package:digi_sanchika/models/document.dart';
import 'package:digi_sanchika/services/document_opener_service.dart';
import 'package:digi_sanchika/presentations/screens/document_open_options.dart'; // Add this import

class DocumentPreviewScreen extends StatefulWidget {
  final Document document;
  final String fileType;
  final File? localFile;

  const DocumentPreviewScreen({
    super.key,
    required this.document,
    required this.fileType,
    this.localFile,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  late PdfController? _pdfController;
  bool _isLoading = true;
  String _errorMessage = '';
  String _textContent = '';

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    try {
      if (widget.fileType == 'PDF') {
        await _loadPdf();
      } else if (widget.fileType == 'TXT') {
        await _loadText();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading document: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPdf() async {
    try {
      // Try to get local file first
      File? file = widget.localFile;
      if (file == null || !await file.exists()) {
        // Download if not available
        final opener = DocumentOpenerService();
        file = await opener.downloadDocument(widget.document);
      }

      if (file != null && await file.exists()) {
        _pdfController = PdfController(
          document: PdfDocument.openFile(file.path),
        );
      } else {
        throw Exception('PDF file not available');
      }
    } catch (e) {
      throw Exception('Failed to load PDF: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadText() async {
    try {
      File? file = widget.localFile;
      if (file == null || !await file.exists()) {
        final opener = DocumentOpenerService();
        file = await opener.downloadDocument(widget.document);
      }

      if (file != null && await file.exists()) {
        _textContent = await file.readAsString();
      } else {
        _textContent = 'File not available for preview';
      }
    } catch (e) {
      _textContent = 'Error loading text: $e';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.name, overflow: TextOverflow.ellipsis),
        backgroundColor: const Color.fromARGB(255, 43, 65, 189),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadDocument,
            tooltip: 'Download',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareDocument,
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: _showOpenOptions,
            tooltip: 'Open with other apps',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? _buildErrorView()
          : _buildPreviewContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'Cannot Preview Document',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showOpenOptions,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Try Opening with Another App'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewContent() {
    switch (widget.fileType) {
      case 'PDF':
        return _buildPdfViewer();
      case 'TXT':
        return _buildTextViewer();
      default:
        return _buildUnsupportedViewer();
    }
  }

  Widget _buildPdfViewer() {
    if (_pdfController == null) {
      return _buildErrorView();
    }

    return Column(
      children: [
        // PDF controls - REMOVED zoom buttons and simplified
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              // Note: pdfx doesn't support direct zoom control via controller
              // Remove zoom buttons or use different approach
              const Spacer(),
              // Show current page using pageListenable
              ValueListenableBuilder<int>(
                valueListenable: _pdfController!.pageListenable,
                builder: (context, page, child) {
                  return Text(
                    'Page $page',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  );
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _pdfController?.previousPage(
                  curve: Curves.easeIn,
                  duration: const Duration(milliseconds: 100),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _pdfController?.nextPage(
                  curve: Curves.easeIn,
                  duration: const Duration(milliseconds: 100),
                ),
              ),
            ],
          ),
        ),

        // PDF view
        Expanded(
          child: PdfView(
            controller: _pdfController!,
            scrollDirection: Axis.vertical,
            // Note: You can remove or keep the renderer based on your needs
            // renderer: (PdfPage page) =>
            //     page.render(width: page.width * 2, height: page.height * 2),
          ),
        ),
      ],
    );
  }

  Widget _buildTextViewer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: SelectableText(
        _textContent,
        style: const TextStyle(fontSize: 16, height: 1.5),
      ),
    );
  }

  Widget _buildUnsupportedViewer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getFileIcon(widget.fileType), size: 80, color: Colors.orange),
          const SizedBox(height: 20),
          Text(
            '${widget.fileType} Preview',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Built-in preview not available for ${widget.fileType} files',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showOpenOptions,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open with Another App'),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'DOCX':
      case 'DOC':
        return Icons.description;
      case 'XLSX':
      case 'XLS':
        return Icons.table_chart;
      case 'PPTX':
      case 'PPT':
        return Icons.slideshow;
      case 'TXT':
        return Icons.text_fields;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _downloadDocument() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${widget.document.name}...'),
        backgroundColor: Colors.blue,
      ),
    );
    await Future.delayed(const Duration(seconds: 2));

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download complete'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _shareDocument() async {
    // TODO: Implement sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share feature coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showOpenOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DocumentOpenOptionsDialog(
        // Fixed class name
        document: widget.document,
        fileType: widget.fileType,
      ),
    );
  }
}
