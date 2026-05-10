import 'dart:io';
import 'package:image/image.dart' as img;

/// One-shot helper used during project setup to convert the WebP source logo
/// into the PNG that `flutter_launcher_icons` requires.
void main() {
  final webpBytes = File('assets/logo.webp').readAsBytesSync();
  final decoded = img.decodeWebP(webpBytes);
  if (decoded == null) {
    stderr.writeln('Failed to decode assets/logo.webp');
    exit(1);
  }
  final outPath = 'assets/logo.png';
  File(outPath).writeAsBytesSync(img.encodePng(decoded));
  stdout.writeln('Wrote $outPath (${decoded.width}x${decoded.height})');
}
