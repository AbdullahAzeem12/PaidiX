import 'package:flutter/material.dart';
import '../../features/profile/domain/pakistan_banks.dart';

/// Semantic bank icon for Pakistani banks and digital payment systems.
/// Renders standard outline icon (phone for wallets, bank building for banks)
/// without custom text monograms.
class BankLogoWidget extends StatelessWidget {
  final PakistaniBank? bank;
  final String? bankName;
  final double size;
  final bool elevated;

  const BankLogoWidget({
    super.key,
    this.bank,
    this.bankName,
    this.size = 20,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBank =
        bank ?? findPakistaniBank(bankName ?? 'JazzCash');
    final isWallet = effectiveBank.category == BankCategory.fintech ||
        effectiveBank.category == BankCategory.microfinance;

    return Icon(
      isWallet ? Icons.phone_android_outlined : Icons.account_balance_outlined,
      size: size,
      color: effectiveBank.primaryColor,
    );
  }
}

/// Optional Category badge pill
class BankCategoryPill extends StatelessWidget {
  final BankCategory category;

  const BankCategoryPill({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
