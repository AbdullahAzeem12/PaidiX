import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/core/config/app_config.dart';
import 'package:paidix/core/network/api_client.dart';
import 'package:paidix/features/kyc/data/kyc_repository.dart';
import 'package:paidix/features/profile/domain/bank_account_item.dart';
import 'package:paidix/features/profile/domain/user_profile.dart';
import 'package:paidix/features/settings/presentation/pages/account_settings_page.dart';
import 'test_fixtures.dart';

void main() {
  setUp(() {
    AppConfig.debugOverrideCustomBackend = null;
    ApiClient.instance.customHttpClient = null;
    setupTestState(
      profile: createTestProfile(
        email: 'abdullahazeem5352@gmail.com',
        kycStatus: KycReviewStatus.verified,
      ),
      banks: const [],
    );
  });

  tearDown(() {
    AppConfig.debugOverrideCustomBackend = null;
    ApiClient.instance.customHttpClient = null;
  });

  test('BankAccountItem.fromJson parses Django REST /banking/bank-accounts/ payloads', () {
    final parsed = BankAccountItem.fromJson({
      'id': 'acc-101',
      'bank': {'id': 7, 'name': 'SadaPay', 'code': 'SADAPAY'},
      'holder_name': 'Abdullah',
      'account_number': '03225352786',
      'is_primary': true,
    });

    expect(parsed.id, 'acc-101');
    expect(parsed.bankId, '7');
    expect(parsed.bankName, 'SadaPay');
    expect(parsed.holder, 'Abdullah');
    expect(parsed.accountNumber, '03225352786');
    expect(parsed.maskedDisplay, '•••• •••• 2786');
    expect(parsed.isPrimary, isTrue);
  });

  testWidgets(
      'Bank Accounts tab fetches GET /banking/bank-accounts/ and displays KYC account immediately',
      (WidgetTester tester) async {
    AppConfig.debugOverrideCustomBackend = true;
    var bankGetCalls = 0;
    ApiClient.instance.customHttpClient = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path.endsWith('/banking/bank-accounts/')) {
        bankGetCalls++;
        return http.Response(
          jsonEncode([
            {
              'id': 'server-bank-1',
              'bank_name': 'SADAPAY',
              'holder_name': 'Abdullah',
              'account_number': '03225352786',
              'is_primary': true,
            },
          ]),
          200,
        );
      }
      return http.Response(jsonEncode({'detail': 'Not found'}), 404);
    });
    await ApiClient.instance.setAuthTokens(access: 'test_token');

    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AccountSettingsPage(initialSection: 'bank-accounts'),
      ),
    );
    await tester.pumpAndSettle();

    expect(bankGetCalls, greaterThanOrEqualTo(1));
    expect(find.text('SADAPAY'), findsOneWidget);
    expect(find.text('Abdullah'), findsOneWidget);
    expect(find.text('•••• •••• 2786'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('No bank accounts linked.'), findsNothing);
  });

  test(
      'KycRepository resolves integer bank id, uses make_primary with PATCH fallback, protects primary delete, and deletes secondary accounts',
      () async {
    AppConfig.debugOverrideCustomBackend = true;
    final calls = <String>[];
    final postPayloads = <Map<String, dynamic>>[];
    final makePrimaryBodies = <String>[];
    final serverRows = <Map<String, dynamic>>[];
    var nextId = 1;
    var returnNotFoundOnMakePrimary = false;

    ApiClient.instance.customHttpClient = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.method == 'GET' &&
          request.url.path.endsWith('/banking/banks/pk/')) {
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'name': 'Standard Chartered Bank (Pakistan) Limited',
              'code': 'SCBL',
              'is_active': true,
            },
            {
              'id': 2,
              'name': 'Meezan Bank Limited',
              'code': 'MEZN',
              'is_active': true,
            },
            {
              'id': 3,
              'name': 'SadaPay',
              'code': 'SADA',
              'is_active': true,
            },
          ]),
          200,
        );
      }
      if (request.method == 'GET' &&
          request.url.path.endsWith('/banking/bank-accounts/')) {
        return http.Response(jsonEncode(serverRows), 200);
      }
      if (request.method == 'POST' &&
          request.url.path.endsWith('/banking/bank-accounts/')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        postPayloads.add(body);
        final id = 'srv-${nextId++}';
        final created = {
          'id': id,
          'bank': body['bank'],
          'bank_name': body['bank'] == 1
              ? 'Standard Chartered Bank (Pakistan) Limited'
              : body['bank'] == 2
                  ? 'Meezan Bank Limited'
                  : 'SadaPay',
          'holder_name': body['holder_name'],
          'account_number': body['account_number'],
          if (body['iban'] != null) 'iban': body['iban'],
          'is_primary': body['is_primary'] ?? false,
        };
        serverRows.add(created);
        return http.Response(jsonEncode(created), 201);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/make_primary/')) {
        makePrimaryBodies.add(request.body);
        if (returnNotFoundOnMakePrimary) {
          return http.Response(jsonEncode({'detail': 'Not found'}), 404);
        }
        final parts =
            request.url.path.split('/').where((e) => e.isNotEmpty).toList();
        final id = parts[parts.length - 2];
        for (int i = 0; i < serverRows.length; i++) {
          serverRows[i] = {
            ...serverRows[i],
            'is_primary': serverRows[i]['id'] == id,
          };
        }
        final target = serverRows.firstWhere((r) => r['id'] == id);
        return http.Response(jsonEncode(target), 200);
      }
      if (request.method == 'PATCH' &&
          request.url.path.contains('/banking/bank-accounts/')) {
        final id = request.url.path
            .split('/')
            .where((e) => e.isNotEmpty)
            .last;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final idx = serverRows.indexWhere((r) => r['id'] == id);
        if (body['is_primary'] == true) {
          for (int i = 0; i < serverRows.length; i++) {
            serverRows[i] = {...serverRows[i], 'is_primary': i == idx};
          }
        }
        serverRows[idx] = {...serverRows[idx], ...body};
        return http.Response(jsonEncode(serverRows[idx]), 200);
      }
      if (request.method == 'DELETE' &&
          request.url.path.contains('/banking/bank-accounts/')) {
        final id = request.url.path
            .split('/')
            .where((e) => e.isNotEmpty)
            .last;
        serverRows.removeWhere((r) => r['id'] == id);
        return http.Response('', 204);
      }
      return http.Response('{}', 200);
    });
    await ApiClient.instance.setAuthTokens(access: 'test_token');

    // 1. Standard Chartered alias ('Standard Chartered Bank Pakistan' / 'SCB') -> id 1 ('SCBL')
    final createdPrimary = await KycRepository.instance.createBankAccount(
      const BankAccountItem(
        id: 'local_1',
        bankName: 'Standard Chartered Bank Pakistan',
        holder: 'Abdullah Azeem',
        accountNumber: '01234567890123',
        iban: 'PK36SCBL0000001234567801',
        isPrimary: true,
      ),
      email: 'abdullahazeem5352@gmail.com',
    );
    expect(createdPrimary.id, 'srv-1');
    expect(createdPrimary.bankId, '1');
    expect(postPayloads.first['bank'], 1);
    expect(postPayloads.first.containsKey('bank_name'), isFalse);
    expect(postPayloads.first.containsKey('bank_code'), isFalse);

    // 2. Patch primary account
    await KycRepository.instance.updateBankAccount(
      createdPrimary.copyWith(holder: 'Abdullah Azeem Updated'),
      email: 'abdullahazeem5352@gmail.com',
    );

    // 3. Primary account cannot be deleted (rejected before hitting DELETE)
    await expectLater(
      KycRepository.instance.deleteBankAccount(
        createdPrimary,
        email: 'abdullahazeem5352@gmail.com',
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.errorCode, 'errorCode', 'PRIMARY_ACCOUNT_PROTECTED'),
      ),
    );
    expect(
      calls.any((c) => c.startsWith('DELETE /api/v1/banking/bank-accounts/srv-1/')),
      isFalse,
    );

    // 4. Add additional account (Meezan) & promote via Option A make_primary
    final createdSecondary = await KycRepository.instance.createBankAccount(
      const BankAccountItem(
        id: 'local_2',
        bankName: 'Meezan Bank Limited',
        holder: 'Abdullah Azeem',
        accountNumber: '123456',
        isPrimary: false,
      ),
      email: 'abdullahazeem5352@gmail.com',
    );
    expect(createdSecondary.id, 'srv-2');
    expect(postPayloads[1]['bank'], 2);

    await KycRepository.instance.setPrimaryBankAccount(
      createdSecondary,
      email: 'abdullahazeem5352@gmail.com',
    );
    expect(
      calls,
      contains('POST /api/v1/banking/bank-accounts/srv-2/make_primary/'),
    );
    expect(makePrimaryBodies.first, '{}');

    // 5. Former primary is now additional and CAN be deleted
    await KycRepository.instance.deleteBankAccount(
      createdPrimary.copyWith(isPrimary: false),
      email: 'abdullahazeem5352@gmail.com',
    );
    expect(
      calls,
      contains('DELETE /api/v1/banking/bank-accounts/srv-1/'),
    );

    // 6. Option B fallback: 404 on make_primary falls back to PATCH
    returnNotFoundOnMakePrimary = true;
    await KycRepository.instance.setPrimaryBankAccount(
      createdSecondary.copyWith(isPrimary: false),
      email: 'abdullahazeem5352@gmail.com',
    );
    expect(
      calls,
      contains('PATCH /api/v1/banking/bank-accounts/srv-2/'),
    );
  });
}

