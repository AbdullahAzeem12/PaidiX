import 'dart:typed_data';
import 'dart:ui' as ui;

/// Verifies picker output and identifies its encoded file type.
class KycImageValidation {
  const KycImageValidation._();

  static const int maxDimension = 1600;
  static const int jpegQuality = 88;

  static Future<Uint8List> validate(Uint8List source) async {
    if (source.isEmpty) {
      throw const FormatException('The selected image is empty.');
    }
    extensionFor(source);

    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(
        source,
        targetWidth: 64,
        targetHeight: 64,
        allowUpscaling: false,
      );
      image = (await codec.getNextFrame()).image;
      if (image.width == 0 || image.height == 0) {
        throw const FormatException(
            'The selected image has invalid dimensions.');
      }
      // image_picker already applies maxWidth, maxHeight, and imageQuality on
      // supported formats. Keep its original encoded bytes for OCR legibility.
      return source;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  static String extensionFor(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    throw const FormatException('Choose a JPEG, PNG, or WebP image.');
  }
}
