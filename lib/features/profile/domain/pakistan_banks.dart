/// Defines pakistan banks in the profile feature's domain layer.

import 'package:material_ui/material_ui.dart';

/// Semantic categories for Pakistani banking and payment institutions.
enum BankCategory {
  commercial('Commercial Bank'),
  islamic('Islamic Bank'),
  specialized('Specialized / DFI'),
  foreign('Foreign Bank'),
  microfinance('Microfinance Bank'),
  fintech('Digital Wallet / Fintech');

  final String label;
  const BankCategory(this.label);
}

/// Rich domain model representing a verified Pakistani banking or payment institution.
class PakistaniBank {
  final String name;
  final String code;
  final BankCategory category;
  final Color primaryColor;
  final Color accentColor;
  final Color textColor;
  final String shortMonogram;
  final List<String> aliases;

  /// Creates the immutable directory record used for search and bank branding.
  const PakistaniBank({
    required this.name,
    required this.code,
    required this.category,
    required this.primaryColor,
    this.accentColor = Colors.white,
    this.textColor = Colors.white,
    required this.shortMonogram,
    this.aliases = const [],
  });

  /// Formatted name with abbreviation code: e.g. "Habib Bank Limited (HBL)"
  String get displayName => name.contains('(') ? name : '$name ($code)';

  /// Checks whether [query] matches the bank's name, code, category, monogram,
  /// or one of its aliases.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (name.toLowerCase().contains(q)) return true;
    if (code.toLowerCase().contains(q)) return true;
    if (category.label.toLowerCase().contains(q)) return true;
    if (shortMonogram.toLowerCase().contains(q)) return true;
    for (final alias in aliases) {
      if (alias.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

/// Shared catalog used by bank search, selection, and logo presentation.
///
/// The list order also determines the empty-query and unmatched-query fallback.
/// Ordered with most popular digital wallets and top commercial institutions at top (matching Screenshot 3).
const List<PakistaniBank> kAllPakistaniBanks = [
  // ===========================================================================
  // Top Featured Wallets & Commercial Banks (matching UI Screenshot 3)
  // ===========================================================================
  PakistaniBank(
    name: 'JazzCash (Mobilink Microfinance Bank)',
    code: 'MMBL',
    category: BankCategory.microfinance,
    primaryColor: Color(0xFFE31B23), // Jazz Vibrant Red
    accentColor: Color(0xFFFFC20E),  // Jazz Yellow/Gold
    shortMonogram: 'JC',
    aliases: [
      'MMBL',
      'JazzCash',
      'Mobilink Microfinance Bank (JazzCash)',
      'JazzCash (Mobilink Bank)',
      'Mobilink Bank',
      'Mobilink Microfinance Bank',
    ],
  ),
  PakistaniBank(
    name: 'EasyPaisa (Telenor Microfinance Bank)',
    code: 'TMFB',
    category: BankCategory.microfinance,
    primaryColor: Color(0xFF1EB853), // EasyPaisa Vibrant Green
    accentColor: Colors.white,
    shortMonogram: 'EP',
    aliases: [
      'TMFB',
      'EasyPaisa',
      'Telenor Microfinance Bank (EasyPaisa)',
      'EasyPaisa (Telenor Bank)',
      'Telenor Bank',
      'Telenor Microfinance Bank',
    ],
  ),
  PakistaniBank(
    name: 'SadaPay',
    code: 'SADA',
    category: BankCategory.fintech,
    primaryColor: Color(0xFFFF6E5A), // SadaPay Signature Sunset Coral
    accentColor: Colors.white,
    shortMonogram: 'SADA',
    aliases: ['SADA', 'SadaPay', 'Sada Pay'],
  ),
  PakistaniBank(
    name: 'NayaPay',
    code: 'NAYA',
    category: BankCategory.fintech,
    primaryColor: Color(0xFF00D2D3), // NayaPay Electric Cyan
    accentColor: Color(0xFF192A56),  // Deep Navy
    textColor: Color(0xFF192A56),
    shortMonogram: 'NAYA',
    aliases: ['NAYA', 'NayaPay', 'Naya Pay'],
  ),
  PakistaniBank(
    name: 'Meezan Bank Limited',
    code: 'MEBL',
    category: BankCategory.islamic,
    primaryColor: Color(0xFF1E293B), // Royal Slate
    accentColor: Color(0xFFD4AF37),  // Sovereign Islamic Gold
    shortMonogram: 'MEBL',
    aliases: ['MEBL', 'Meezan Bank', 'Meezan Bank Limited', 'Meezan'],
  ),
  PakistaniBank(
    name: 'Habib Bank Limited (HBL)',
    code: 'HBL',
    category: BankCategory.commercial,
    primaryColor: Color(0xFF008248), // Iconic HBL Green
    accentColor: Colors.white,
    shortMonogram: 'HBL',
    aliases: ['HBL', 'Habib Bank', 'Habib Bank Limited'],
  ),
  PakistaniBank(
    name: 'United Bank Limited (UBL)',
    code: 'UBL',
    category: BankCategory.commercial,
    primaryColor: Color(0xFF003399), // UBL Royal Blue
    accentColor: Color(0xFF00A3E0),  // Cyan
    shortMonogram: 'UBL',
    aliases: ['UBL', 'United Bank', 'United Bank Limited'],
  ),
  PakistaniBank(
    name: 'MCB Bank Limited',
    code: 'MCB',
    category: BankCategory.commercial,
    primaryColor: Color(0xFFE53935), // MCB Vivid Red
    accentColor: Color(0xFF0A2F6E),  // MCB Navy
    shortMonogram: 'MCB',
    aliases: ['MCB', 'MCB Bank'],
  ),
  PakistaniBank(
    name: 'Allied Bank Limited (ABL)',
    code: 'ABL',
    category: BankCategory.commercial,
    primaryColor: Color(0xFF002D62), // Allied Navy
    accentColor: Color(0xFFF58220),  // Allied Orange
    shortMonogram: 'ABL',
    aliases: ['ABL', 'Allied Bank', 'Allied Bank Limited'],
  ),
  PakistaniBank(
    name: 'Bank Alfalah Limited',
    code: 'BAFL',
    category: BankCategory.commercial,
    primaryColor: Color(0xFFE30613), // Alfalah Crimson
    accentColor: Color(0xFF002B49),  // Navy
    shortMonogram: 'BAFL',
    aliases: ['BAFL', 'Bank Alfalah', 'Alfalah'],
  ),
  PakistaniBank(
    name: 'Standard Chartered Bank Pakistan',
    code: 'SCB',
    category: BankCategory.commercial,
    primaryColor: Color(0xFF006699), // SCB Trust Blue
    accentColor: Color(0xFF00A550),  // SCB Green
    shortMonogram: 'SCB',
    aliases: [
      'SCB',
      'Standard Chartered',
      'Standard Chartered Bank',
      'Standard Chartered Bank Pakistan',
    ],
  ),
  PakistaniBank(
    name: 'Faysal Bank Limited',
    code: 'FABL',
    category: BankCategory.commercial,
    primaryColor: Color(0xFFC59B27), // Faysal Gold
    accentColor: Color(0xFF0C2340),  // Midnight Navy
    shortMonogram: 'FABL',
    aliases: ['FABL', 'Faysal Bank', 'Faysal'],
  ),
  PakistaniBank(
    name: 'Askari Bank Limited',
    code: 'AKBL',
    category: BankCategory.commercial,
    primaryColor: Color(0xFF1E4D2B), // Askari Spruce Green
    accentColor: Color(0xFFD4AF37),  // Gold
    shortMonogram: 'AKBL',
    aliases: ['AKBL', 'Askari Bank', 'Askari Bank Limited'],
  ),
  PakistaniBank(
    name: 'The Bank of Punjab',
    code: 'BOP',
    category: BankCategory.commercial,
    primaryColor: Color(0xFF00539B), // BOP Blue
    accentColor: Color(0xFFFFC72C),  // Punjab Gold
    shortMonogram: 'BOP',
    aliases: ['BOP', 'Bank of Punjab', 'The Bank of Punjab (BOP)'],
  ),
  PakistaniBank(
    name: 'Bank Al Habib Limited',
    code: 'BAHL',
    category: BankCategory.commercial,
    primaryColor: Color(0xFF005C29), // Al Habib Forest Green
    accentColor: Color(0xFFD4AF37),  // Gold
    shortMonogram: 'BAHL',
    aliases: ['BAHL', 'Bank Al Habib', 'Al Habib'],
  ),
  PakistaniBank(
    name: 'National Bank of Pakistan',
    code: 'NBP',
    category: BankCategory.commercial,
    primaryColor: Color(0xFF00401A), // NBP Sovereign Green
    accentColor: Color(0xFFEAA023),  // Gold
    shortMonogram: 'NBP',
    aliases: ['NBP', 'National Bank'],
  ),
  PakistaniBank(
    name: 'Soneri Bank Limited',
    code: 'SNBL',
    category: BankCategory.commercial,
    primaryColor: Color(0xFFF59E0B), // Soneri Amber Sun
    accentColor: Color(0xFF00205B),  // Navy
    textColor: Color(0xFF00205B),
    shortMonogram: 'SNBL',
    aliases: ['SNBL', 'Soneri Bank', 'Soneri'],
  ),
  PakistaniBank(
    name: 'JS Bank Limited',
    code: 'JSBL',
    category: BankCategory.commercial,
    primaryColor: Color(0xFF00529B), // JS Royal Blue
    accentColor: Color(0xFFF58220),  // Orange
    shortMonogram: 'JSBL',
    aliases: ['JSBL', 'JS Bank', 'JS'],
  ),

  // ===========================================================================
  // Islamic Banking Institutions
  // ===========================================================================
  PakistaniBank(
    name: 'Dubai Islamic Bank Pakistan Limited',
    code: 'DIBPL',
    category: BankCategory.islamic,
    primaryColor: Color(0xFFC5A059), // DIB Sovereign Gold
    accentColor: Color(0xFF1F2937),  // Deep Slate
    textColor: Color(0xFF1F2937),
    shortMonogram: 'DIBPL',
    aliases: ['DIBPL', 'Dubai Islamic Bank', 'Dubai Islamic', 'DIB'],
  ),
  PakistaniBank(
    name: 'BankIslami Pakistan Limited',
    code: 'BIPL',
    category: BankCategory.islamic,
    primaryColor: Color(0xFF004D26), // Islamic Emerald
    accentColor: Colors.white,
    shortMonogram: 'BIPL',
    aliases: ['BIPL', 'BankIslami', 'Bank Islami'],
  ),
  PakistaniBank(
    name: 'MCB Islamic Bank Limited',
    code: 'MCBIB',
    category: BankCategory.islamic,
    primaryColor: Color(0xFFB71C1C), // Ruby
    accentColor: Color(0xFF0C2340),  // Navy
    shortMonogram: 'MCBIB',
    aliases: ['MCBIB', 'MCB Islamic'],
  ),

  // ===========================================================================
  // Specialized, Regional Commercial & Instant Payment Systems
  // ===========================================================================
  PakistaniBank(
    name: 'Habib Metropolitan Bank Limited',
    code: 'HMB',
    category: BankCategory.commercial,
    primaryColor: Color(0xFF007A3D), // Habib Metro Green
    accentColor: Color(0xFFD4AF37),  // Gold
    shortMonogram: 'HMB',
    aliases: ['HMB', 'Habib Metro', 'Habib Metropolitan'],
  ),
  PakistaniBank(
    name: 'The Bank of Khyber',
    code: 'BOK',
    category: BankCategory.commercial,
    primaryColor: Color(0xFF006837), // Khyber Pine Green
    accentColor: Color(0xFF00AEEF),  // Cyan
    shortMonogram: 'BOK',
    aliases: ['BOK', 'Bank of Khyber'],
  ),
  PakistaniBank(
    name: 'Silkbank Limited',
    code: 'SILK',
    category: BankCategory.commercial,
    primaryColor: Color(0xFF7A1315), // Silk Maroon
    accentColor: Colors.white,
    shortMonogram: 'SILK',
    aliases: ['SILK', 'Silk Bank', 'Silkbank'],
  ),
  PakistaniBank(
    name: 'Summit Bank Limited',
    code: 'SMBL',
    category: BankCategory.commercial,
    primaryColor: Color(0xFF8B0000), // Crimson Maroon
    accentColor: Colors.white,
    shortMonogram: 'SMBL',
    aliases: ['SMBL', 'Summit Bank'],
  ),
  PakistaniBank(
    name: 'Raast (SBP Instant Payment System)',
    code: 'RAAST',
    category: BankCategory.fintech,
    primaryColor: Color(0xFF006837), // SBP Sovereign Green
    accentColor: Color(0xFFFFC72C),  // Raast Gold
    shortMonogram: 'RAAST',
    aliases: ['RAAST', 'Raast', 'SBP Raast', 'Raast Instant Payment'],
  ),
  PakistaniBank(
    name: 'Zarai Taraqiati Bank Limited',
    code: 'ZTBL',
    category: BankCategory.specialized,
    primaryColor: Color(0xFF1B5E20), // Agri Green
    accentColor: Color(0xFFF57F17),  // Golden Wheat
    shortMonogram: 'ZTBL',
    aliases: ['ZTBL', 'Zarai Taraqiati Bank', 'ZTBL Bank'],
  ),
  PakistaniBank(
    name: 'SME Bank Limited',
    code: 'SMEBL',
    category: BankCategory.specialized,
    primaryColor: Color(0xFF00695C), // Slate Teal
    accentColor: Colors.white,
    shortMonogram: 'SMEBL',
    aliases: ['SMEBL', 'SME Bank'],
  ),
  PakistaniBank(
    name: 'Sindh Bank Limited',
    code: 'SNDB',
    category: BankCategory.specialized,
    primaryColor: Color(0xFF880E4F), // Ajrak Maroon
    accentColor: Color(0xFFFFD54F),  // Gold
    shortMonogram: 'SNDB',
    aliases: ['SNDB', 'Sindh Bank'],
  ),
  PakistaniBank(
    name: 'Industrial Development Bank of Pakistan',
    code: 'IDBP',
    category: BankCategory.specialized,
    primaryColor: Color(0xFF37474F), // Industrial Steel
    accentColor: Color(0xFF90A4AE),
    shortMonogram: 'IDBP',
    aliases: ['IDBP', 'Industrial Development Bank'],
  ),

  // ===========================================================================
  // Foreign Banks Operating in Pakistan
  // ===========================================================================
  PakistaniBank(
    name: 'Citibank N.A. Pakistan',
    code: 'CITI',
    category: BankCategory.foreign,
    primaryColor: Color(0xFF003B70), // Citi Blue
    accentColor: Color(0xFFEE1C25),  // Citi Red Arc
    shortMonogram: 'CITI',
    aliases: ['CITI', 'Citibank', 'Citibank Pakistan', 'Citibank N.A.'],
  ),
  PakistaniBank(
    name: 'Deutsche Bank AG Pakistan',
    code: 'DB',
    category: BankCategory.foreign,
    primaryColor: Color(0xFF0018A8), // Deutsche Blue
    accentColor: Colors.white,
    shortMonogram: 'DB',
    aliases: ['DB', 'Deutsche Bank', 'Deutsche Bank AG'],
  ),
  PakistaniBank(
    name: 'Industrial and Commercial Bank of China Pakistan',
    code: 'ICBC',
    category: BankCategory.foreign,
    primaryColor: Color(0xFFC7000B), // ICBC Crimson
    accentColor: Colors.white,
    shortMonogram: 'ICBC',
    aliases: ['ICBC', 'ICBC Pakistan', 'Bank of China'],
  ),

  // ===========================================================================
  // Microfinance Institutions
  // ===========================================================================
  PakistaniBank(
    name: 'Khushhali Microfinance Bank',
    code: 'KMBL',
    category: BankCategory.microfinance,
    primaryColor: Color(0xFFE65100), // Khushhali Amber
    accentColor: Color(0xFFFFD54F),
    shortMonogram: 'KMBL',
    aliases: ['KMBL', 'Khushhali Bank', 'Khushhali Microfinance Bank Limited'],
  ),
  PakistaniBank(
    name: 'U Microfinance Bank',
    code: 'UMBL',
    category: BankCategory.microfinance,
    primaryColor: Color(0xFFFF6F00), // Ufone Vivid Orange
    accentColor: Colors.white,
    shortMonogram: 'UMBL',
    aliases: ['UMBL', 'U Bank', 'UPaisa'],
  ),
  PakistaniBank(
    name: 'FINCA Microfinance Bank',
    code: 'FINCA',
    category: BankCategory.microfinance,
    primaryColor: Color(0xFF4A148C), // FINCA Purple
    accentColor: Color(0xFFFFB300),  // Amber
    shortMonogram: 'FINCA',
    aliases: ['FINCA', 'FINCA Bank'],
  ),
  PakistaniBank(
    name: 'NRSP Microfinance Bank',
    code: 'NRSP',
    category: BankCategory.microfinance,
    primaryColor: Color(0xFF2E7D32), // Rural Green
    accentColor: Colors.white,
    shortMonogram: 'NRSP',
    aliases: ['NRSP', 'NRSP Bank'],
  ),
  PakistaniBank(
    name: 'Apna Microfinance Bank',
    code: 'APNA',
    category: BankCategory.microfinance,
    primaryColor: Color(0xFF1565C0), // Blue
    accentColor: Colors.white,
    shortMonogram: 'APNA',
    aliases: ['APNA', 'Apna Bank'],
  ),
  PakistaniBank(
    name: 'Pak Oman Microfinance Bank',
    code: 'POMB',
    category: BankCategory.microfinance,
    primaryColor: Color(0xFFC62828), // Oman Red
    accentColor: Color(0xFF2E7D32),  // Forest Green
    shortMonogram: 'POMB',
    aliases: ['POMB', 'Pak Oman', 'Pak Oman Bank'],
  ),
];

/// Resolves [query] to a catalog entry, preferring exact names and aliases.
///
/// If no entry matches, the first catalog entry is returned as the fallback.
PakistaniBank findPakistaniBank(String query) {
  final clean = query.trim().toLowerCase();
  if (clean.isEmpty) return kAllPakistaniBanks.first;

  // 1. Exact name or code match
  for (final bank in kAllPakistaniBanks) {
    if (bank.name.toLowerCase() == clean ||
        bank.code.toLowerCase() == clean ||
        bank.displayName.toLowerCase() == clean) {
      return bank;
    }
  }

  // 2. Alias match
  for (final bank in kAllPakistaniBanks) {
    for (final alias in bank.aliases) {
      if (alias.toLowerCase() == clean) {
        return bank;
      }
    }
  }

  // 3. Substring match
  for (final bank in kAllPakistaniBanks) {
    if (clean.contains(bank.name.toLowerCase()) ||
        bank.name.toLowerCase().contains(clean) ||
        clean.contains(bank.code.toLowerCase())) {
      return bank;
    }
    for (final alias in bank.aliases) {
      if (clean.contains(alias.toLowerCase()) ||
          alias.toLowerCase().contains(clean)) {
        return bank;
      }
    }
  }

  return kAllPakistaniBanks.first;
}
