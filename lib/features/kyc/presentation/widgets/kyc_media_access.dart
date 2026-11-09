import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Shared helpers for every KYC gallery / camera pick (CNIC front, CNIC back,
/// selfie). Keeps the permission flow and the image safety checks in one place
/// so every device (stock Android, Samsung, Xiaomi, Huawei EMUI / HarmonyOS,
/// iOS) goes through exactly the same path.
class KycMediaAccess {
  const KycMediaAccess._();

  /// Longest edge (px) requested from the native picker. 1600px keeps a CNIC
  /// legible while bounding decode memory on lower-memory Huawei devices.
  /// A 48/64MP original is resized by the native picker before Dart reads it.
  static const double maxDimension = 1600;

  /// JPEG quality used by the native picker when it re-encodes.
  static const int jpegQuality = 88;

  /// Requests native photo access when the platform exposes that permission,
  /// then opens the platform picker. Android's picker can grant access to one
  /// selected image even when broad library access is denied.
  ///
  /// No app-specific permission button or dialog is shown. If access is denied,
  /// the native picker is still opened so the OS can provide its scoped
  /// per-image grant (including Android's system photo picker).
  static Future<bool> ensureGalleryAccess(BuildContext context) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return true;

    try {
      if (!await _hasGalleryAccess()) {
        if (Platform.isAndroid) {
          // Android 13+ maps to READ_MEDIA_IMAGES; older Android maps to
          // READ_EXTERNAL_STORAGE. Request legacy storage only when needed.
          final photos = await Permission.photos.request();
          if (!photos.isGranted && !photos.isLimited) {
            await Permission.storage.request();
          }
        } else {
          await Permission.photos.request();
        }
      }
    } catch (e) {
      debugPrint('Native gallery permission request failed: $e');
    }
    return true;
  }

  static Future<bool> _hasGalleryAccess() async {
    final photos = await Permission.photos.status;
    if (photos.isGranted || photos.isLimited) return true;
    if (Platform.isAndroid) {
      final storage = await Permission.storage.status;
      if (storage.isGranted) return true;
    }
    return false;
  }

  /// Quick, memory-cheap check that [bytes] is an image Flutter can decode.
  ///
  /// Decodes at a 64px width (sub-sampled), so it is fast even for large
  /// files. Catches formats the engine cannot decode on a given device
  /// (e.g. some HEIC/HEIF photos from Huawei cameras) *before* they reach
  /// `Image.memory`, where an undecodable image would otherwise replace the
  /// screen with an error widget.
  static Future<bool> isDecodable(Uint8List bytes) async {
    if (bytes.isEmpty) return false;
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      return true;
    } catch (e) {
      debugPrint('Picked image is not decodable: $e');
      return false;
    } finally {
      codec?.dispose();
    }
  }
}

