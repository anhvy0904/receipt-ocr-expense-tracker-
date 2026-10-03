import 'dart:io';

import 'package:flutter/material.dart';

class ReceiptPreviewScreen extends StatefulWidget {
  const ReceiptPreviewScreen({required this.imagePath, super.key});
  final String imagePath;

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  bool _accepted = false;
  bool _imageFailed = false;

  void _useReceipt() {
    if (_accepted || _imageFailed) return;
    setState(() => _accepted = true);
    // Ownership of this temporary crop passes to the caller; no permanent copy.
    Navigator.of(context).pop(widget.imagePath);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_accepted,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Receipt preview'),
          automaticallyImplyLeading: !_accepted,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: InteractiveViewer(
                  child: Center(
                    child: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.contain,
                      semanticLabel: 'Cropped receipt',
                      errorBuilder: (context, error, stack) {
                        if (!_imageFailed) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _imageFailed = true);
                          });
                        }
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'The photo could not be displayed. Retake the receipt.',
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _accepted
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Retake'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _accepted || _imageFailed
                            ? null
                            : _useReceipt,
                        child: const Text('Use Receipt'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
