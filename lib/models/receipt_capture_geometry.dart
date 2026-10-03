import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Geometry of the exact preview frame visible when Capture was pressed.
class ReceiptCaptureGeometry {
  const ReceiptCaptureGeometry({
    required this.viewport,
    required this.frame,
    required this.previewSize,
    required this.orientation,
    required this.sensorOrientation,
    this.mirroredPreview = false,
  });

  final Size viewport;
  final Rect frame;

  /// Preview dimensions after applying the displayed orientation.
  final Size previewSize;
  final DeviceOrientation orientation;
  final int sensorOrientation;
  final bool mirroredPreview;
}

DeviceOrientation receiptPreviewOrientation(CameraValue value) =>
    value.previewPauseOrientation ??
    value.lockedCaptureOrientation ??
    value.deviceOrientation;

Size orientedReceiptPreviewSize(CameraValue value) {
  final orientation = receiptPreviewOrientation(value);
  final size = value.previewSize!;
  final landscape =
      orientation == DeviceOrientation.landscapeLeft ||
      orientation == DeviceOrientation.landscapeRight;
  return landscape ? size : Size(size.height, size.width);
}

/// Shared by the overlay and capture metadata, including the controls' insets.
Rect receiptFrameForViewport(
  Size viewport,
  EdgeInsets safePadding, {
  double controlsHeight = 112,
}) {
  final top = safePadding.top + 72;
  final bottom = safePadding.bottom + controlsHeight;
  final height = math.max(0.0, viewport.height - top - bottom - 32);
  final width = math.min(math.max(0.0, viewport.width - 48) * .8, height / 1.8);
  return Rect.fromCenter(
    center: Offset(viewport.width / 2, top + 16 + height / 2),
    width: width,
    height: width * 1.8,
  );
}
