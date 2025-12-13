import 'dart:typed_data';
import 'compressed_image.dart';

// Import conditionnel : Web -> impl_web, IO -> impl_io, sinon stub
import 'image_compressor_impl_stub.dart'
    if (dart.library.html) 'image_compressor_impl_web.dart'
    if (dart.library.io) 'image_compressor_impl_io.dart' as impl;

class ImageCompressor {
  static Future<CompressedImage> compressBytes(
    Uint8List input, {
    int maxSide = 1600,
    int quality = 82,
    int? maxBytes, // ex: 900 * 1024
    bool keepPngIfTransparent = true,
  }) {
    return impl.compressBytes(
      input,
      maxSide: maxSide,
      quality: quality,
      maxBytes: maxBytes,
      keepPngIfTransparent: keepPngIfTransparent,
    );
  }
}
