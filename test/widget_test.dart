import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/app.dart';

void main() {
  testWidgets('Renders SignUp screen by default with all reference fields', (WidgetTester tester) async {
    await tester.pumpWidget(const PaidiXApp());
    await tester.pumpAndSettle();

    // Verify Eyebrow & Title
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(find.text('Start sending.'), findsOneWidget);

    // Verify Fields
    expect(find.text('FULL NAME'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('PHONE (OPTIONAL)'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);

    // Verify Submit Button
    expect(find.text('Create Account'), findsOneWidget);

    // Verify Footer Link
    expect(find.text('Sign in'), findsOneWidget);
  });
}

