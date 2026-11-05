/// Tests the auto professional cropper and profile picture confirmation dialog.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
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

  setUpAll(() async {
    testPngBytes = await _createValidPngBytes(width: 80, height: 120);
  });

  group('Auto Professional Profile Cropper & Confirmation Suite', () {
    test('autoCropImage centers tall portrait photos with 1:1 golden headroom and 512x512 output', () async {
      final portraitBytes = await _createValidPngBytes(width: 600, height: 1000);
      final cropped = await ProfilePictureCropDialog.autoCropImage(portraitBytes);

      expect(cropped.isNotEmpty, isTrue);

      final codec = await ui.instantiateImageCodec(cropped);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 512);
      expect(frame.image.height, 512);
      frame.image.dispose();
      codec.dispose();
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

    testWidgets('Renders confirmation dialog with auto-cropped circular preview, badges, and action buttons', (tester) async {
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

      // Open the auto-crop confirmation modal
      await tester.tap(find.text('Open Auto Cropper'));
      await _pumpUntilLoaded(tester);

      // Verify header and guidance
      expect(find.text('Confirm Profile Picture'), findsOneWidget);
      expect(find.text('Auto-centered & studio-enhanced'), findsOneWidget);

      // Verify auto-enhancement semantic chips
      expect(find.text('✨ Auto-Centered'), findsOneWidget);
      expect(find.text('📐 1:1 Headroom'), findsOneWidget);
      expect(find.text('🎨 Zero Distortion'), findsOneWidget);

      // Verify filter presets
      expect(find.text('✨ Studio Enhanced'), findsOneWidget);
      expect(find.text('🌿 Natural'), findsOneWidget);
      expect(find.text('☀️ Warm Gold'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm & Set Picture'), findsOneWidget);
    });

    testWidgets('Filter presets switch smoothly without errors', (tester) async {
      tester.view.physicalSize = const Size(414, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ProfilePictureCropDialog(rawBytes: testPngBytes),
          ),
        ),
      );
      await _pumpUntilLoaded(tester);

      // Switch to Natural
      await tester.tap(find.text('🌿 Natural'));
      await _pumpUntilLoaded(tester);

      // Switch to Warm Gold
      await tester.tap(find.text('☀️ Warm Gold'));
      await _pumpUntilLoaded(tester);

      // Switch back to Studio Enhanced
      await tester.tap(find.text('✨ Studio Enhanced'));
      await _pumpUntilLoaded(tester);

      // Drain spongy release timers
      await tester.pump(const Duration(milliseconds: 200));
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

    testWidgets('Confirm & Set Picture button confirms and returns 512x512 auto-cropped bytes', (tester) async {
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

      // Tap Confirm & Set Picture
      final confirmBtn = find.text('Confirm & Set Picture');
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
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
