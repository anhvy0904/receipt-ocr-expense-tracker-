import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/ocr_result.dart';

/// Uses the bundled native Latin recognizer. No network or database operations.
class OcrService {
  TextRecognizer? _recognizer;
  Future<void> _pending = Future.value();
  Future<void>? _disposal;
  bool _closed = false;

  Future<OcrResult> recognizeText(String imagePath) {
    if (_closed) return Future.error(StateError('OCR service is disposed.'));
    final operation = _pending.then((_) async {
      final stopwatch = Stopwatch()..start();
      try {
        final recognizer = _recognizer ??= TextRecognizer(
          script: TextRecognitionScript.latin,
        );
        final recognized = await recognizer.processImage(
          InputImage.fromFilePath(imagePath),
        );
        return OcrResult(fullText: recognized.text, blocks: recognized.blocks);
      } finally {
        stopwatch.stop();
        if (kDebugMode) {
          debugPrint(
            'OCR processing duration: ${stopwatch.elapsedMilliseconds} ms',
          );
        }
      }
    });
    // A failed request must not poison later requests or prevent cleanup.
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  /// Wait for accepted requests before closing the native recognizer once.
  Future<void> dispose() {
    _closed = true;
    return _disposal ??= _pending.then((_) async {
      await _recognizer?.close();
    });
  }
}
