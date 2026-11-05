import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../features/profile/domain/pakistan_banks.dart';
import 'bank_logo_widget.dart';
import 'spongy_tap.dart';

/// Interactive modal bottom sheet for browsing and searching all 39 Pakistani banks
/// and digital payment systems with real-time category filtering and authentic logos.
class BankSelectorSheet extends StatefulWidget {
  final String selectedBankName;
  final ValueChanged<PakistaniBank> onBankSelected;

  const BankSelectorSheet({
    super.key,
    required this.selectedBankName,
    required this.onBankSelected,
  });

  /// Displays the bank selector sheet as a modal bottom sheet.
  static Future<PakistaniBank?> show(
    BuildContext context, {
    required String selectedBankName,
  }) {
    PakistaniBank? result;
    return showModalBottomSheet<PakistaniBank>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BankSelectorSheet(
        selectedBankName: selectedBankName,
        onBankSelected: (bank) {
          result = bank;
          Navigator.pop(ctx, bank);
        },
      ),
    ).then((val) => val ?? result);
  }

  @override
  State<BankSelectorSheet> createState() => _BankSelectorSheetState();
}

class _BankSelectorSheetState extends State<BankSelectorSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  BankCategory? _selectedCategory;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PakistaniBank> get _filteredBanks {
    return kAllPakistaniBanks.where((bank) {
      if (_selectedCategory != null && bank.category != _selectedCategory) {
        return false;
      }
      return bank.matches(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBank = findPakistaniBank(widget.selectedBankName);
    final banks = _filteredBanks;

    return Material(
      color: c.card,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border, width: 1.2)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Draggable Pill
            Center(
              child: Container(
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: c.border.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Row: Title & Close Icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Select Bank',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.aqua.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${kAllPakistaniBanks.length} Available',
                            style: TextStyle(
                              color: c.aqua,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 20, color: c.textMuted),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: c.inputFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border, width: 1.1),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _query = val),
                  style: TextStyle(fontSize: 13.5, color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search Pakistani bank or wallet...',
                    hintStyle:
                        TextStyle(color: c.textPlaceholder, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 19, color: c.textMuted),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.cancel_rounded,
                                size: 16, color: c.textMuted),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Category Filter Chips Slider
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildCategoryChip(
                    label: 'All (${kAllPakistaniBanks.length})',
                    isSelected: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                    c: c,
                  ),
                  ...BankCategory.values.map((cat) {
                    final count = kAllPakistaniBanks
                        .where((b) => b.category == cat)
                        .length;
                    return _buildCategoryChip(
                      label: '${cat.label.split(' ').first} ($count)',
                      isSelected: _selectedCategory == cat,
                      onTap: () => setState(() => _selectedCategory = cat),
                      c: c,
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Divider(color: c.border.withValues(alpha: 0.5), height: 1),

            // Bank List View
            Expanded(
              child: banks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 40, color: c.textMuted),
                          const SizedBox(height: 8),
                          Text(
                            'No matching bank or wallet found',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try searching with abbreviation (e.g., ABL, MEBL, HBL)',
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      itemCount: banks.length,
                      separatorBuilder: (_, __) => Divider(
                        color: c.border.withValues(alpha: 0.35),
                        height: 1,
                      ),
                      itemBuilder: (ctx, idx) {
                        final b = banks[idx];
                        final isSelected = b.code == selectedBank.code ||
                            b.name.toLowerCase() ==
                                widget.selectedBankName.toLowerCase() ||
                            b.aliases.any((a) =>
                                a.toLowerCase() ==
                                widget.selectedBankName.toLowerCase());

                        return SpongyTap(
                          onTap: () {
                            widget.onBankSelected(b);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                      ? c.aqua.withValues(alpha: 0.08)
                                      : c.aqua.withValues(alpha: 0.06))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                BankLogoWidget(bank: b, size: 38),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              b.name,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: isSelected
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: isSelected
                                                    ? c.aqua
                                                    : c.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          BankCategoryPill(
                                              category: b.category),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${b.code} • ${b.category.label}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? c.aqua.withValues(alpha: 0.85)
                                              : c.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: c.aqua,
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.check_rounded,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required PaidiXColorScheme c,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: SpongyTap(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? c.aqua.withValues(alpha: 0.18)
                : c.inputFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? c.aqua : c.border,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? c.aqua : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
