import 'package:flutter/foundation.dart';

/// Domain model representing a linked Pakistani PKR receiving bank account.
@immutable
class BankAccountItem {
  final String id;
  final String bankName;
  final String holder;
  final String accountNumber;
  final String iban;
  final bool isPrimary;

  const BankAccountItem({
    required this.id,
    required this.bankName,
    required this.holder,
    required this.accountNumber,
    this.iban = '',
    this.isPrimary = false,
  });

  /// Extracts the last 4 digits for masked display
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

  /// Formatted masked display matching Screenshot 1: •••• •••• 2786
  String get maskedDisplay => '•••• •••• $last4';

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'bankName': bankName,
        'holder': holder,
        'accountNumber': accountNumber,
        'iban': iban,
        'isPrimary': isPrimary,
      };

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

/// Authoritative list of Pakistani banks & digital wallets
const List<String> kPakistaniBanks = [
  'JazzCash (Mobilink Microfinance Bank)',
  'EasyPaisa (Telenor Microfinance Bank)',
  'SadaPay',
  'NayaPay',
  'Meezan Bank Limited',
  'Habib Bank Limited (HBL)',
  'United Bank Limited (UBL)',
  'MCB Bank Limited',
  'Allied Bank Limited (ABL)',
  'Bank Alfalah',
  'Standard Chartered Bank',
  'Faysal Bank',
  'Askari Bank',
  'Bank of Punjab (BOP)',
  'Bank Al Habib',
  'Soneri Bank',
  'JS Bank',
  'Dubai Islamic Bank',
];

