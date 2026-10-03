import 'dart:io';
import 'package:image/image.dart' as image;

/// Raster export only: the original generated logo remains unchanged.
void main() {
  final logo = image.decodePng(
    File('assets/branding/receiptwise_logo.png').readAsBytesSync(),
  )!;
  const sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  for (final entry in sizes.entries) {
    final canvas = image.Image(width: entry.value, height: entry.value);
    image.fill(canvas, color: image.ColorRgba8(255, 246, 220, 255));
    final foreground = image.copyResize(
      logo,
      width: entry.value,
      height: entry.value,
      interpolation: image.Interpolation.average,
    );
    image.compositeImage(canvas, foreground);
    File(
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
    ).writeAsBytesSync(image.encodePng(canvas));
  }
}
