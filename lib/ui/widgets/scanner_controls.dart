import 'dart:math' as math;

import 'package:flutter/material.dart';

class ScannerControls extends StatelessWidget {
  const ScannerControls({
    required this.ready,
    required this.busy,
    required this.torchOn,
    required this.changingFlash,
    required this.onClose,
    required this.onFlash,
    required this.onCapture,
    this.captureEnabled = true,
    super.key,
  });

  final bool ready;
  final bool busy;
  final bool torchOn;
  final bool changingFlash;
  final VoidCallback onClose;
  final VoidCallback onFlash;
  final VoidCallback onCapture;
  final bool captureEnabled;

  static double bottomHeight(BuildContext context, double viewportWidth) {
    final text = TextPainter(
      text: const TextSpan(
        text: 'Fit the receipt inside the frame',
        style: TextStyle(fontSize: 14, height: 1.4),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: math.max(1, viewportWidth - 56));
    final height = text.height + 16 + 12 + 80 + 32;
    text.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.78),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                    ),
                    tooltip: 'Close scanner',
                    onPressed: busy ? null : onClose,
                    icon: const Icon(Icons.close),
                  ),
                  const Spacer(),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.78),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                    ),
                    tooltip: torchOn ? 'Turn torch off' : 'Turn torch on',
                    onPressed: !ready || busy || changingFlash ? null : onFlash,
                    icon: Icon(torchOn ? Icons.flash_on : Icons.flash_off),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (ready)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          'Fit the receipt inside the frame',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(80, 80),
                      ),
                      tooltip: 'Capture receipt',
                      iconSize: 40,
                      onPressed: busy || changingFlash || !captureEnabled
                          ? null
                          : onCapture,
                      icon: busy
                          ? const SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(),
                            )
                          : const Icon(Icons.camera_alt),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
