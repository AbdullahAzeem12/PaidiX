import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/app.dart';

void main() {
  testWidgets(
      'PaidiXApp handles lifecycle resume and confirms frame render over lifecycle channel',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PaidiXApp());
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    const codec = StandardMethodCodec();
    final callBytes = codec.encodeMethodCall(
      const MethodCall('verifyFrameRendered'),
    );

    final responseFuture = tester.binding.defaultBinaryMessenger
        .handlePlatformMessage('com.paidix.paidix/lifecycle', callBytes, null);

    await tester.pump();
    final responseBytes = await responseFuture;
    expect(responseBytes, isNotNull);
    final result = codec.decodeEnvelope(responseBytes!);
    expect(result, isTrue);
  });
}
