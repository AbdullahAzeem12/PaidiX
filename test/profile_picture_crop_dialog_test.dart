/// Tests the clean, minimalist auto cropper and profile picture confirmation dialog.

import 'dart:ui' as ui;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/features/profile/presentation/widgets/profile_picture_crop_dialog.dart';

Future<Uint8List> _createValidPngBytes({int width = 100, int height = 100}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF10B981),
  );
  final picture = recorder.endRecording();
  final image = picture.toImageSync(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

Future<Uint8List> _createTriBandPortraitPng({
  int width = 200,
  int height = 400,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height / 4),
    Paint()..color = const Color(0xFFEF4444),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, height / 4, width.toDouble(), height / 2),
    Paint()..color = const Color(0xFF10B981),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, height * 0.75, width.toDouble(), height / 4),
    Paint()..color = const Color(0xFF3B82F6),
  );
  final picture = recorder.endRecording();
  final image = picture.toImageSync(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

Future<Color> _sampleCenterPixel(Uint8List pngBytes) async {
  final codec = await ui.instantiateImageCodec(pngBytes);
  final frame = await codec.getNextFrame();
  final byteData =
      await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final w = frame.image.width;
  final h = frame.image.height;
  final cx = w ~/ 2;
  final cy = h ~/ 2;
  final offset = (cy * w + cx) * 4;
  final r = byteData!.getUint8(offset);
  final g = byteData.getUint8(offset + 1);
  final b = byteData.getUint8(offset + 2);
  final a = byteData.getUint8(offset + 3);
  frame.image.dispose();
  codec.dispose();
  return Color.fromARGB(a, r, g, b);
}

Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    await Future.delayed(const Duration(milliseconds: 150));
  });
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List testPngBytes;
  late Uint8List triBandPortraitBytes;

  setUpAll(() async {
    testPngBytes = await _createValidPngBytes(width: 80, height: 120);
    triBandPortraitBytes = await _createTriBandPortraitPng();
  });

  group('Clean Auto Profile Cropper & Confirmation Suite', () {
    test('autoCropImage centers tall portrait photos cleanly and outputs 512x512', () async {
      final cropped = await ProfilePictureCropDialog.autoCropImage(triBandPortraitBytes);

      expect(cropped.isNotEmpty, isTrue);

      final codec = await ui.instantiateImageCodec(cropped);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 512);
      expect(frame.image.height, 512);
      final byteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      // Center 200x200 band (y = 100..300) is solid emerald green without top red bleed
      final topPixelOffset = (25 * 512 + 256) * 4;
      final bottomPixelOffset = (485 * 512 + 256) * 4;
      expect(byteData!.getUint8(topPixelOffset + 1), greaterThan(150));
      expect(byteData.getUint8(topPixelOffset), lessThan(80));
      expect(byteData.getUint8(bottomPixelOffset + 1), greaterThan(150));
      expect(byteData.getUint8(bottomPixelOffset + 2), lessThan(180));
      frame.image.dispose();
      codec.dispose();
    });

    test('autoCropImage honors alignment and zoom overrides cleanly', () async {
      final topCropped = await ProfilePictureCropDialog.autoCropImage(
        triBandPortraitBytes,
        alignment: Alignment.topCenter,
        zoom: 2.0,
      );
      final bottomCropped = await ProfilePictureCropDialog.autoCropImage(
        triBandPortraitBytes,
        alignment: Alignment.bottomCenter,
        zoom: 2.0,
      );

      final topCenterColor = await _sampleCenterPixel(topCropped);
      final bottomCenterColor = await _sampleCenterPixel(bottomCropped);

      expect((topCenterColor.r * 255).round(), greaterThan(180));
      expect((bottomCenterColor.b * 255).round(), greaterThan(180));
    });

    test('autoCropImage centers wide landscape photos with 1:1 output', () async {
      final landscapeBytes = await _createValidPngBytes(width: 1200, height: 800);
      final cropped = await ProfilePictureCropDialog.autoCropImage(landscapeBytes);

      expect(cropped.isNotEmpty, isTrue);

      final codec = await ui.instantiateImageCodec(cropped);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 512);
      expect(frame.image.height, 512);
      frame.image.dispose();
      codec.dispose();
    });

    testWidgets('Renders clean confirmation dialog with centered circular preview, framing controls, and Save / Cancel buttons', (tester) async {
      tester.view.physicalSize = const Size(414, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ProfilePictureCropDialog.show(context, rawBytes: testPngBytes);
                },
                child: const Text('Open Auto Cropper'),
              ),
            ),
          ),
        ),
      );

      // Open the confirmation modal
      await tester.tap(find.text('Open Auto Cropper'));
      await _pumpUntilLoaded(tester);

      // Verify clean header, framing controls, and absence of AI slop badges
      expect(find.text('Profile Photo'), findsOneWidget);
      expect(find.text('Preview before saving'), findsOneWidget);
      expect(find.text('Drag photo to center • Slide or pinch to zoom'),
          findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('✨ Auto-Centered'), findsNothing);
      expect(find.text('📐 1:1 Headroom'), findsNothing);
      expect(find.text('🎨 Zero Distortion'), findsNothing);
      expect(find.text('✨ Studio Enhanced'), findsNothing);

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Interactive zoom and drag framing shifts exported crop and Reset restores center', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Uint8List? resultBytes;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  resultBytes = await ProfilePictureCropDialog.show(
                    context,
                    rawBytes: triBandPortraitBytes,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await _pumpUntilLoaded(tester);

      // Drag photo vertically upward so bottom blue band enters center
      await tester.drag(find.byType(RawImage), const Offset(0, -140));
      await tester.pumpAndSettle();

      expect(find.text('Reset'), findsOneWidget);

      // Reset snaps framing back to center and hides Reset
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Reset'), findsNothing);

      // Zoom to ~2.0x via Slider center tap and drag down toward top red band
      await tester.tap(find.byType(Slider));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ClipOval), const Offset(0, 260));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();

      expect(resultBytes, isNotNull);
      late Color sampled;
      await tester.runAsync(() async {
        sampled = await _sampleCenterPixel(resultBytes!);
      });
      expect((sampled.r * 255).round(), greaterThan(180));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cancel button dismisses without returning bytes', (tester) async {
      tester.view.physicalSize = const Size(414, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Uint8List? resultBytes;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  resultBytes = await ProfilePictureCropDialog.show(
                    context,
                    rawBytes: testPngBytes,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await _pumpUntilLoaded(tester);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(resultBytes, isNull);
    });

    testWidgets('Save button confirms and returns 512x512 auto-cropped bytes', (tester) async {
      tester.view.physicalSize = const Size(414, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Uint8List? resultBytes;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  resultBytes = await ProfilePictureCropDialog.show(
                    context,
                    rawBytes: testPngBytes,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await _pumpUntilLoaded(tester);

      // Tap Save
      final saveBtn = find.text('Save');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verified 512x512 bytes returned
      expect(resultBytes, isNotNull);
      expect(resultBytes!.isNotEmpty, isTrue);

      ui.FrameInfo? frame;
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(resultBytes!);
        frame = await codec.getNextFrame();
        codec.dispose();
      });

      expect(frame, isNotNull);
      expect(frame!.image.width, 512);
      expect(frame!.image.height, 512);
      frame!.image.dispose();
    });
  });
}
