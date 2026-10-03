import 'dart:io';

import 'package:flutter/material.dart';

class ReceiptImage extends StatelessWidget {
  const ReceiptImage({
    required this.imagePath,
    this.thumbnail = false,
    super.key,
  });
  final String? imagePath;
  final bool thumbnail;

  Widget _missing() => Center(
    child: thumbnail
        ? const Icon(
            Icons.receipt_long_outlined,
            semanticLabel: 'Receipt image unavailable',
          )
        : const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Receipt image unavailable.'),
          ),
  );

  @override
  Widget build(BuildContext context) {
    final photo = imagePath == null || imagePath!.isEmpty
        ? _missing()
        : Image.file(
            File(imagePath!),
            fit: thumbnail ? BoxFit.cover : BoxFit.contain,
            semanticLabel: thumbnail
                ? 'Receipt thumbnail'
                : 'Full receipt image',
            cacheWidth: thumbnail ? 160 : null,
            errorBuilder: (_, error, stack) => _missing(),
          );
    if (thumbnail) {
      return SizedBox(
        width: 64,
        height: 80,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: photo,
          ),
        ),
      );
    }
    return SizedBox(height: 320, child: InteractiveViewer(child: photo));
  }
}
