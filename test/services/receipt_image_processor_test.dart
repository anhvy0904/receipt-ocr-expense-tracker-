import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:receiptwise/models/receipt_capture_geometry.dart';
import 'package:receiptwise/services/receipt_image_processor.dart';
import 'package:receiptwise/services/receipt_image_service.dart';

ReceiptCaptureGeometry geometry({
  Size viewport = const Size(400, 800),
  Rect frame = const Rect.fromLTRB(100, 200, 300, 600),
  Size preview = const Size(1000, 2000),
  DeviceOrientation orientation = DeviceOrientation.portraitUp,
  bool mirrored = false,
}) => ReceiptCaptureGeometry(
  viewport: viewport,
  frame: frame,
  previewSize: preview,
  orientation: orientation,
  sensorOrientation: 90,
  mirroredPreview: mirrored,
);

void expectBounds(Rect actual, Rect expected) {
  // Outward rounding can add one boundary pixel, never remove receipt pixels.
  expect(actual.left, closeTo(expected.left, 1));
  expect(actual.top, closeTo(expected.top, 1));
  expect(actual.right, closeTo(expected.right, 1));
  expect(actual.bottom, closeTo(expected.bottom, 1));
}

void main() {
  test('same-aspect capture maps the rectangle to full-resolution pixels', () {
    expect(
      receiptCropBounds(geometry(), const Size(2000, 4000)),
      const Rect.fromLTRB(500, 1000, 1500, 3000),
    );
  });

  test(
    'portrait cover crop and 16:9 preview of 4:3 still are both inverted',
    () {
      final metadata = geometry(
        viewport: const Size(300, 600),
        preview: const Size(1080, 1920),
        frame: const Rect.fromLTRB(60, 120, 240, 480),
      );
      expectBounds(
        receiptCropBounds(metadata, const Size(3000, 4000)),
        const Rect.fromLTRB(900, 800, 2100, 3200),
      );
    },
  );

  test('landscape capture accounts for vertical preview cropping', () {
    final metadata = geometry(
      viewport: const Size(800, 400),
      preview: const Size(1600, 900),
      frame: const Rect.fromLTRB(200, 100, 600, 300),
      orientation: DeviceOrientation.landscapeRight,
    );
    expectBounds(
      receiptCropBounds(metadata, const Size(4000, 3000)),
      const Rect.fromLTRB(1000, 1000, 3000, 2000),
    );
  });

  test(
    'opposite-axis cover crops cannot be replaced by direct photo scaling',
    () {
      final metadata = geometry(
        viewport: const Size(1000, 1000),
        preview: const Size(2000, 1000),
        frame: const Rect.fromLTRB(250, 250, 750, 750),
        orientation: DeviceOrientation.landscapeLeft,
      );
      expect(
        receiptCropBounds(metadata, const Size(4000, 3000)),
        const Rect.fromLTRB(1500, 1000, 2500, 2000),
      );
    },
  );

  test(
    'front-camera mirror moves an off-center frame to the correct pixels',
    () {
      final metadata = geometry(
        frame: const Rect.fromLTRB(0, 200, 100, 600),
        mirrored: true,
      );
      expect(
        receiptCropBounds(metadata, const Size(2000, 4000)),
        const Rect.fromLTRB(1500, 1000, 2000, 3000),
      );
    },
  );

  test(
    'EXIF rotation is baked once and missing orientation uses sensor rotation',
    () {
      final pixels = img.Image(width: 4, height: 2);
      pixels.setPixelRgb(0, 1, 200, 10, 20);
      pixels.exif.imageIfd.orientation = 6;
      final metadata = geometry(preview: const Size(2, 4));
      final normalized = uprightReceiptImage(pixels, metadata);
      expect(normalized.width, 2);
      expect(normalized.height, 4);
      expect(normalized.getPixel(0, 0).r, 200);
      expect(normalized.exif.imageIfd.orientation, 1);
      final again = uprightReceiptImage(normalized, metadata);
      expect(again.getPixel(0, 0).r, 200);
      pixels.exif.imageIfd.orientation = null;
      final fallback = uprightReceiptImage(pixels, metadata);
      expect(fallback.width, 2);
      expect(fallback.height, 4);
      expect(fallback.getPixel(0, 0).r, 200);
    },
  );

  test('all eight EXIF orientations preserve the correct corner pixels', () {
    final expectedCorner = [0, 30, 70, 40, 0, 40, 70, 30];
    for (var tag = 1; tag <= 8; tag++) {
      final pixels = img.Image(width: 4, height: 2);
      for (var y = 0; y < 2; y++) {
        for (var x = 0; x < 4; x++) {
          pixels.setPixelRgb(x, y, x * 10 + y * 40, 0, 0);
        }
      }
      pixels.exif.imageIfd.orientation = tag;
      final rotated = tag >= 5;
      final normalized = uprightReceiptImage(
        pixels,
        geometry(
          preview: rotated ? const Size(2, 4) : const Size(4, 2),
          orientation: rotated
              ? DeviceOrientation.portraitUp
              : DeviceOrientation.landscapeLeft,
        ),
      );
      expect(normalized.width, rotated ? 2 : 4, reason: 'EXIF $tag');
      expect(normalized.height, rotated ? 4 : 2, reason: 'EXIF $tag');
      expect(
        normalized.getPixel(0, 0).r,
        expectedCorner[tag - 1],
        reason: 'EXIF $tag',
      );
    }
  });

  test('invalid and offscreen geometry is rejected', () {
    expect(
      () => receiptCropBounds(
        geometry(viewport: Size.zero),
        const Size(2000, 4000),
      ),
      throwsArgumentError,
    );
    expect(
      () => receiptCropBounds(
        geometry(frame: const Rect.fromLTRB(500, 0, 600, 100)),
        const Size(2000, 4000),
      ),
      throwsArgumentError,
    );
  });

  test('frame calculation remains vertical and respects control insets', () {
    for (final size in [const Size(400, 800), const Size(800, 400)]) {
      final frame = receiptFrameForViewport(
        size,
        const EdgeInsets.only(top: 24, bottom: 16),
      );
      expect(frame.height, greaterThan(frame.width));
      expect(frame.top, greaterThanOrEqualTo(24 + 72));
      expect(frame.bottom, lessThanOrEqualTo(size.height - 16 - 112));
    }
  });

  test(
    'processor writes a native-resolution crop only to temporary storage',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'receiptwise_crop_test_',
      );
      try {
        final source = File(path.join(temporary.path, 'source.png'));
        final pixels = img.Image(width: 200, height: 400);
        img.fill(pixels, color: img.ColorRgb8(220, 100, 30));
        await source.writeAsBytes(img.encodePng(pixels));
        final storage = ReceiptImageService(
          temporaryDirectoryProvider: () async => temporary,
        );
        final output = await ReceiptImageProcessor(
          imageStorage: storage,
        ).cropReceipt(sourcePath: source.path, geometry: geometry());
        expect(path.isWithin(temporary.path, output), isTrue);
        final crop = img.decodeImage(await File(output).readAsBytes())!;
        expect(crop.width, 100);
        expect(crop.height, 200);
        expect(crop.getPixel(50, 100).r, closeTo(220, 3));
        expect(await source.exists(), isTrue);
        await storage.discardTemporaryPhoto(output);
        expect(await File(output).exists(), isFalse);
        expect(await Directory(path.dirname(output)).exists(), isFalse);
        expect(await source.exists(), isTrue);
      } finally {
        await temporary.delete(recursive: true);
      }
    },
  );

  test(
    'failed decoding cleans the partial crop and its temporary directory',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'receiptwise_bad_crop_test_',
      );
      try {
        final source = File(path.join(temporary.path, 'bad.jpg'));
        await source.writeAsString('not an image');
        final storage = ReceiptImageService(
          temporaryDirectoryProvider: () async => temporary,
        );
        await expectLater(
          ReceiptImageProcessor(
            imageStorage: storage,
          ).cropReceipt(sourcePath: source.path, geometry: geometry()),
          throwsFormatException,
        );
        expect(
          await temporary.list().where((entry) => entry is Directory).toList(),
          isEmpty,
        );
      } finally {
        await temporary.delete(recursive: true);
      }
    },
  );
}
