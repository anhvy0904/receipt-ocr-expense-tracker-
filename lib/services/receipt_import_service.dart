import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

import '../models/ocr_result.dart';
import '../models/receipt_review_draft.dart';
import 'ocr_service.dart';
import 'receipt_image_service.dart';

class ReceiptImportService {
  ReceiptImportService({
    ImagePicker? picker,
    ReceiptImageService? images,
    OcrService? ocr,
  }) : _picker = picker ?? ImagePicker(),
       _images = images ?? ReceiptImageService(),
       _ocr = ocr ?? OcrService();

  final ImagePicker _picker;
  final ReceiptImageService _images;
  final OcrService _ocr;

  Future<XFile?> recoverLostImage() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final recovered = await _picker.retrieveLostData();
    if (recovered.exception != null) throw recovered.exception!;
    return recovered.files?.firstOrNull;
  }

  Future<ReceiptReviewDraft?> acquire(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      requestFullMetadata: false,
    );
    return picked == null ? null : prepare(picked);
  }

  Future<ReceiptReviewDraft> prepare(XFile picked) async {
    final destination = await _images.createTemporaryReceiptPath();
    try {
      await compute(_normalizeReceipt, (
        source: picked.path,
        destination: destination,
      ));
    } catch (_) {
      try {
        await _images.discardTemporaryPhoto(destination);
      } catch (_) {
        /* Preserve processing failure. */
      }
      rethrow;
    }
    OcrResult? result;
    bool failed = false;
    try {
      result = await _ocr.recognizeText(destination);
    } catch (_) {
      failed = true;
    }
    return ReceiptReviewDraft(
      imagePath: destination,
      imageDescription: 'Selected receipt image',
      ocrResult: result,
      ocrFailed: failed,
    );
  }

  Future<void> discard(String path) => _images.discardTemporaryPhoto(path);
  Future<void> dispose() => _ocr.dispose();
}

/// Gallery/camera picker input has no live scanner frame: retain the entire image.
Future<void> _normalizeReceipt(
  ({String source, String destination}) paths,
) async {
  final bytes = await File(paths.source).readAsBytes();
  image.Image? decoded;
  try {
    decoded = image.decodeImage(bytes);
  } catch (_) {
    throw const FormatException('Invalid receipt image');
  }
  if (decoded == null) throw const FormatException('Unsupported receipt image');
  final upright = image.bakeOrientation(decoded);
  await File(
    paths.destination,
  ).writeAsBytes(image.encodeJpg(upright, quality: 95), flush: true);
}
