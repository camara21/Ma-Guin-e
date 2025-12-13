import 'dart:typed_data';
import 'package:image/image.dart' as img;

import 'compressed_image.dart';

Future<CompressedImage> compressBytes(
  Uint8List input, {
  required int maxSide,
  required int quality,
  required int? maxBytes,
  required bool keepPngIfTransparent,
}) async {
  final decoded = _safeDecode(input);
  if (decoded == null) {
    // Format non décodable : on renvoie tel quel
    return CompressedImage(
      bytes: input,
      contentType: 'application/octet-stream',
      extension: 'bin',
    );
  }

  final hasAlpha = keepPngIfTransparent ? _hasAlpha(decoded) : false;
  final shouldPng = keepPngIfTransparent && hasAlpha;

  final resized = _resizeIfNeeded(decoded, maxSide);

  // Encode
  Uint8List out = shouldPng
      ? Uint8List.fromList(img.encodePng(resized, level: 6))
      : Uint8List.fromList(
          img.encodeJpg(resized, quality: quality.clamp(30, 95)));

  // Si trop lourd et qu'on est en JPEG : baisse progressive de qualité
  if (maxBytes != null && !shouldPng && out.lengthInBytes > maxBytes) {
    out =
        _reduceJpegToTarget(resized, startQuality: quality, maxBytes: maxBytes);
  }

  // Si trop lourd et PNG + maxBytes : on ne boucle pas (la qualité n'aide pas en PNG)
  return CompressedImage(
    bytes: out,
    contentType: shouldPng ? 'image/png' : 'image/jpeg',
    extension: shouldPng ? 'png' : 'jpg',
    width: resized.width,
    height: resized.height,
  );
}

img.Image? _safeDecode(Uint8List bytes) {
  try {
    return img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
}

bool _hasAlpha(img.Image image) {
  if (image.numChannels < 4) return false;

  final stepX = (image.width / 40).clamp(1, image.width).toInt();
  final stepY = (image.height / 40).clamp(1, image.height).toInt();

  for (int y = 0; y < image.height; y += stepY) {
    for (int x = 0; x < image.width; x += stepX) {
      final p = image.getPixel(x, y);
      if (p.a < 255) return true;
    }
  }
  return false;
}

img.Image _resizeIfNeeded(img.Image image, int maxSide) {
  final w = image.width;
  final h = image.height;
  final maxDim = w > h ? w : h;

  if (maxDim <= maxSide) return image;

  final scale = maxSide / maxDim;
  final newW = (w * scale).round();
  final newH = (h * scale).round();

  return img.copyResize(image, width: newW, height: newH);
}

Uint8List _reduceJpegToTarget(
  img.Image image, {
  required int startQuality,
  required int maxBytes,
}) {
  int q = startQuality.clamp(30, 95);
  Uint8List best = Uint8List.fromList(img.encodeJpg(image, quality: q));

  for (int i = 0; i < 8 && best.lengthInBytes > maxBytes; i++) {
    q = (q - 8).clamp(30, 95);
    best = Uint8List.fromList(img.encodeJpg(image, quality: q));
  }
  return best;
}
