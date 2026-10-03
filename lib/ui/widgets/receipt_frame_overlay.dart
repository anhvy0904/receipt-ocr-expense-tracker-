import 'package:flutter/material.dart';

class ReceiptFrameOverlay extends StatelessWidget {
  const ReceiptFrameOverlay({required this.frame, super.key});
  final Rect frame;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _ReceiptFramePainter(frame)),
    );
  }
}

class _ReceiptFramePainter extends CustomPainter {
  const _ReceiptFramePainter(this.frame);
  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final roundedFrame = RRect.fromRectAndRadius(
      frame,
      const Radius.circular(12),
    );
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(roundedFrame);
    canvas.drawPath(shade, Paint()..color = const Color(0x99000000));
    canvas.drawRRect(
      roundedFrame,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ReceiptFramePainter oldDelegate) =>
      frame != oldDelegate.frame;
}
