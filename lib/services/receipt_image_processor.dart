import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/receipt_capture_geometry.dart';
import 'receipt_image_service.dart';

/// Inverts preview cover scaling, then maps the preview's centered sensor crop
/// into the upright, full-resolution still image. No resizing is performed.
Rect receiptCropBounds(ReceiptCaptureGeometry geometry, Size imageSize) {
  final viewport = geometry.viewport;
  final preview = geometry.previewSize;
  if (viewport.isEmpty ||
      preview.isEmpty ||
      imageSize.isEmpty ||
      !viewport.width.isFinite ||
      !viewport.height.isFinite ||
      !preview.width.isFinite ||
      !preview.height.isFinite ||
      !imageSize.width.isFinite ||
      !imageSize.height.isFinite ||
      !geometry.frame.isFinite ||
      geometry.frame.isEmpty) {
    throw ArgumentError('Receipt crop geometry must be finite and non-empty');
  }
  final frame = geometry.frame.intersect(Offset.zero & viewport);
  if (frame.isEmpty) {
    throw ArgumentError('Receipt frame is outside the preview');
  }
  final cover = applyBoxFit(BoxFit.cover, preview, viewport);
  final visiblePreview = Alignment.center.inscribe(
    cover.source,
    Offset.zero & preview,
  );
  final left =
      (visiblePreview.left +
          frame.left / viewport.width * visiblePreview.width) /
      preview.width;
  final right =
      (visiblePreview.left +
          frame.right / viewport.width * visiblePreview.width) /
      preview.width;
  final top =
      (visiblePreview.top +
          frame.top / viewport.height * visiblePreview.height) /
      preview.height;
  final bottom =
      (visiblePreview.top +
          frame.bottom / viewport.height * visiblePreview.height) /
      preview.height;

  // A 16:9 preview of a 4:3 still uses the central sensor region, not the entire
  // still stretched to the preview. Both stages must be inverted separately.
  final sensorFit = applyBoxFit(BoxFit.cover, imageSize, preview);
  final sensorRegion = Alignment.center.inscribe(
    sensorFit.source,
    Offset.zero & imageSize,
  );
  final x1 = geometry.mirroredPreview ? 1 - right : left;
  final x2 = geometry.mirroredPreview ? 1 - left : right;
  final x = (sensorRegion.left + x1 * sensorRegion.width).floor().clamp(
    0,
    imageSize.width.toInt() - 1,
  );
  final y = (sensorRegion.top + top * sensorRegion.height).floor().clamp(
    0,
    imageSize.height.toInt() - 1,
  );
  final endX = (sensorRegion.left + x2 * sensorRegion.width).ceil().clamp(
    x + 1,
    imageSize.width.toInt(),
  );
  final endY = (sensorRegion.top + bottom * sensorRegion.height).ceil().clamp(
    y + 1,
    imageSize.height.toInt(),
  );
  return Rect.fromLTRB(
    x.toDouble(),
    y.toDouble(),
    endX.toDouble(),
    endY.toDouble(),
  );
}

/// Normalizes camera EXIF rotation/mirroring before interpreting crop pixels.
img.Image uprightReceiptImage(
  img.Image image,
  ReceiptCaptureGeometry geometry,
) {
  final orientation = image.exif.imageIfd.orientation;
  var upright = img.bakeOrientation(image);
  final portrait = geometry.previewSize.height > geometry.previewSize.width;
  // Camera plugins normally provide EXIF or already-upright pixels. For a
  // missing/normal tag with swapped dimensions, use sensor/device orientation.
  if ((orientation == null || orientation == 1) &&
      upright.width != upright.height &&
      portrait != (upright.height > upright.width)) {
    final deviceRotation = switch (geometry.orientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final rotation =
        (geometry.sensorOrientation +
            (geometry.mirroredPreview ? deviceRotation : -deviceRotation)) %
        360;
    if (rotation % 180 != 90) {
      throw StateError(
        'The photo orientation does not match the captured preview',
      );
    }
    upright = img.copyRotate(upright, angle: rotation);
  }
  // Pixels are now upright; retaining the old EXIF rotation would rotate twice.
  upright.exif.imageIfd.orientation = 1;
  return upright;
}

class ReceiptImageProcessor {
  ReceiptImageProcessor({ReceiptImageService? imageStorage})
    : _imageStorage = imageStorage ?? ReceiptImageService();
  final ReceiptImageService _imageStorage;

  Future<String> cropReceipt({
    required String sourcePath,
    required ReceiptCaptureGeometry geometry,
  }) async {
    final outputPath = await _imageStorage.createTemporaryReceiptPath();
    try {
      await compute(_processReceipt, (sourcePath, outputPath, geometry));
      return outputPath;
    } catch (_) {
      try {
        await _imageStorage.discardTemporaryPhoto(outputPath);
      } catch (error) {
        if (kDebugMode) debugPrint('Failed crop cleanup: $error');
      }
      rethrow;
    }
  }
}

Future<void> _processReceipt(
  (String, String, ReceiptCaptureGeometry) request,
) async {
  final (sourcePath, outputPath, geometry) = request;
  final decoded = img.decodeImage(await File(sourcePath).readAsBytes());
  if (decoded == null) {
    throw const FormatException('Captured photo could not be decoded');
  }
  final upright = uprightReceiptImage(decoded, geometry);
  final bounds = receiptCropBounds(
    geometry,
    Size(upright.width.toDouble(), upright.height.toDouble()),
  );
  final cropped = img.copyCrop(
    upright,
    x: bounds.left.toInt(),
    y: bounds.top.toInt(),
    width: bounds.width.toInt(),
    height: bounds.height.toInt(),
  );
  // Strip obsolete full-image EXIF dimensions/thumbnail and preserve the pixels.
  cropped.exif = img.ExifData();
  await File(
    outputPath,
  ).writeAsBytes(img.encodeJpg(cropped, quality: 95), flush: true);
}
