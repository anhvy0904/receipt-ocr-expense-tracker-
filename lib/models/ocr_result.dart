import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Raw recognition output; no merchant, amount, or date inference is performed.
class OcrResult {
  OcrResult({required this.fullText, required List<TextBlock> blocks})
    : blocks = List.unmodifiable(blocks),
      lines = List.unmodifiable(blocks.expand((block) => block.lines));

  final String fullText;
  final List<TextBlock> blocks;
  final List<TextLine> lines;
}
