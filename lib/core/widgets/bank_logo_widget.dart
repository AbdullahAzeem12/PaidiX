import 'package:flutter/material.dart';
import '../../features/profile/domain/pakistan_banks.dart';

/// Premium, high-fidelity vector brand logo for all 39 verified Pakistani banks
/// and digital payment systems (JazzCash, EasyPaisa, SadaPay, NayaPay, Raast, HBL, Meezan, etc.).
class BankLogoWidget extends StatelessWidget {
  final PakistaniBank? bank;
  final String? bankName;
  final double size;
  final bool elevated;

  const BankLogoWidget({
    super.key,
    this.bank,
    this.bankName,
    this.size = 38,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBank =
        bank ?? findPakistaniBank(bankName ?? 'JazzCash');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            effectiveBank.primaryColor,
            effectiveBank.primaryColor.withValues(alpha: 0.88),
          ],
        ),
        border: Border.all(
          color: effectiveBank.accentColor.withValues(alpha: 0.32),
          width: 1.1,
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: effectiveBank.primaryColor.withValues(alpha: 0.30),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient branded background pattern
            _buildBackgroundPattern(effectiveBank),

            // Foreground Authentic Logo Content
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: EdgeInsets.all(size * 0.08),
                child: _buildBrandContent(effectiveBank),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundPattern(PakistaniBank bank) {
    switch (bank.code) {
      case 'MMBL': // JazzCash
        return Positioned(
          bottom: -4,
          right: -4,
          child: Container(
            width: size * 0.55,
            height: size * 0.55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bank.accentColor.withValues(alpha: 0.35),
            ),
          ),
        );
      case 'ABL': // Allied Bank
        return Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: size * 0.35,
            height: size,
            color: bank.accentColor.withValues(alpha: 0.25),
          ),
        );
      case 'SCB': // Standard Chartered
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: size * 0.35,
            color: bank.accentColor.withValues(alpha: 0.45),
          ),
        );
      case 'MEBL': // Meezan Bank
        return Positioned(
          top: -3,
          right: -3,
          child: Icon(
            Icons.dark_mode_rounded,
            size: size * 0.5,
            color: bank.accentColor.withValues(alpha: 0.22),
          ),
        );
      case 'RAAST': // Raast
        return Positioned(
          top: -2,
          right: -2,
          child: Icon(
            Icons.bolt_rounded,
            size: size * 0.65,
            color: bank.accentColor.withValues(alpha: 0.30),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBrandContent(PakistaniBank bank) {
    final textStyle = TextStyle(
      color: bank.textColor,
      fontSize: _fontSizeForMonogram(bank.shortMonogram),
      fontWeight: FontWeight.w900,
      letterSpacing: -0.2,
      height: 1.0,
      fontFamily: 'sans-serif',
    );

    // Specific custom visual signatures
    if (bank.code == 'RAAST') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bolt_rounded, size: size * 0.42, color: bank.accentColor),
          Text(
            'RAAST',
            style: textStyle.copyWith(
              fontSize: size * 0.22,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
    }

    if (bank.code == 'SADA') {
      return Center(
        child: Text(
          'sada',
          style: TextStyle(
            color: bank.textColor,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            fontFamily: 'sans-serif',
          ),
        ),
      );
    }

    if (bank.code == 'CITI') {
      return Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: size * 0.16,
              child: Container(
                width: size * 0.45,
                height: 2.2,
                decoration: BoxDecoration(
                  color: bank.accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'citi',
              style: TextStyle(
                color: bank.textColor,
                fontSize: size * 0.38,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      );
    }

    if (bank.code == 'DB') {
      return Center(
        child: Container(
          width: size * 0.56,
          height: size * 0.56,
          decoration: BoxDecoration(
            border: Border.all(color: bank.textColor, width: 1.8),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Center(
            child: Transform.rotate(
              angle: -0.45,
              child: Container(
                width: 2.2,
                height: size * 0.42,
                color: bank.textColor,
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Text(
        bank.shortMonogram,
        textAlign: TextAlign.center,
        style: textStyle,
      ),
    );
  }

  double _fontSizeForMonogram(String monogram) {
    if (monogram.length <= 2) {
      return size * 0.42;
    } else if (monogram.length == 3) {
      return size * 0.34;
    } else {
      return size * 0.28;
    }
  }
}

/// Category badge pill (e.g., "COMMERCIAL", "ISLAMIC", "FINTECH", "MICROFINANCE")
class BankCategoryPill extends StatelessWidget {
  final BankCategory category;

  const BankCategoryPill({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final Color badgeColor;
    final String label;

    switch (category) {
      case BankCategory.commercial:
        badgeColor = const Color(0xFF006699);
        label = 'COMMERCIAL';
        break;
      case BankCategory.islamic:
        badgeColor = const Color(0xFFD4AF37);
        label = 'ISLAMIC';
        break;
      case BankCategory.specialized:
        badgeColor = const Color(0xFF00695C);
        label = 'SPECIALIZED';
        break;
      case BankCategory.foreign:
        badgeColor = const Color(0xFF5E35B1);
        label = 'FOREIGN';
        break;
      case BankCategory.microfinance:
        badgeColor = const Color(0xFFE65100);
        label = 'MICROFINANCE';
        break;
      case BankCategory.fintech:
        badgeColor = const Color(0xFF5FCFC9);
        label = 'WALLET / FINTECH';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
