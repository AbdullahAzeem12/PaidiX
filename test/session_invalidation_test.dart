import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paidix/app/app.dart';
import 'package:paidix/app/router.dart';
import 'package:paidix/core/network/api_client.dart';
import 'package:paidix/features/profile/data/user_profile_repository.dart';
import 'test_fixtures.dart';

void main() {
  testWidgets(
      'server account deletion clears local state and routes to sign-in',
      (tester) async {
    setupTestState();
    final client = ApiClient.instance;
    await client.setAuthTokens(
      access: 'active_access',
      refresh: 'valid_refresh',
    );
    client.customHttpClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'detail': 'This account does not exist.',
          'code': 'account_not_found',
        }),
        401,
      );
    });

    appRouter.go('/app/dashboard');
    await tester.pumpWidget(const PaidiXApp());
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/app/dashboard');

    await expectLater(
      client.get('/accounts/profile/'),
      throwsA(isA<ApiException>()),
    );
    await tester.pumpAndSettle();

    expect(appRouter.routeInformationProvider.value.uri.path, '/signin');
    expect(UserProfileRepository.instance.profile.email, isEmpty);
    expect(client.authToken, isNull);
    expect(client.refreshToken, isNull);
    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('Account unavailable'), findsOneWidget);

    appRouter.go('/signin');
    client.customHttpClient = null;
    await client.clearSession();
  });
}
