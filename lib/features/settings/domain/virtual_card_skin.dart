import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Luxury metallic and holographic finishes for the PaidiX virtual receiving card.
enum VirtualCardSkin {
  emeraldObsidian(
    id: 'emerald_obsidian',
    name: 'Emerald Obsidian',
    tag: 'SIGNATURE METALLIC',
    description: 'Deep midnight teal with metallic emerald matrix & gold foil PX insignia.',
    gradientColors: [
      Color(0xFF042B28),
      Color(0xFF011A18),
      Color(0xFF004D40),
      Color(0xFF021715),
    ],
    accentColor: Color(0xFF00E5BC),
    foilColor: Color(0xFFFFD54F),
    chipColor: Color(0xFFFFD54F),
    isHolographic: false,
  ),
  prismaticHologram(
    id: 'prismatic_hologram',
    name: 'Prismatic Hologram',
    tag: 'CYBER IRIDESCENT',
    description: 'Dynamic spectral light dispersion with pearlescent rainbow reflection.',
    gradientColors: [
      Color(0xFF1E1B4B),
      Color(0xFF312E81),
      Color(0xFF0E7490),
      Color(0xFF155E75),
      Color(0xFF4C1D95),
    ],
    accentColor: Color(0xFF38BDF8),
    foilColor: Color(0xFFF472B6),
    chipColor: Color(0xFFE2E8F0),
    isHolographic: true,
  ),
  champagneGold(
    id: 'champagne_gold',
    name: 'Champagne Gold',
    tag: '24K PRIVATE BANKING',
    description: 'Brushed luxury champagne gold with warm amber rim and debossed crest.',
    gradientColors: [
      Color(0xFF423208),
      Color(0xFF241B03),
      Color(0xFF5E460D),
      Color(0xFF281E04),
    ],
    accentColor: Color(0xFFFFE082),
    foilColor: Color(0xFFFFD700),
    chipColor: Color(0xFFFFD700),
    isHolographic: false,
  ),
  stealthCarbon(
    id: 'stealth_carbon',
    name: 'Stealth Carbon',
    tag: 'AEROSPACE COMPOSITE',
    description: 'Matte carbon-fiber weave with high-contrast electric cyan laser edges.',
    gradientColors: [
      Color(0xFF0F172A),
      Color(0xFF090D16),
      Color(0xFF1E293B),
      Color(0xFF0B1120),
    ],
    accentColor: Color(0xFF06B6D4),
    foilColor: Color(0xFF94A3B8),
    chipColor: Color(0xFFCBD5E1),
    isHolographic: false,
  );

  final String id;
  final String name;
  final String tag;
  final String description;
  final List<Color> gradientColors;
  final Color accentColor;
  final Color foilColor;
  final Color chipColor;
  final bool isHolographic;

  const VirtualCardSkin({
    required this.id,
    required this.name,
    required this.tag,
    required this.description,
    required this.gradientColors,
    required this.accentColor,
    required this.foilColor,
    required this.chipColor,
    required this.isHolographic,
  });

  static VirtualCardSkin fromId(String? id) {
    if (id == null) return VirtualCardSkin.emeraldObsidian;
    return VirtualCardSkin.values.firstWhere(
      (s) => s.id == id,
      orElse: () => VirtualCardSkin.emeraldObsidian,
    );
  }
}

/// Reactive state manager and persistent storage for PaidiX Virtual Card Studio.
class VirtualCardPreferences {
  VirtualCardPreferences._();
  static final VirtualCardPreferences instance = VirtualCardPreferences._();

  static final ValueNotifier<VirtualCardSkin> activeSkinNotifier =
      ValueNotifier<VirtualCardSkin>(VirtualCardSkin.emeraldObsidian);

  static final ValueNotifier<bool> isDetailsMaskedNotifier =
      ValueNotifier<bool>(true);

  static VirtualCardSkin get currentSkin => activeSkinNotifier.value;
  static bool get isDetailsMasked => isDetailsMaskedNotifier.value;

  static bool _isInitialized = false;

  /// Load persisted card preferences from local app storage.
  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      final file = await _getPrefsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);
        if (data.containsKey('skin_id')) {
          activeSkinNotifier.value =
              VirtualCardSkin.fromId(data['skin_id'] as String?);
        }
        if (data.containsKey('is_masked')) {
          isDetailsMaskedNotifier.value = data['is_masked'] as bool? ?? true;
        }
      }
    } catch (_) {
      // Fallback silently to defaults
    }
  }

  /// Change active skin with persistent saving and haptics.
  static void setSkin(VirtualCardSkin skin) {
    if (activeSkinNotifier.value == skin) return;
    HapticFeedback.selectionClick();
    activeSkinNotifier.value = skin;
    _persist();
  }

  /// Toggle number masking (•••• 2786 vs 4214 8890 1532 2786) with haptics.
  static void toggleMaskDetails() {
    HapticFeedback.lightImpact();
    isDetailsMaskedNotifier.value = !isDetailsMaskedNotifier.value;
    _persist();
  }

  /// Reset card settings to default.
  static void resetToDefault() {
    activeSkinNotifier.value = VirtualCardSkin.emeraldObsidian;
    isDetailsMaskedNotifier.value = true;
    _persist();
  }

  static Future<File> _getPrefsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/paidix_virtual_card_prefs.json');
  }

  static Future<void> _persist() async {
    try {
      final file = await _getPrefsFile();
      final data = {
        'skin_id': activeSkinNotifier.value.id,
        'is_masked': isDetailsMaskedNotifier.value,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // Ignore write failures in test or sandboxed environments
    }
  }
}
