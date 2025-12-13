import 'dart:typed_data';
import 'compressed_image.dart';

Future<CompressedImage> compressBytes(
  Uint8List input, {
  required int maxSide,
  required int quality,
  required int? maxBytes,
  required bool keepPngIfTransparent,
}) {
  throw UnsupportedError('Compression non supportée sur cette plateforme.');
}
