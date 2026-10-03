import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:receiptwise/models/ocr_result.dart';
import 'package:receiptwise/services/ocr_service.dart';
import 'package:receiptwise/services/receipt_image_service.dart';
import 'package:receiptwise/services/receipt_import_service.dart';

class _Picker extends ImagePicker {
  XFile? selected;
  ImageSource? source;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    return selected;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async =>
      LostDataResponse(files: selected == null ? null : [selected!]);
}

class _Ocr extends OcrService {
  bool fail = false;
  String? path;
  @override
  Future<OcrResult> recognizeText(String imagePath) async {
    path = imagePath;
    if (fail) throw StateError('Recognition failed');
    return OcrResult(fullText: 'SHOP\nTong tien 150.000', blocks: []);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late File source;
  late _Picker picker;
  late _Ocr ocr;
  late ReceiptImportService service;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('receipt_import_test_');
    source = await File(
      '${root.path}/source.png',
    ).writeAsBytes(image.encodePng(image.Image(width: 800, height: 1200)));
    picker = _Picker()..selected = XFile(source.path);
    ocr = _Ocr();
    service = ReceiptImportService(
      picker: picker,
      ocr: ocr,
      images: ReceiptImageService(temporaryDirectoryProvider: () async => root),
    );
  });
  tearDown(() async {
    await service.dispose();
    await root.delete(recursive: true);
  });

  test(
    'gallery and picker camera normalize into owned temporary JPEG at full resolution',
    () async {
      for (final input in ImageSource.values) {
        final draft = await service.acquire(input);
        expect(picker.source, input);
        expect(draft!.imagePath, isNot(source.path));
        expect(ocr.path, draft.imagePath);
        expect(draft.ocrResult!.fullText, contains('150.000'));
        final normalized = image.decodeJpg(
          await File(draft.imagePath!).readAsBytes(),
        )!;
        expect(normalized.width, 800);
        expect(normalized.height, 1200);
        await service.discard(draft.imagePath!);
        expect(await File(draft.imagePath!).exists(), isFalse);
        expect(await source.exists(), isTrue);
      }
    },
  );

  test(
    'cancel creates no draft; OCR failure still returns manual-review image',
    () async {
      picker.selected = null;
      expect(await service.acquire(ImageSource.gallery), isNull);
      picker.selected = XFile(source.path);
      ocr.fail = true;
      final draft = await service.acquire(ImageSource.gallery);
      expect(draft!.ocrFailed, isTrue);
      expect(draft.ocrResult, isNull);
      expect(await File(draft.imagePath!).exists(), isTrue);
    },
  );

  test(
    'invalid image rolls back owned temporary files and preserves source',
    () async {
      await source.writeAsBytes([1, 2, 3]);
      await expectLater(
        service.acquire(ImageSource.gallery),
        throwsFormatException,
      );
      expect(await root.list().toList(), [isA<File>()]);
      expect(await source.exists(), isTrue);
    },
  );

  test(
    'Android lost image recovery exposes selection for explicit review',
    () async {
      expect((await service.recoverLostImage())!.path, source.path);
      picker.selected = null;
      expect(await service.recoverLostImage(), isNull);
    },
  );
}
