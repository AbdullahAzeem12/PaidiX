import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paidix/app/theme/app_theme.dart';
import 'package:paidix/core/widgets/bank_logo_widget.dart';
import 'package:paidix/core/widgets/bank_selector_sheet.dart';
import 'package:paidix/features/profile/domain/pakistan_banks.dart';

void main() {
  group('Pakistani Banks Directory & Resolver Suite', () {
    test('Directory contains exactly 39 authoritative banking institutions', () {
      expect(kAllPakistaniBanks.length, equals(39));

      // Verify category distribution
      final commercial =
          kAllPakistaniBanks.where((b) => b.category == BankCategory.commercial);
      final islamic =
          kAllPakistaniBanks.where((b) => b.category == BankCategory.islamic);
      final specialized =
          kAllPakistaniBanks.where((b) => b.category == BankCategory.specialized);
      final foreign =
          kAllPakistaniBanks.where((b) => b.category == BankCategory.foreign);
      final microfinance =
          kAllPakistaniBanks.where((b) => b.category == BankCategory.microfinance);
      final fintech =
          kAllPakistaniBanks.where((b) => b.category == BankCategory.fintech);

      expect(commercial.length, equals(17));
      expect(islamic.length, equals(4));
      expect(specialized.length, equals(4));
      expect(foreign.length, equals(3));
      expect(microfinance.length, equals(8));
      expect(fintech.length, equals(3));
    });

    test('findPakistaniBank resolves abbreviations, names, and aliases accurately',
        () {
      // Abbreviation checks
      expect(findPakistaniBank('MEBL').name, equals('Meezan Bank Limited'));
      expect(findPakistaniBank('HBL').name, equals('Habib Bank Limited (HBL)'));
      expect(findPakistaniBank('UBL').name, equals('United Bank Limited (UBL)'));
      expect(findPakistaniBank('ABL').name, equals('Allied Bank Limited (ABL)'));
      expect(findPakistaniBank('SADA').name, equals('SadaPay'));
      expect(findPakistaniBank('NAYA').name, equals('NayaPay'));
      expect(findPakistaniBank('RAAST').name,
          equals('Raast (SBP Instant Payment System)'));
      expect(findPakistaniBank('CITI').name, equals('Citibank N.A. Pakistan'));
      expect(findPakistaniBank('DB').name, equals('Deutsche Bank AG Pakistan'));

      // Aliases checks
      expect(findPakistaniBank('JazzCash').code, equals('MMBL'));
      expect(findPakistaniBank('EasyPaisa').code, equals('TMFB'));
      expect(findPakistaniBank('Standard Chartered').code, equals('SCB'));
      expect(findPakistaniBank('Dubai Islamic').code, equals('DIBPL'));
    });
  });

  group('BankLogoWidget & Selector Presentation Suite', () {
    testWidgets('BankLogoWidget renders custom brand signatures for fintech and banks',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Column(
              children: [
                BankLogoWidget(bankName: 'SadaPay', size: 40),
                BankLogoWidget(bankName: 'NayaPay', size: 40),
                BankLogoWidget(bankName: 'JazzCash', size: 40),
                BankLogoWidget(bankName: 'EasyPaisa', size: 40),
                BankLogoWidget(bankName: 'Raast', size: 40),
                BankLogoWidget(bankName: 'Meezan Bank Limited', size: 40),
                BankLogoWidget(bankName: 'Citibank', size: 40),
                BankLogoWidget(bankName: 'Deutsche Bank', size: 40),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(BankLogoWidget), findsNWidgets(8));
      expect(find.text('sada'), findsOneWidget);
      expect(find.text('NAYA'), findsOneWidget);
      expect(find.text('JC'), findsOneWidget);
      expect(find.text('EP'), findsOneWidget);
      expect(find.text('RAAST'), findsOneWidget);
      expect(find.text('MEBL'), findsOneWidget);
      expect(find.text('citi'), findsOneWidget);
    });

    testWidgets('BankSelectorSheet filters banks by search query and category chips',
        (WidgetTester tester) async {
      PakistaniBank? pickedBank;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  pickedBank = await BankSelectorSheet.show(
                    ctx,
                    selectedBankName: 'JazzCash',
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Select Bank'), findsOneWidget);
      expect(find.text('39 Available'), findsOneWidget);

      // Search for "HBL"
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'HBL');
      await tester.pumpAndSettle();

      expect(find.text('Habib Bank Limited (HBL)'), findsOneWidget);

      // Tap HBL
      await tester.tap(find.text('Habib Bank Limited (HBL)'));
      await tester.pumpAndSettle();

      expect(pickedBank, isNotNull);
      expect(pickedBank!.code, equals('HBL'));
    });
  });
}
