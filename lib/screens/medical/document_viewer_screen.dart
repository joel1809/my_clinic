import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

import '../../widgets/shared.dart';

/// Lecteur PDF intégré : télécharge le document via son URL signée puis
/// l'affiche dans l'application (zoom au pincement, défilement des pages).
class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  PdfControllerPinch? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _controller?.dispose();
      _controller = null;
    });

    try {
      final response = await http
          .get(Uri.parse(widget.url))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('Téléchargement impossible (${response.statusCode}).');
      }
      if (!mounted) return;
      setState(() {
        _controller = PdfControllerPinch(
          document: PdfDocument.openData(response.bodyBytes),
        );
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      ),
      body: _error != null
          ? ErrorView(error: _error!, onRetry: _load)
          : _controller == null
              ? const Center(child: CircularProgressIndicator())
              : PdfViewPinch(controller: _controller!),
    );
  }
}
