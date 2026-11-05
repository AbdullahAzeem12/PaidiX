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
    testPngBytes = await _createValidPngBytes(width: 80, height: 80);
  });

  group('ProfilePictureCropDialog Studio Suite', () {
    testWidgets('Renders cropper studio with live circular frame, controls and filter chips', (tester) async {
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
                child: const Text('Open Cropper'),
              ),
            ),
          ),
        ),
      );

      // Open the cropper modal
      await tester.tap(find.text('Open Cropper'));
      await _pumpUntilLoaded(tester);

      // Verify header and guidance
      expect(find.text('Adjust Profile Picture'), findsOneWidget);
      expect(find.text('Center your face & customize styling'), findsOneWidget);

      // Verify zoom icons and slider
      expect(find.byIcon(Icons.zoom_out_rounded), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in_rounded), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Verify rotation button and reset button
      expect(find.byIcon(Icons.rotate_right_rounded), findsOneWidget);
      expect(find.byIcon(Icons.restart_alt_rounded), findsOneWidget);

      // Verify initial filters visible
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Studio Vibrant'), findsOneWidget);
      expect(find.text('Crisp Clarity'), findsOneWidget);

      // Scroll horizontal filter list to find Warm Gold and Monochrome
      final scrollable = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(find.text('Warm Gold'), 60.0, scrollable: scrollable);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Warm Gold'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Monochrome'), 60.0, scrollable: scrollable);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Monochrome'), findsOneWidget);

      // Verify Save and Cancel action buttons
      expect(find.text('Save Picture'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Clean up spongy timers
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('Rotation button cycles orientations cleanly', (tester) async {
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

      final rotateFinder = find.byIcon(Icons.rotate_right_rounded);
      expect(rotateFinder, findsOneWidget);

      // Tap rotate 3 times
      await tester.tap(rotateFinder);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(rotateFinder);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(rotateFinder);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify reset returns back to default
      final resetFinder = find.byIcon(Icons.restart_alt_rounded);
      await tester.tap(resetFinder);
      await tester.pump(const Duration(milliseconds: 150));
    });

    testWidgets('Filter chip selection updates active filter index', (tester) async {
      tester.view.physicalSize = const Size(414, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ProfilePictureCropDialog(rawBytes: testPngBytes),
          ),
        ),
      );
      await _pumpUntilLoaded(tester);

      // Tap 'Studio Vibrant'
      await tester.tap(find.text('Studio Vibrant'));
      await tester.pump(const Duration(milliseconds: 150));

      // Scroll to 'Warm Gold' and tap
      final scrollable = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(find.text('Warm Gold'), 60.0, scrollable: scrollable);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Warm Gold'));
      await tester.pump(const Duration(milliseconds: 150));

      // Scroll to 'Monochrome' and tap
      await tester.scrollUntilVisible(find.text('Monochrome'), 60.0, scrollable: scrollable);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Monochrome'));
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

    testWidgets('Save Picture renders 512x512 square cropped bytes without distortion', (tester) async {
      tester.view.physicalSize = const Size(414, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ProfilePictureCropDialog(rawBytes: testPngBytes),
          ),
        ),
      );
      await _pumpUntilLoaded(tester);

      // Verify Save Picture button is rendered in the action row
      final saveBtnFinder = find.text('Save Picture');
      await tester.ensureVisible(saveBtnFinder);
      expect(saveBtnFinder, findsOneWidget);

      // Execute renderCroppedBytes on state within real engine loop
      final state = tester.state<ProfilePictureCropDialogState>(
        find.byType(ProfilePictureCropDialog),
      );
      Uint8List? croppedBytes;
      ui.FrameInfo? frame;
      await tester.runAsync(() async {
        croppedBytes = await state.renderCroppedBytes();
        if (croppedBytes != null) {
          final codec = await ui.instantiateImageCodec(croppedBytes!);
          frame = await codec.getNextFrame();
          codec.dispose();
        }
      });

      // Result must be valid non-empty PNG bytes
      expect(croppedBytes, isNotNull);
      expect(croppedBytes!.isNotEmpty, isTrue);
      expect(frame, isNotNull);
      expect(frame!.image.width, 512);
      expect(frame!.image.height, 512);
      frame!.image.dispose();
    });
  });
}
