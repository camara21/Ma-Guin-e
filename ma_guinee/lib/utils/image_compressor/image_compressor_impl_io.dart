import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

import 'compressed_image.dart';

Future<CompressedImage> compressBytes(
  Uint8List input, {
  required int maxSide,
  required int quality,
  required int? maxBytes,
  required bool keepPngIfTransparent,
}) async {
  final isMobile = Platform.isAndroid || Platform.isIOS;

  if (isMobile) {
    return _compressMobileNative(
      input,
      maxSide: maxSide,
      quality: quality,
      maxBytes: maxBytes,
      keepPngIfTransparent: keepPngIfTransparent,
    );
  }

  return _compressPureDart(
    input,
    maxSide: maxSide,
    quality: quality,
    maxBytes: maxBytes,
    keepPngIfTransparent: keepPngIfTransparent,
  );
}

Future<CompressedImage> _compressMobileNative(
  Uint8List input, {
  required int maxSide,
  required int quality,
  required int? maxBytes,
  required bool keepPngIfTransparent,
}) async {
  final decoded = _safeDecode(input);
  final hasAlpha =
      (decoded != null && keepPngIfTransparent) ? _hasAlpha(decoded) : false;
  final outputPng = keepPngIfTransparent && hasAlpha;

  final dims =
      (decoded != null) ? _targetWH(decoded, maxSide) : (maxSide, maxSide);
  final targetW = dims.$1;
  final targetH = dims.$2;

  CompressedImage out = await _compressOnceNative(
    input,
    targetW: targetW,
    targetH: targetH,
    quality: quality,
    outputPng: outputPng,
  );

  if (maxBytes != null && out.bytes.lengthInBytes > maxBytes && !outputPng) {
    int q = quality.clamp(35, 92);

    for (int i = 0; i < 6 && out.bytes.lengthInBytes > maxBytes; i++) {
      q = (q - 7).clamp(35, 92);
      out = await _compressOnceNative(
        input,
        targetW: targetW,
        targetH: targetH,
        quality: q,
        outputPng: false,
      );
    }

    int side = maxSide;
    for (int i = 0; i < 4 && out.bytes.lengthInBytes > maxBytes; i++) {
      side = (side * 0.85).round().clamp(640, maxSide);

      final dims2 = (decoded != null) ? _targetWH(decoded, side) : (side, side);

      out = await _compressOnceNative(
        input,
        targetW: dims2.$1,
        targetH: dims2.$2,
        quality: q,
        outputPng: false,
      );
    }
  }

  return out;
}

Future<CompressedImage> _compressOnceNative(
  Uint8List input, {
  required int targetW,
  required int targetH,
  required int quality,
  required bool outputPng,
}) async {
  final format = outputPng ? CompressFormat.png : CompressFormat.jpeg;

  final List<int>? raw = await FlutterImageCompress.compressWithList(
    input,
    minWidth: targetW,
    minHeight: targetH,
    quality: outputPng ? 100 : quality,
    format: format,
    keepExif: false,
  );

  if (raw == null || raw.isEmpty) {
    throw Exception('Compression échouée (null/vide).');
  }

  final bytes = Uint8List.fromList(raw);
  final d2 = _safeDecode(bytes);

  return CompressedImage(
    bytes: bytes,
    contentType: outputPng ? 'image/png' : 'image/jpeg',
    extension: outputPng ? 'png' : 'jpg',
    width: d2?.width,
    height: d2?.height,
  );
}

Future<CompressedImage> _compressPureDart(
  Uint8List input, {
  required int maxSide,
  required int quality,
  required int? maxBytes,
  required bool keepPngIfTransparent,
}) async {
  final decoded = _safeDecode(input);
  if (decoded == null) {
    return CompressedImage(
      bytes: input,
      contentType: 'application/octet-stream',
      extension: 'bin',
    );
  }

  final hasAlpha = keepPngIfTransparent ? _hasAlpha(decoded) : false;
  final shouldPng = keepPngIfTransparent && hasAlpha;

  final resized = _resizeIfNeeded(decoded, maxSide);

  Uint8List out = shouldPng
      ? Uint8List.fromList(img.encodePng(resized, level: 6))
      : Uint8List.fromList(
          img.encodeJpg(resized, quality: quality.clamp(30, 95)));

  if (maxBytes != null && !shouldPng && out.lengthInBytes > maxBytes) {
    out =
        _reduceJpegToTarget(resized, startQuality: quality, maxBytes: maxBytes);
  }

  return CompressedImage(
    bytes: out,
    contentType: shouldPng ? 'image/png' : 'image/jpeg',
    extension: shouldPng ? 'png' : 'jpg',
    width: resized.width,
    height: resized.height,
  );
}

// Helpers
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
      if (image.getPixel(x, y).a < 255) return true;
    }
  }
  return false;
}

(int, int) _targetWH(img.Image image, int maxSide) {
  final w = image.width;
  final h = image.height;
  final maxDim = w > h ? w : h;
  if (maxDim <= maxSide) return (w, h);

  final scale = maxSide / maxDim;
  return ((w * scale).round(), (h * scale).round());
}

img.Image _resizeIfNeeded(img.Image image, int maxSide) {
  final w = image.width;
  final h = image.height;
  final maxDim = w > h ? w : h;
  if (maxDim <= maxSide) return image;

  final scale = maxSide / maxDim;
  return img.copyResize(image,
      width: (w * scale).round(), height: (h * scale).round());
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
