import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/transaction_model.dart';
import '../../services/receipt_import_service.dart';
import '../../services/receipt_save_service.dart';
import '../widgets/placeholder_content.dart';
import 'review_receipt_screen.dart';

class ReceiptImportScreen extends StatefulWidget {
  const ReceiptImportScreen({
    required this.service,
    required this.saveService,
    this.source = ImageSource.gallery,
    this.recoveredImage,
    super.key,
  });
  final ReceiptImportService service;
  final ReceiptSaveService saveService;
  final ImageSource source;
  final XFile? recoveredImage;

  @override
  State<ReceiptImportScreen> createState() => _ReceiptImportScreenState();
}

class _ReceiptImportScreenState extends State<ReceiptImportScreen> {
  bool _busy = true;
  bool _failed = false;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  Future<void> _start() async {
    if (_running) return;
    _running = true;
    setState(() {
      _busy = true;
      _failed = false;
    });
    String? temporary;
    try {
      final draft = widget.recoveredImage == null
          ? await widget.service.acquire(widget.source)
          : await widget.service.prepare(widget.recoveredImage!);
      temporary = draft?.imagePath;
      if (!mounted) return;
      if (draft == null) {
        Navigator.of(context).pop();
        return;
      }
      final saved = await Navigator.of(context).push<TransactionModel>(
        MaterialPageRoute(
          builder: (_) => ReviewReceiptScreen(
            draft: draft,
            canRetake: false,
            saveService: widget.saveService,
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (temporary != null) {
        try {
          await widget.service.discard(temporary);
        } catch (error) {
          if (kDebugMode) debugPrint('Imported receipt cleanup failed: $error');
        }
      }
      if (mounted) setState(() => _busy = false);
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Receipt image')),
      body: SafeArea(
        child: _failed
            ? PlaceholderContent(
                icon: Icons.error_outline,
                title: 'Could not open receipt image',
                description:
                    'Check camera/photo access or choose a supported image.',
                action: Column(
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _start,
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              )
            : const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Selecting image and reading receipt…'),
                  ],
                ),
              ),
      ),
    ),
  );
}
