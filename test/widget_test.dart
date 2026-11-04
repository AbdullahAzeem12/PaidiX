import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/app.dart';

void main() {
  testWidgets('Renders SignIn screen by default with all reference fields and navigates to SignUp', (WidgetTester tester) async {
    await tester.pumpWidget(const PaidiXApp());
    await tester.pumpAndSettle();

    // Verify Eyebrow & Title
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('Welcome back.'), findsOneWidget);

    // Verify Fields
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);

    // Verify Submit Button
    expect(find.text('Sign in'), findsOneWidget);

    // Verify Footer Link
    final createAccountLink = find.text('Create an account');
    expect(createAccountLink, findsOneWidget);

    // Ensure link is visible in scroll view and tap
    await tester.ensureVisible(createAccountLink);
    await tester.pumpAndSettle();
    await tester.tap(createAccountLink);
    await tester.pumpAndSettle();

    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(find.text('Start sending.'), findsOneWidget);
  });
}
