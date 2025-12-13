import 'dart:typed_data';

class CompressedImage {
  final Uint8List bytes;
  final String contentType; // image/jpeg | image/png
  final String extension; // jpg | png
  final int? width;
  final int? height;

  const CompressedImage({
    required this.bytes,
    required this.contentType,
    required this.extension,
    this.width,
    this.height,
  });
}
