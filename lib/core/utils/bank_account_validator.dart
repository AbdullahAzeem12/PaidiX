/// Defines bank account validator and intelligent Pakistani banking validation rules.

import 'package:flutter/foundation.dart';
import '../../features/profile/domain/pakistan_banks.dart';

/// Validation status for Pakistani bank account numbers.
enum AccountNumberStatus {
  empty,
  incomplete,
  valid,
  tooLong,
  invalidWalletPrefix,
}

/// Validation status for Pakistani IBANs.
enum IbanStatus {
  empty,
  incomplete,
  invalidPrefix,
  invalidCharacters,
  valid,
}

/// Configuration rule for a specific Pakistani bank's account numbering system.
@immutable
class BankAccountRule {
  final String bankCode;
  final String bankName;
  final int minDigits;
  final int maxDigits;
  final int typicalDigits;
  final String hintText;
  final String helperText;
  final String ibanBankCode;
  final bool isMobileWallet;

  const BankAccountRule({
    required this.bankCode,
    required this.bankName,
    required this.minDigits,
    required this.maxDigits,
    required this.typicalDigits,
    required this.hintText,
    required this.helperText,
    required this.ibanBankCode,
    this.isMobileWallet = false,
  });

  /// Human-readable length label: e.g. "14 digits", "11 digits", "10–14 digits"
  String get lengthLabel {
    if (minDigits == maxDigits) {
      return '$minDigits digits';
    }
    return '$minDigits–$maxDigits digits';
  }
}

/// Intelligent Pakistani Bank Account & IBAN Validator.
class BankAccountValidator {
  const BankAccountValidator._();

  /// Strips all non-digit characters.
  static String cleanDigits(String raw) =>
      raw.replaceAll(RegExp(r'\D'), '');

  /// Strips whitespace, hyphens, and non-alphanumeric characters for IBAN.
  static String cleanIban(String raw) =>
      raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

  /// Returns the intelligent bank configuration rule for the given bank name or code.
  static BankAccountRule getRule(String bankNameOrCode) {
    final query = bankNameOrCode.trim().toLowerCase();

    // 1. Digital Wallets & Microfinance Mobile Accounts (11 digits, starts with 03)
    if (query.contains('jazzcash') ||
        query.contains('mobilink') ||
        query == 'mmbl') {
      return const BankAccountRule(
        bankCode: 'MMBL',
        bankName: 'JazzCash',
        minDigits: 11,
        maxDigits: 14,
        typicalDigits: 11,
        hintText: '0300 1234567',
        helperText: '11-digit mobile account number (e.g. 03XXXXXXXXX)',
        ibanBankCode: 'MMBL',
        isMobileWallet: true,
      );
    }

    if (query.contains('easypaisa') ||
        query.contains('telenor') ||
        query == 'tmfb') {
      return const BankAccountRule(
        bankCode: 'TMFB',
        bankName: 'EasyPaisa',
        minDigits: 11,
        maxDigits: 16,
        typicalDigits: 11,
        hintText: '0345 1234567',
        helperText: '11-digit mobile account number (e.g. 03XXXXXXXXX)',
        ibanBankCode: 'TMFB',
        isMobileWallet: true,
      );
    }

    if (query.contains('sadapay') || query == 'sada') {
      return const BankAccountRule(
        bankCode: 'SADA',
        bankName: 'SadaPay',
        minDigits: 11,
        maxDigits: 11,
        typicalDigits: 11,
        hintText: '0300 1234567',
        helperText: '11-digit registered mobile number',
        ibanBankCode: 'SADA',
        isMobileWallet: true,
      );
    }

    if (query.contains('nayapay') || query == 'naya') {
      return const BankAccountRule(
        bankCode: 'NAYA',
        bankName: 'NayaPay',
        minDigits: 11,
        maxDigits: 11,
        typicalDigits: 11,
        hintText: '0300 1234567',
        helperText: '11-digit registered mobile number',
        ibanBankCode: 'NAYA',
        isMobileWallet: true,
      );
    }

    if (query.contains('upaisa') || query.contains('u microfinance')) {
      return const BankAccountRule(
        bankCode: 'UMBL',
        bankName: 'UPaisa',
        minDigits: 11,
        maxDigits: 11,
        typicalDigits: 11,
        hintText: '0333 1234567',
        helperText: '11-digit UPaisa mobile account number',
        ibanBankCode: 'UMBL',
        isMobileWallet: true,
      );
    }

    if (query.contains('zindigi')) {
      return const BankAccountRule(
        bankCode: 'JSBL',
        bankName: 'Zindigi',
        minDigits: 11,
        maxDigits: 11,
        typicalDigits: 11,
        hintText: '0300 1234567',
        helperText: '11-digit Zindigi mobile account number',
        ibanBankCode: 'JSBL',
        isMobileWallet: true,
      );
    }

    // 2. Commercial & Islamic Banking Institutions
    if (query.contains('meezan') || query == 'mebl') {
      return const BankAccountRule(
        bankCode: 'MEBL',
        bankName: 'Meezan Bank Limited',
        minDigits: 10,
        maxDigits: 14,
        typicalDigits: 14,
        hintText: '0101 0102030405',
        helperText: '14-digit account number (4-digit branch + 10-digit account)',
        ibanBankCode: 'MEZN',
      );
    }

    if (query.contains('habib bank') ||
        (query.contains('hbl') && !query.contains('metro'))) {
      return const BankAccountRule(
        bankCode: 'HBL',
        bankName: 'Habib Bank Limited (HBL)',
        minDigits: 14,
        maxDigits: 16,
        typicalDigits: 14,
        hintText: '0042 7901234503',
        helperText: '14-digit standard HBL account number',
        ibanBankCode: 'HABB',
      );
    }

    if (query.contains('united bank') || query.contains('ubl')) {
      return const BankAccountRule(
        bankCode: 'UBL',
        bankName: 'United Bank Limited (UBL)',
        minDigits: 10,
        maxDigits: 14,
        typicalDigits: 14,
        hintText: '0123 4567890123',
        helperText: '10 to 14-digit UBL account number',
        ibanBankCode: 'UNIL',
      );
    }

    if (query.contains('mcb bank') ||
        query.contains('muslim commercial') ||
        query == 'mcb') {
      return const BankAccountRule(
        bankCode: 'MCB',
        bankName: 'MCB Bank Limited',
        minDigits: 14,
        maxDigits: 16,
        typicalDigits: 14,
        hintText: '0123 456789012345',
        helperText: '14 to 16-digit MCB account number',
        ibanBankCode: 'MUCB',
      );
    }

    if (query.contains('alfalah') || query == 'bafl') {
      return const BankAccountRule(
        bankCode: 'BAFL',
        bankName: 'Bank Alfalah Limited',
        minDigits: 14,
        maxDigits: 14,
        typicalDigits: 14,
        hintText: '0123 1001234567',
        helperText: '14-digit account number (4-digit branch + 10-digit account)',
        ibanBankCode: 'ALFH',
      );
    }

    if (query.contains('allied bank') || query == 'abl') {
      return const BankAccountRule(
        bankCode: 'ABL',
        bankName: 'Allied Bank Limited (ABL)',
        minDigits: 14,
        maxDigits: 16,
        typicalDigits: 14,
        hintText: '0010 012345670014',
        helperText: '14 to 16-digit ABL account number',
        ibanBankCode: 'ABPA',
      );
    }

    if (query.contains('standard chartered') || query == 'scb') {
      return const BankAccountRule(
        bankCode: 'SCB',
        bankName: 'Standard Chartered Bank Pakistan',
        minDigits: 11,
        maxDigits: 14,
        typicalDigits: 11,
        hintText: '01 1234567 01',
        helperText: '11-digit Standard Chartered account number',
        ibanBankCode: 'SCBL',
      );
    }

    if (query.contains('national bank') || query == 'nbp') {
      return const BankAccountRule(
        bankCode: 'NBP',
        bankName: 'National Bank of Pakistan (NBP)',
        minDigits: 14,
        maxDigits: 16,
        typicalDigits: 14,
        hintText: '0123 456789012345',
        helperText: '14 to 16-digit NBP account number',
        ibanBankCode: 'NBPA',
      );
    }

    if (query.contains('faysal') || query == 'fbl') {
      return const BankAccountRule(
        bankCode: 'FAYS',
        bankName: 'Faysal Bank Limited',
        minDigits: 14,
        maxDigits: 16,
        typicalDigits: 14,
        hintText: '0123 001234567890',
        helperText: '14-digit Faysal Bank account number',
        ibanBankCode: 'FAYS',
      );
    }

    if (query.contains('punjab') || query == 'bop') {
      return const BankAccountRule(
        bankCode: 'BOP',
        bankName: 'The Bank of Punjab (BOP)',
        minDigits: 14,
        maxDigits: 16,
        typicalDigits: 14,
        hintText: '0123 456789012345',
        helperText: '14 to 16-digit BOP account number',
        ibanBankCode: 'BPUN',
      );
    }

    if (query.contains('askari') || query == 'akbl') {
      return const BankAccountRule(
        bankCode: 'AKBL',
        bankName: 'Askari Bank Limited',
        minDigits: 13,
        maxDigits: 14,
        typicalDigits: 14,
        hintText: '0123 4567890123',
        helperText: '13 to 14-digit Askari Bank account number',
        ibanBankCode: 'ASCM',
      );
    }

    if (query.contains('dubai islamic') || query == 'dib') {
      return const BankAccountRule(
        bankCode: 'DIB',
        bankName: 'Dubai Islamic Bank Pakistan',
        minDigits: 10,
        maxDigits: 14,
        typicalDigits: 14,
        hintText: '0123 4567890123',
        helperText: '10 to 14-digit DIB account number',
        ibanBankCode: 'DIBP',
      );
    }

    if (query.contains('bankislami')) {
      return const BankAccountRule(
        bankCode: 'BKIP',
        bankName: 'BankIslami Pakistan Limited',
        minDigits: 14,
        maxDigits: 14,
        typicalDigits: 14,
        hintText: '1001 00123450001',
        helperText: '14-digit BankIslami account number',
        ibanBankCode: 'BKIP',
      );
    }

    if (query.contains('soneri')) {
      return const BankAccountRule(
        bankCode: 'SNBL',
        bankName: 'Soneri Bank Limited',
        minDigits: 14,
        maxDigits: 14,
        typicalDigits: 14,
        hintText: '0123 4567890123',
        helperText: '14-digit Soneri Bank account number',
        ibanBankCode: 'SONE',
      );
    }

    if (query.contains('habib metro') || query == 'hmb') {
      return const BankAccountRule(
        bankCode: 'HMB',
        bankName: 'Habib Metropolitan Bank',
        minDigits: 14,
        maxDigits: 14,
        typicalDigits: 14,
        hintText: '0123 4567890123',
        helperText: '14-digit Habib Metro account number',
        ibanBankCode: 'HABB',
      );
    }

    if (query.contains('js bank') || query == 'jsbl') {
      return const BankAccountRule(
        bankCode: 'JSBL',
        bankName: 'JS Bank Limited',
        minDigits: 10,
        maxDigits: 14,
        typicalDigits: 14,
        hintText: '0123 4567890123',
        helperText: '10 to 14-digit JS Bank account number',
        ibanBankCode: 'JSBL',
      );
    }

    if (query.contains('bank al habib') || query.contains('al-habib')) {
      return const BankAccountRule(
        bankCode: 'BAHL',
        bankName: 'Bank AL Habib Limited',
        minDigits: 14,
        maxDigits: 17,
        typicalDigits: 17,
        hintText: '1001 0081 01234501',
        helperText: '14 to 17-digit Bank AL Habib account number',
        ibanBankCode: 'BAHL',
      );
    }

    // Default Fallback: Generic Pakistani Bank
    final matchedBank = findPakistaniBank(bankNameOrCode);
    return BankAccountRule(
      bankCode: matchedBank.code,
      bankName: matchedBank.name,
      minDigits: 9,
      maxDigits: 18,
      typicalDigits: 14,
      hintText: '10 to 16-digit account number',
      helperText: 'Standard Pakistani bank account number (10–16 digits)',
      ibanBankCode: matchedBank.code.length >= 4
          ? matchedBank.code.substring(0, 4).toUpperCase()
          : 'PKXX',
    );
  }

  /// Validates the entered account number against the bank's rules.
  static AccountNumberStatus validateAccountNumber(
    String bankName,
    String raw,
  ) {
    final clean = cleanDigits(raw);
    if (clean.isEmpty) return AccountNumberStatus.empty;

    final rule = getRule(bankName);

    // If mobile wallet, ensure standard 11 digits
    if (rule.isMobileWallet) {
      if (clean.length < 11) return AccountNumberStatus.incomplete;
      if (clean.length == 11) {
        if (!clean.startsWith('03')) {
          return AccountNumberStatus.invalidWalletPrefix;
        }
        return AccountNumberStatus.valid;
      }
      if (clean.length > rule.maxDigits) {
        return AccountNumberStatus.tooLong;
      }
      return AccountNumberStatus.valid;
    }

    if (clean.length < rule.minDigits) {
      return AccountNumberStatus.incomplete;
    }
    if (clean.length > rule.maxDigits) {
      return AccountNumberStatus.tooLong;
    }

    return AccountNumberStatus.valid;
  }

  /// Returns true if the account number is completely valid for the bank.
  static bool isAccountNumberValid(String bankName, String raw) {
    final status = validateAccountNumber(bankName, raw);
    return status == AccountNumberStatus.valid;
  }

  /// Validates an entered Pakistani IBAN (Optional field).
  ///
  /// If empty, it is considered valid because IBAN is optional.
  /// If entered, it must adhere strictly to Pakistani IBAN specifications (24 alphanumeric, starts with PK).
  static IbanStatus validateIban(String raw) {
    final clean = cleanIban(raw);
    if (clean.isEmpty) return IbanStatus.empty;

    if (!clean.startsWith('PK')) {
      return IbanStatus.invalidPrefix;
    }

    if (clean.length < 24) {
      return IbanStatus.incomplete;
    }

    if (clean.length > 24) {
      return IbanStatus.invalidCharacters;
    }

    // Must be 24 alphanumeric characters
    if (!RegExp(r'^PK\d{2}[A-Z0-9]{20}$').hasMatch(clean)) {
      return IbanStatus.invalidCharacters;
    }

    return IbanStatus.valid;
  }

  /// Returns true if the IBAN is valid (either empty because optional, or fully valid).
  static bool isIbanValid(String raw) {
    final clean = cleanIban(raw);
    if (clean.isEmpty) return true; // Optional!
    return validateIban(raw) == IbanStatus.valid;
  }

  /// Formats an IBAN with 4-character spaces for visual clarity:
  /// e.g. "PK36 MEZN 0001 2345 6789 0123"
  static String formatIban(String raw) {
    final clean = cleanIban(raw);
    if (clean.isEmpty) return '';

    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }
}
