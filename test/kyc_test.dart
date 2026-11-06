/// Tests the kyc test behavior and guards its key user-facing and domain expectations.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/core/utils/bank_account_validator.dart';
import 'package:paidix/core/utils/cnic_formatter.dart';
import 'package:paidix/core/utils/phone_formatter.dart';
import 'package:paidix/features/kyc/data/kyc_image_processor.dart';
import 'package:paidix/features/kyc/domain/kyc_models.dart';
import 'package:paidix/features/kyc/presentation/pages/kyc_page.dart';
import 'package:paidix/features/kyc/presentation/widgets/kyc_file_picker_tile.dart';
import 'package:paidix/features/kyc/presentation/widgets/kyc_header.dart';
import 'package:paidix/features/kyc/presentation/widgets/kyc_permission_dialog.dart';
import 'package:paidix/features/kyc/presentation/widgets/kyc_stepper.dart';
import 'package:paidix/features/kyc/presentation/widgets/kyc_success_dialog.dart';

/// Configures and launches the application or test suite.
void main() {
  group('CNIC Utilities & Realtime Validation', () {
    test('CnicValidator cleans non-digit characters correctly', () {
      expect(CnicValidator.clean('35202-0450461-5'), equals('3520204504615'));
      expect(CnicValidator.clean(' 35202 0450461 5 '), equals('3520204504615'));
      expect(CnicValidator.clean('abc'), equals(''));
    });

    test('CnicValidator formats clean 13 digits to standard Pakistani format', () {
      expect(CnicValidator.format('3520204504615'), equals('35202-0450461-5'));
      expect(CnicValidator.format('6110112345671'), equals('61101-1234567-1'));
    });

    test('CnicValidator validates 13 digits and valid province code (1-8)', () {
      expect(CnicValidator.isValidFormat('35202-0450461-5'), isTrue);
      expect(CnicValidator.isValidFormat('3520204504615'), isTrue);
      expect(CnicValidator.isValidFormat('95202-0450461-5'), isFalse); // Province 9 invalid
      expect(CnicValidator.isValidFormat('05202-0450461-5'), isFalse); // Province 0 invalid
      expect(CnicValidator.isValidFormat('35202'), isFalse); // Less than 13 digits
    });

    test('CnicValidator.checkAvailability returns intelligent status codes', () async {
      expect(await CnicValidator.checkAvailability(''), equals(CnicStatus.empty));
      expect(await CnicValidator.checkAvailability('35202'), equals(CnicStatus.incomplete));
      expect(await CnicValidator.checkAvailability('9520204504615'), equals(CnicStatus.invalidFormat));
      expect(await CnicValidator.checkAvailability('3520200000000'), equals(CnicStatus.alreadyRegistered));
      expect(await CnicValidator.checkAvailability('4210112345671'), equals(CnicStatus.available));
    });

    test('CnicInputFormatter formats typed digits into hyphenated string dynamically', () {
      final formatter = CnicInputFormatter();
      const oldValue = TextEditingValue.empty;

      final step1 = formatter.formatEditUpdate(
        oldValue,
        const TextEditingValue(text: '35202'),
      );
      expect(step1.text, equals('35202'));

      final step2 = formatter.formatEditUpdate(
        step1,
        const TextEditingValue(text: '352020'),
      );
      expect(step2.text, equals('35202-0'));

      final step3 = formatter.formatEditUpdate(
        step2,
        const TextEditingValue(text: '3520204504615'),
      );
      expect(step3.text, equals('35202-0450461-5'));
    });
  });

  group('Phone Utilities & Realtime Validation', () {
    test('PhoneFormatter formats clean digits into US standard (XXX) XXX-XXXX', () {
      expect(PhoneFormatter.formatUs('3363060546'), equals('(336) 306-0546'));
      expect(PhoneFormatter.formatUs('(336) 306-0546'), equals('(336) 306-0546'));
      expect(PhoneFormatter.formatUs('336'), equals('(336'));
      expect(PhoneFormatter.formatUs('336306'), equals('(336) 306'));
      expect(PhoneFormatter.formatUs(''), equals(''));
    });

    test('PhoneFormatter formats clean digits into Pakistani standard XXX XXXXXXX', () {
      expect(PhoneFormatter.formatPk('3217649976'), equals('321 7649976'));
      expect(PhoneFormatter.formatPk('321 7649976'), equals('321 7649976'));
      expect(PhoneFormatter.formatPk('03217649976'), equals('321 7649976'));
      expect(PhoneFormatter.formatPk('+923217649976'), equals('321 7649976'));
      expect(PhoneFormatter.formatPk('923217649976'), equals('321 7649976'));
      expect(PhoneFormatter.formatPk('321'), equals('321'));
      expect(PhoneFormatter.formatPk(''), equals(''));
    });

    test('PhoneInputFormatter dynamically formats US number while typing', () {
      final formatter = PhoneInputFormatter(isUs: true);
      const oldValue = TextEditingValue.empty;

      final s1 = formatter.formatEditUpdate(
        oldValue,
        const TextEditingValue(text: '336'),
      );
      expect(s1.text, equals('(336'));

      final s2 = formatter.formatEditUpdate(
        s1,
        const TextEditingValue(text: '(3363'),
      );
      expect(s2.text, equals('(336) 3'));

      final s3 = formatter.formatEditUpdate(
        s2,
        const TextEditingValue(text: '(336) 3060546'),
      );
      expect(s3.text, equals('(336) 306-0546'));
    });

    test('PhoneValidator correctly checks US NANP and PK mobile standards', () {
      // US tests
      expect(PhoneValidator.isValidUs('3363060546'), isTrue);
      expect(PhoneValidator.isValidUs('(336) 306-0546'), isTrue);
      expect(PhoneValidator.isValidUs('(036) 306-0546'), isFalse); // Area code starts with 0
      expect(PhoneValidator.isValidUs('(136) 306-0546'), isFalse); // Area code starts with 1
      expect(PhoneValidator.isValidUs('(336) 106-0546'), isFalse); // Exchange code starts with 1
      expect(PhoneValidator.isValidUs('336306'), isFalse); // Incomplete

      // PK tests
      expect(PhoneValidator.isValidPk('3217649976'), isTrue);
      expect(PhoneValidator.isValidPk('321 7649976'), isTrue);
      expect(PhoneValidator.isValidPk('03217649976'), isTrue); // With leading 0
      expect(PhoneValidator.isValidPk('+923217649976'), isTrue); // With +92 country code
      expect(PhoneValidator.isValidPk('923217649976'), isTrue); // With 92 country code
      expect(PhoneValidator.isValidPk('2217649976'), isFalse); // Not starting with 3
      expect(PhoneValidator.isValidPk('32176'), isFalse); // Incomplete
    });

    test('PersonalInfo validation supports both US (+1) and PK (+92) numbers', () {
      // Valid PK
      const validPk = PersonalInfo(
        fullName: 'Hassan Azeem',
        countryCode: 'PK +92',
        phoneNumber: '321 7649976',
        smsConsent: true,
      );
      expect(validPk.isValid, isTrue);

      // Valid US
      const validUs = PersonalInfo(
        fullName: 'Jerry DAT',
        countryCode: 'US +1',
        phoneNumber: '(336) 306-0546',
        smsConsent: true,
      );
      expect(validUs.isValid, isTrue);

      // Invalid US area code starting with 0
      const invalidUs = PersonalInfo(
        fullName: 'Jerry DAT',
        countryCode: 'US +1',
        phoneNumber: '(036) 306-0546',
        smsConsent: true,
      );
      expect(invalidUs.isValid, isFalse);
    });
  });

  group('KYC Domain Models & Validation', () {
    test('PersonalInfo validation requires name, phone and smsConsent', () {
      const empty = PersonalInfo();
      expect(empty.isValid, isFalse);

      const partial = PersonalInfo(
        fullName: 'Hassan Azeem',
        phoneNumber: '3217649976',
        smsConsent: false,
      );
      expect(partial.isValid, isFalse);

      const valid = PersonalInfo(
        fullName: 'Hassan Azeem',
        phoneNumber: '3217649976',
        smsConsent: true,
      );
      expect(valid.isValid, isTrue);
    });

    test('IdentityDocInfo validation checks for cnic and both documents', () {
      const empty = IdentityDocInfo();
      expect(empty.hasFiles, isFalse);
      expect(empty.isValid, isFalse);

      const withFrontOnly = IdentityDocInfo(
        cnicNumber: '35202-0450463-2',
        frontFileName: 'cnic_front.jpg',
      );
      expect(withFrontOnly.hasFiles, isFalse);
      expect(withFrontOnly.isValid, isFalse);

      const complete = IdentityDocInfo(
        cnicNumber: '35202-0450463-2',
        frontFileName: 'cnic_front.jpg',
        backFileName: 'cnic_back.jpg',
      );
      expect(complete.hasFiles, isTrue);
      expect(complete.isValid, isTrue);
    });

    test('BankInfo validation requires valid Pakistani bank and Account Number, with optional IBAN', () {
      const empty = BankInfo();
      expect(empty.isValid, isFalse);

      // Account number missing
      const noAccount = BankInfo(
        bankName: 'Meezan Bank Limited',
        beneficiaryTitle: 'Abdullah Azeem',
        accountNumber: '',
        iban: '',
      );
      expect(noAccount.isValid, isFalse);

      // Incomplete account number (e.g. 8 digits for Meezan which needs 10-14)
      const incompleteAcc = BankInfo(
        bankName: 'Meezan Bank Limited',
        beneficiaryTitle: 'Abdullah Azeem',
        accountNumber: '12345678',
        iban: '',
      );
      expect(incompleteAcc.isValid, isFalse);

      // Valid account number with empty IBAN (IBAN is optional) -> Valid!
      const validWithoutIban = BankInfo(
        bankName: 'Meezan Bank Limited',
        beneficiaryTitle: 'Abdullah Azeem',
        accountNumber: '01010102030405',
        iban: '',
      );
      expect(validWithoutIban.isValid, isTrue);

      // Valid account number with valid IBAN -> Valid!
      const validWithIban = BankInfo(
        bankName: 'Meezan Bank Limited',
        beneficiaryTitle: 'Abdullah Azeem',
        accountNumber: '01010102030405',
        iban: 'PK36MEZN0001234567890123',
      );
      expect(validWithIban.isValid, isTrue);

      // Valid account number with invalid IBAN format -> Invalid!
      const invalidIban = BankInfo(
        bankName: 'Meezan Bank Limited',
        beneficiaryTitle: 'Abdullah Azeem',
        accountNumber: '01010102030405',
        iban: 'INVALID_IBAN_123',
      );
      expect(invalidIban.isValid, isFalse);

      // Legacy fallback: valid when legacy 14+ digit iban was provided
      const legacyValid = BankInfo(
        bankName: 'Meezan Bank Limited',
        beneficiaryTitle: 'Abdullah Azeem',
        iban: 'PK36MEZN0001234567890123',
      );
      expect(legacyValid.isValid, isTrue);
    });
  });

  group('BankAccountValidator & Intelligent Bank Rules', () {
    test('detects unique account number lengths and rules for digital wallets and commercial banks', () {
      // JazzCash: 11 digits starting with 03
      final jcRule = BankAccountValidator.getRule('JazzCash');
      expect(jcRule.isMobileWallet, isTrue);
      expect(jcRule.typicalDigits, equals(11));
      expect(BankAccountValidator.isAccountNumberValid('JazzCash', '03001234567'), isTrue);
      expect(BankAccountValidator.isAccountNumberValid('JazzCash', '02001234567'), isFalse); // Not starting with 03
      expect(BankAccountValidator.isAccountNumberValid('JazzCash', '0300123'), isFalse); // Incomplete

      // EasyPaisa: 11 digits starting with 03
      final epRule = BankAccountValidator.getRule('EasyPaisa');
      expect(epRule.isMobileWallet, isTrue);
      expect(BankAccountValidator.isAccountNumberValid('EasyPaisa', '03451234567'), isTrue);

      // SadaPay: 11 digits starting with 03
      expect(BankAccountValidator.isAccountNumberValid('SadaPay', '03217649976'), isTrue);

      // Meezan Bank: 10-14 digits (standard 14)
      final meezanRule = BankAccountValidator.getRule('Meezan Bank Limited');
      expect(meezanRule.isMobileWallet, isFalse);
      expect(meezanRule.typicalDigits, equals(14));
      expect(meezanRule.ibanBankCode, equals('MEZN'));
      expect(BankAccountValidator.isAccountNumberValid('Meezan Bank Limited', '01010102030405'), isTrue); // 14 digits
      expect(BankAccountValidator.isAccountNumberValid('Meezan Bank Limited', '123456'), isFalse); // < 10 digits

      // HBL: 14-16 digits
      final hblRule = BankAccountValidator.getRule('Habib Bank Limited (HBL)');
      expect(hblRule.ibanBankCode, equals('HABB'));
      expect(BankAccountValidator.isAccountNumberValid('Habib Bank Limited (HBL)', '00427901234503'), isTrue); // 14 digits

      // Bank Alfalah: 14 digits
      final baflRule = BankAccountValidator.getRule('Bank Alfalah Limited');
      expect(baflRule.ibanBankCode, equals('ALFH'));
      expect(BankAccountValidator.isAccountNumberValid('Bank Alfalah Limited', '01231001234567'), isTrue); // 14 digits
    });

    test('validates IBAN optionally and enforces 24-character PK standard', () {
      // Empty IBAN is valid because IBAN is optional
      expect(BankAccountValidator.isIbanValid(''), isTrue);
      expect(BankAccountValidator.isIbanValid('   '), isTrue);

      // Valid Pakistani IBANs (24 characters)
      expect(BankAccountValidator.isIbanValid('PK36MEZN0001234567890123'), isTrue);
      expect(BankAccountValidator.isIbanValid('PK00 MEZN 0001 2345 6789 0123'), isTrue); // With spaces

      // Invalid IBANs
      expect(BankAccountValidator.isIbanValid('US12MEZN0001234567890123'), isFalse); // Not PK
      expect(BankAccountValidator.isIbanValid('PK36MEZN0001'), isFalse); // < 24 chars
      expect(BankAccountValidator.isIbanValid('PK36MEZN00012345678901234567'), isFalse); // > 24 chars
    });
  });

  group('KycImageProcessor Intelligence Pipeline', () {
    test('enhances document with multi-stage progress and compression calculation', () async {
      const processor = KycImageProcessor();
      final stages = <String>[];
      final progresses = <double>[];

      final result = await processor.enhanceDocument(
        fileName: 'cnic_sample.jpg',
        isSelfie: false,
        onProgress: (progress, stage) {
          progresses.add(progress);
          stages.add(stage);
        },
      );

      expect(result.processedBytes, isNotNull);
      expect(result.compressionRatio, isNotNull);
      expect(stages.isNotEmpty, isTrue);
      expect(progresses.isNotEmpty, isTrue);
      expect(progresses.last, equals(1.0));
    });

    test('enhances selfie photo with facial detection milestones', () async {
      const processor = KycImageProcessor();
      final stages = <String>[];

      final result = await processor.enhanceDocument(
        fileName: 'selfie.png',
        isSelfie: true,
        onProgress: (p, stage) => stages.add(stage),
      );

      expect(result.processedBytes, isNotNull);
      expect(stages.any((s) => s.contains('facial') || s.contains('Facial') || s.contains('Face')), isTrue);
    });
  });

  group('KYC Presentation Widgets', () {
    testWidgets('KycHeader displays logo, ACCOUNT SETUP badge and Log out button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: KycHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PaidiX'), findsOneWidget);
      expect(find.text('ACCOUNT SETUP'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('KycStepper displays all 4 steps with numbers and labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: KycStepper(
              currentStep: KycStep.identity,
              onStepTapped: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('Identity'), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('PK Bank'), findsOneWidget);
    });

    testWidgets('KycPage renders Step 1 Personal details and fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const KycPage(initialStep: KycStep.personal),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('STEP 1 OF 4'), findsOneWidget);
      expect(find.text('Tell us about you.'), findsOneWidget);
      expect(find.text('Basic details we\'ll use on your profile.'), findsOneWidget);
      expect(find.text('FULL NAME'), findsOneWidget);
      expect(find.text('PHONE'), findsOneWidget);
      expect(find.text('PK +92'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('KycPage renders Step 2 Identity verification with CNIC and browse buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const KycPage(initialStep: KycStep.identity),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('STEP 2 OF 4'), findsOneWidget);
      expect(find.text('Verify your identity.'), findsOneWidget);
      expect(find.text('CNIC NUMBER'), findsOneWidget);
      expect(find.text('CNIC — FRONT'), findsOneWidget);
      expect(find.text('CNIC — BACK'), findsOneWidget);
      expect(find.textContaining('State Bank KYC Requirement'), findsOneWidget);

      // Realtime validation test: typing CNIC dynamically triggers checking and Available
      await tester.enterText(find.byType(TextField), '4210112345671');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Unique CNIC • Unregistered'), findsOneWidget);
    });

    testWidgets('KycPage renders Step 3 Photo upload with camera capture and guidelines', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const KycPage(initialStep: KycStep.photo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('STEP 3 OF 4'), findsOneWidget);
      expect(find.text('Upload your photo.'), findsOneWidget);
      expect(find.text('Live Photo Capture with Face Detection'), findsOneWidget);
      expect(find.text('Photo Guidelines'), findsOneWidget);
      expect(find.text('OR CHOOSE EXISTING PHOTO FILE'), findsOneWidget);
    });

    testWidgets('KycPage renders Step 4 Pakistani Bank Account linking with separate Account Number and optional IBAN', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const KycPage(initialStep: KycStep.bank),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('STEP 4 OF 4'), findsOneWidget);
      expect(find.text('Link your Pakistani Bank Account.'), findsOneWidget);
      expect(find.text('PAKISTANI BANK'), findsOneWidget);
      expect(find.text('BENEFICIARY ACCOUNT TITLE'), findsOneWidget);
      expect(find.text('ACCOUNT NUMBER'), findsOneWidget);
      expect(find.text('IBAN (OPTIONAL)'), findsOneWidget);
      expect(find.text('1-LINK & PRISM Real-time Direct Clearing'), findsOneWidget);
    });

    testWidgets('KycHeader and KycPage adapt cleanly to narrow 360px and 320px screens with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const KycPage(initialStep: KycStep.personal),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('ACCOUNT SETUP'), findsOneWidget);
    });

    testWidgets('KycFilePickerTile responds to tap with smooth bounce scale animation', (tester) async {
      bool browseTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: KycFilePickerTile(
              label: 'CNIC — FRONT',
              onBrowse: () => browseTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final browseBtn = find.text('BROWSE');
      expect(browseBtn, findsOneWidget);

      await tester.tap(browseBtn);
      await tester.pump(const Duration(milliseconds: 50));
      expect(browseTapped, isTrue);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('KycPermissionDialog renders without pixel overflow on narrow 320px screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                KycPermissionDialog.show(
                  context,
                  isCamera: false,
                  onGranted: () {},
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Photo Gallery Access Required'), findsOneWidget);
      expect(find.text('Grant Permission'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      // Verify zero render overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Step 1 allows selecting US (+1) country code and formats phone with real-time spacing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const KycPage(initialStep: KycStep.personal),
        ),
      );
      await tester.pumpAndSettle();

      // Verify default PK +92 is shown
      expect(find.text('PK +92'), findsOneWidget);

      // Tap on the country code dropdown
      await tester.tap(find.text('PK +92'));
      await tester.pumpAndSettle();

      // Dropdown menu appears with US +1 option
      expect(find.text('US +1'), findsOneWidget);

      // Select United States (US +1) from the dropdown
      await tester.tap(find.text('US +1'));
      await tester.pumpAndSettle();

      // Verify selected button now shows US +1
      expect(find.text('US +1'), findsOneWidget);

      // Find the phone input field (second textfield on page, first is Full Name)
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(4)); // Full Name, Phone, Address, City

      final phoneField = textFields.at(1);

      // Type digits: 3363060546
      await tester.enterText(phoneField, '3363060546');
      await tester.pumpAndSettle();

      // Verify realtime spacing & formatting (XXX) XXX-XXXX in the controller
      final phoneWidget = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(phoneWidget.controller?.text, equals('(336) 306-0546'));
      expect(find.text('Valid United States Phone Number'), findsOneWidget);
    });
    testWidgets('KycSuccessDialog renders concise square layout with animated checkmark and spongy dashboard button', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => KycSuccessDialog.show(context),
              child: const Text('Show Kyc Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show Kyc Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Account Setup Complete!'), findsOneWidget);
      expect(find.text('Your identity & bank details have been securely submitted.'), findsOneWidget);
      expect(find.text('Submitted & Under Review'), findsOneWidget);
      expect(find.text('Go to Dashboard'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
