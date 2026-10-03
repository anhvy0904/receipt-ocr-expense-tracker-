import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../models/receipt_capture_geometry.dart';

/// Maps a visible tap into preview coordinates, accounting for cover cropping.
Offset focusPointForPreview(Offset tap, Size viewport, double aspectRatio) {
  final source = Size(aspectRatio, 1);
  final fitted = applyBoxFit(BoxFit.cover, source, viewport);
  final crop = Alignment.center.inscribe(fitted.source, Offset.zero & source);
  return Offset(
    ((crop.left + tap.dx / viewport.width * crop.width) / source.width).clamp(
      0,
      1,
    ),
    (crop.top + tap.dy / viewport.height * crop.height).clamp(0, 1),
  );
}

class ReceiptCameraPreview extends StatelessWidget {
  const ReceiptCameraPreview({
    required this.controller,
    required this.onFocus,
    super.key,
  });
  final CameraController controller;
  final ValueChanged<Offset> onFocus;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CameraValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        if (!value.isInitialized) return const SizedBox.expand();
        final size = orientedReceiptPreviewSize(value);
        final ratio = size.width / size.height;
        return LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => onFocus(
                focusPointForPreview(
                  details.localPosition,
                  constraints.biggest,
                  ratio,
                ),
              ),
              child: ClipRect(
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: ratio * 1000,
                      height: 1000,
                      child: CameraPreview(controller),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
