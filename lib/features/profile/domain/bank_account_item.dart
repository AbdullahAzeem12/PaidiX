/// Defines bank account item in the profile feature's domain layer.

import 'package:flutter/foundation.dart';
export 'pakistan_banks.dart';

/// Domain model representing a linked Pakistani PKR receiving bank account.
@immutable
class BankAccountItem {
  final String id;
  final String bankName;
  final String holder;
  final String accountNumber;
  final String iban;
  final bool isPrimary;

  /// Creates an immutable account record for persistence and settings UI.
  const BankAccountItem({
    required this.id,
    required this.bankName,
    required this.holder,
    required this.accountNumber,
    this.iban = '',
    this.isPrimary = false,
  });

  /// Extracts the last four numeric characters for a masked account label.
  ///
  /// Uses the IBAN when the account number is too short, then a safe fallback
  /// when neither field contains four digits.
  String get last4 {
    final cleanNum = accountNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanNum.length >= 4) {
      return cleanNum.substring(cleanNum.length - 4);
    }
    final cleanIban = iban.replaceAll(RegExp(r'\D'), '');
    if (cleanIban.length >= 4) {
      return cleanIban.substring(cleanIban.length - 4);
    }
    return cleanNum.isNotEmpty ? cleanNum : '2786';
  }

  /// Formats the account number for display without exposing the full value.
  String get maskedDisplay => '•••• •••• $last4';

  /// Copies this record while retaining every field not explicitly replaced.
  BankAccountItem copyWith({
    String? id,
    String? bankName,
    String? holder,
    String? accountNumber,
    String? iban,
    bool? isPrimary,
  }) {
    return BankAccountItem(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      holder: holder ?? this.holder,
      accountNumber: accountNumber ?? this.accountNumber,
      iban: iban ?? this.iban,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  /// Converts the account to the JSON shape stored by the profile repository.
  Map<String, dynamic> toJson() => {
        'id': id,
        'bankName': bankName,
        'holder': holder,
        'accountNumber': accountNumber,
        'iban': iban,
        'isPrimary': isPrimary,
      };

  /// Rebuilds an account from saved JSON, supplying defaults for missing fields.
  factory BankAccountItem.fromJson(Map<String, dynamic> json) {
    return BankAccountItem(
      id: json['id'] as String? ??
          'bank_${DateTime.now().millisecondsSinceEpoch}',
      bankName: json['bankName'] as String? ??
          'JazzCash (Mobilink Microfinance Bank)',
      holder: json['holder'] as String? ?? 'Abdullah Azeem',
      accountNumber: json['accountNumber'] as String? ?? '03225352786',
      iban: json['iban'] as String? ?? '',
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }

  /// Compares accounts by all persisted fields, not by object identity.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BankAccountItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          bankName == other.bankName &&
          holder == other.holder &&
          accountNumber == other.accountNumber &&
          iban == other.iban &&
          isPrimary == other.isPrimary;

  /// Produces a hash consistent with [operator ==] for collection use.
  @override
  int get hashCode => Object.hash(
        id,
        bankName,
        holder,
        accountNumber,
        iban,
        isPrimary,
      );
}

/// Authoritative list of Pakistani banks & digital wallets (39 institutions)
const List<String> kPakistaniBanks = [
  // Digital / Microfinance Wallets
  'JazzCash (Mobilink Microfinance Bank)',
  'EasyPaisa (Telenor Microfinance Bank)',
  'SadaPay',
  'NayaPay',
  'Raast (SBP Instant Payment System)',

  // Commercial & Islamic Banks
  'Allied Bank Limited',
  'Askari Bank Limited',
  'Bank Alfalah Limited',
  'Bank Al Habib Limited',
  'Faysal Bank Limited',
  'Habib Bank Limited',
  'Habib Metropolitan Bank Limited',
  'JS Bank Limited',
  'MCB Bank Limited',
  'National Bank of Pakistan',
  'Soneri Bank Limited',
  'Standard Chartered Bank Pakistan',
  'Summit Bank Limited',
  'The Bank of Khyber',
  'The Bank of Punjab',
  'United Bank Limited',
  'Silkbank Limited',
  'Meezan Bank Limited',
  'BankIslami Pakistan Limited',
  'Dubai Islamic Bank Pakistan Limited',
  'MCB Islamic Bank Limited',

  // Specialized & Foreign
  'Zarai Taraqiati Bank Limited',
  'SME Bank Limited',
  'Sindh Bank Limited',
  'Industrial Development Bank of Pakistan',
  'Citibank N.A. Pakistan',
  'Deutsche Bank AG Pakistan',
  'Industrial and Commercial Bank of China Pakistan',

  // Microfinance
  'Khushhali Microfinance Bank',
  'U Microfinance Bank',
  'FINCA Microfinance Bank',
  'NRSP Microfinance Bank',
  'Apna Microfinance Bank',
  'Pak Oman Microfinance Bank',
];

