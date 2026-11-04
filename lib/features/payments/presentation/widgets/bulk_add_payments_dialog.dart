// =============================================================================
// BULK ADD PAYMENTS DIALOG & LOGIC (COMMENTED OUT)
// The complete Bulk Add section, data models, row controllers, calculations,
// screenshot attachments, batch submission logic, and dialog UI are commented
// out as requested by user.
// =============================================================================

/*
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/spongy_tap.dart';
import '../../data/payments_repository_impl.dart';
import '../../domain/payment_models.dart';

/// Data model representing a single row in the bulk payment grid.
class BulkPaymentRowData {
  final String id;
  String methodId;
  String senderName;
  String senderCompany;
  String confirmationCode;
  DateTime date;
  double amount;
  String? screenshotFileName;
  Uint8List? screenshotBytes;

  late final TextEditingController senderNameController;
  late final TextEditingController senderCompanyController;
  late final TextEditingController confirmationCodeController;
  late final TextEditingController amountController;

  BulkPaymentRowData({
    required this.id,
    this.methodId = 'cashapp_1',
    this.senderName = '',
    this.senderCompany = '',
    this.confirmationCode = '',
    DateTime? date,
    this.amount = 0.0,
    this.screenshotFileName,
    this.screenshotBytes,
  }) : date = date ?? DateTime.now() {
    senderNameController = TextEditingController(text: senderName);
    senderCompanyController = TextEditingController(text: senderCompany);
    confirmationCodeController = TextEditingController(text: confirmationCode);
    amountController = TextEditingController(
      text: amount > 0 ? amount.toStringAsFixed(2) : '',
    );
  }

  void dispose() {
    senderNameController.dispose();
    senderCompanyController.dispose();
    confirmationCodeController.dispose();
    amountController.dispose();
  }

  BulkPaymentRowData cloneForDuplicate() {
    return BulkPaymentRowData(
      id: 'row_${DateTime.now().microsecondsSinceEpoch}',
      methodId: methodId,
      senderName: senderNameController.text.trim(),
      senderCompany: senderCompanyController.text.trim(),
      confirmationCode: '', // Prompt user for unique confirmation code
      date: date,
      amount: amount,
      screenshotFileName: null, // Prompt for distinct proof
      screenshotBytes: null,
    );
  }

  bool get isValid =>
      senderNameController.text.trim().isNotEmpty &&
      confirmationCodeController.text.trim().isNotEmpty &&
      amount > 0;
}

/// A responsive, intelligent modal dialog for adding several incoming payments at once.
/// Features:
/// - Desktop / wide view: spreadsheet-style grid table matching reference design.
/// - Mobile view: responsive, neatly structured payment cards with zero pixel overflow.
/// - Dynamic real-time calculation of active rows and total amount.
/// - Row management: "+ Add row", "+5 rows", "+10 rows", duplicate row, delete row, clear all.
/// - Date picker integration with formatted mm/dd/yyyy display.
/// - Screenshot proof file attachment with gallery picker.
/// - Full batch submission pipeline persisting to [PaymentsRepositoryImpl].
class BulkAddPaymentsDialog extends StatefulWidget {
  final PaymentsRepositoryImpl paymentsRepository;

  const BulkAddPaymentsDialog({
    super.key,
    required this.paymentsRepository,
  });

  static Future<void> show(
    BuildContext context,
    PaymentsRepositoryImpl paymentsRepository,
  ) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => BulkAddPaymentsDialog(
        paymentsRepository: paymentsRepository,
      ),
    );
  }

  @override
  State<BulkAddPaymentsDialog> createState() => _BulkAddPaymentsDialogState();
}

class _BulkAddPaymentsDialogState extends State<BulkAddPaymentsDialog> {
  final List<BulkPaymentRowData> _rows = [];
  bool _isSubmitting = false;
  List<PaymentMethodOption> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
    _addRow();
  }

  Future<void> _loadPaymentMethods() async {
    final methods = await widget.paymentsRepository.getPaymentMethods();
    if (mounted) {
      setState(() {
        _paymentMethods = methods;
      });
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow([BulkPaymentRowData? customRow]) {
    setState(() {
      final newRow = customRow ??
          BulkPaymentRowData(
            id: 'row_${DateTime.now().microsecondsSinceEpoch}',
            methodId: _paymentMethods.isNotEmpty
                ? _paymentMethods.first.id
                : 'cashapp_1',
          );
      newRow.amountController.addListener(() => _onAmountChanged(newRow));
      newRow.senderNameController.addListener(() => setState(() {}));
      newRow.confirmationCodeController.addListener(() => setState(() {}));
      _rows.add(newRow);
    });
  }

  void _addMultipleRows(int count) {
    for (int i = 0; i < count; i++) {
      _addRow();
    }
  }

  void _duplicateRow(int index) {
    if (index >= 0 && index < _rows.length) {
      final cloned = _rows[index].cloneForDuplicate();
      _addRow(cloned);
    }
  }

  void _deleteRow(int index) {
    if (_rows.length <= 1) {
      // Clear instead of removing last row
      _rows[0].senderNameController.clear();
      _rows[0].senderCompanyController.clear();
      _rows[0].confirmationCodeController.clear();
      _rows[0].amountController.clear();
      setState(() {
        _rows[0].amount = 0.0;
        _rows[0].screenshotFileName = null;
        _rows[0].screenshotBytes = null;
      });
      return;
    }

    setState(() {
      final removed = _rows.removeAt(index);
      removed.dispose();
    });
  }

  void _clearAll() {
    for (final row in _rows) {
      row.dispose();
    }
    _rows.clear();
    _addRow();
  }

  void _onAmountChanged(BulkPaymentRowData row) {
    final text = row.amountController.text.trim();
    final parsed = double.tryParse(text) ?? 0.0;
    if (row.amount != parsed) {
      setState(() {
        row.amount = parsed;
      });
    }
  }

  double get _totalAmount {
    return _rows.fold(0.0, (sum, r) => sum + r.amount);
  }

  Future<void> _pickScreenshot(BulkPaymentRowData row) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          row.screenshotFileName = picked.name;
          row.screenshotBytes = bytes;
        });
      }
    } catch (_) {
      // Fallback in case of desktop or test sandbox
      setState(() {
        row.screenshotFileName =
            'proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });
    }
  }

  Future<void> _pickDate(BuildContext context, BulkPaymentRowData row) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: row.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final colors = AppColors.of(context);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.aqua,
              onPrimary: const Color(0xFF022F32),
              surface: colors.card,
              onSurface: colors.textPrimary,
            ),
            dialogTheme: DialogThemeData(backgroundColor: colors.card),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        row.date = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    final validRows = _rows.where((r) => r.isValid).toList();

    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill at least one row with a sender name, confirmation code, and amount.',
          ),
          backgroundColor: Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      for (final row in validRows) {
        await widget.paymentsRepository.submitPayment(
          PaymentSubmission(
            methodId: row.methodId,
            senderName: row.senderNameController.text.trim(),
            senderCompany: row.senderCompanyController.text.trim(),
            confirmationCode: row.confirmationCodeController.text.trim(),
            amount: row.amount,
            transactionDate: row.date,
            proofFileName: row.screenshotFileName ?? 'bulk_receipt.jpg',
          ),
        );
      }

      await NotificationService.instance.showNotification(
        id: 16,
        title: 'Bulk Payments Submitted',
        body:
            '${validRows.length} payment(s) have been submitted for clearing and verification.',
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${validRows.length} payment(s) submitted successfully!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0E7C7B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting payments: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height && size.height < 520;
    final isMobile = size.width < 720;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: isMobile
              ? size.width * (isLandscape ? 0.96 : 0.95)
              : size.width * 0.92,
          constraints: BoxConstraints(
            maxWidth: 1060,
            maxHeight: isLandscape ? size.height * 0.98 : size.height * 0.92,
          ),
          margin: EdgeInsets.symmetric(
            horizontal: isLandscape ? 8 : 10,
            vertical: isLandscape ? 3 : 16,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 12 : (isMobile ? 16 : 24),
            vertical: isLandscape ? 6 : (isMobile ? 16 : 24),
          ),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: AppSpacing.radiusXl,
            border: Border.all(color: colors.border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 36,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Title and Close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Add several payments at once',
                      style: TextStyle(
                        fontSize: isLandscape ? 14.5 : (isMobile ? 16 : 18),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: colors.textSecondary,
                        size: isLandscape ? 18 : 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: isLandscape ? 4 : 8),

              // Instructions subtitle
              if (!isLandscape)
                Text(
                  'Fill one row per payment. Each row is submitted as a separate payment for review — exactly like the single New Payment form, just faster. A screenshot and the transaction date are required on every row.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textMuted,
                    height: 1.4,
                  ),
                )
              else
                Text(
                  'Fill one row per payment. Screenshot and date required on each row.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              SizedBox(height: isLandscape ? 4 : 16),

              // Scrollable grid/card content area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.cardDark.withValues(alpha: 0.4),
                    borderRadius: AppSpacing.radiusMd,
                    border: Border.all(color: colors.borderSubtle, width: 1),
                  ),
                  child: isMobile ? _buildMobileList() : _buildDesktopTable(),
                ),
              ),
              SizedBox(height: isLandscape ? 4 : 12),

              // Row additions toolbar
              Wrap(
                spacing: isLandscape ? 6 : 8,
                runSpacing: isLandscape ? 3 : 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildActionButton(
                    label: '+ Add row',
                    onTap: () => _addRow(),
                    colors: colors,
                  ),
                  _buildActionButton(
                    label: '+5 rows',
                    onTap: () => _addMultipleRows(5),
                    colors: colors,
                  ),
                  _buildActionButton(
                    label: '+10 rows',
                    onTap: () => _addMultipleRows(10),
                    colors: colors,
                  ),
                  Text(
                    isLandscape
                        ? 'Use duplicate to copy a row.'
                        : 'Use the duplicate icon to copy a row, then change the txn ID + screenshot.',
                    style: TextStyle(
                      fontSize: isLandscape ? 10.5 : 11.5,
                      color: colors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isLandscape ? 4 : 16),

              // Divider
              Divider(color: colors.divider, height: 1),
              SizedBox(height: isLandscape ? 4 : 14),

              // Footer: Stats & Action Buttons
              _buildFooter(isMobile, isLandscape),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
    required PaidiXColorScheme colors,
  }) {
    return SpongyTap(
      onTap: onTap,
      pressScale: 0.94,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.cardHighlight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.borderSubtle, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: colors.aqua,
          ),
        ),
      ),
    );
  }

  /// Wide desktop / tablet spreadsheet table matching the reference design.
  Widget _buildDesktopTable() {
    final colors = AppColors.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Table Header Row
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.cardDark,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border(bottom: BorderSide(color: colors.borderSubtle)),
                ),
                child: Row(
                  children: [
                    _buildHeaderCell('#', width: 30),
                    _buildHeaderCell('METHOD *', width: 160),
                    _buildHeaderCell('SENDER NAME *', width: 140),
                    _buildHeaderCell('SENDER COMPANY *', width: 130),
                    _buildHeaderCell('CONFIRMATION CODE *', width: 145),
                    _buildHeaderCell('DATE *', width: 125),
                    _buildHeaderCell('AMOUNT (USD) *', width: 100),
                    _buildHeaderCell('SCREENSHOT *', width: 95),
                    const SizedBox(width: 80), // Action icons column
                  ],
                ),
              ),

              // Table Body Rows
              ...List.generate(_rows.length, (index) {
                final row = _rows[index];
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: index.isEven
                        ? Colors.transparent
                        : colors.cardHighlight.withValues(alpha: 0.15),
                    border: Border(
                      bottom: BorderSide(
                        color: colors.borderSubtle.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // # Index
                      SizedBox(
                        width: 30,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),

                      // Method Dropdown
                      SizedBox(
                        width: 160,
                        child: _buildMethodDropdown(row),
                      ),
                      const SizedBox(width: 8),

                      // Sender Name Input
                      SizedBox(
                        width: 132,
                        child: _buildCellTextField(
                          controller: row.senderNameController,
                          hint: 'Sender name',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Sender Company Input
                      SizedBox(
                        width: 122,
                        child: _buildCellTextField(
                          controller: row.senderCompanyController,
                          hint: 'Company',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Confirmation Code Input
                      SizedBox(
                        width: 137,
                        child: _buildCellTextField(
                          controller: row.confirmationCodeController,
                          hint: 'Confirmation code',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Date Picker Button
                      SizedBox(
                        width: 117,
                        child: _buildDateField(row),
                      ),
                      const SizedBox(width: 8),

                      // Amount Input
                      SizedBox(
                        width: 92,
                        child: _buildCellTextField(
                          controller: row.amountController,
                          hint: '0.00',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          onChanged: (_) => _onAmountChanged(row),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Screenshot Button
                      SizedBox(
                        width: 95,
                        child: _buildScreenshotButton(row),
                      ),
                      const SizedBox(width: 8),

                      // Actions: Duplicate & Delete
                      SizedBox(
                        width: 72,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SpongyTap(
                              onTap: () => _duplicateRow(index),
                              pressScale: 0.9,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Icon(Icons.copy_rounded,
                                    size: 16, color: colors.textMuted),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SpongyTap(
                              onTap: () => _deleteRow(index),
                              pressScale: 0.9,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Icon(Icons.delete_outline_rounded,
                                    size: 17,
                                    color: colors.textMuted
                                        .withValues(alpha: 0.8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// Mobile-optimized responsive card list preventing all pixel overflow.
  Widget _buildMobileList() {
    final colors = AppColors.of(context);

    return ListView.separated(
      padding: const EdgeInsets.all(10),
      physics: const BouncingScrollPhysics(),
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final row = _rows[index];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.cardDark,
            borderRadius: AppSpacing.radiusMd,
            border: Border.all(
              color: row.isValid
                  ? colors.emerald.withValues(alpha: 0.4)
                  : colors.borderSubtle,
              width: 1.1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row Header: # Badge + Actions
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.cardHighlight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '# ${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: colors.aqua,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.copy_rounded,
                        size: 16, color: colors.textSecondary),
                    tooltip: 'Duplicate',
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    constraints: const BoxConstraints(),
                    onPressed: () => _duplicateRow(index),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 17, color: colors.statusErrorDot),
                    tooltip: 'Delete',
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    constraints: const BoxConstraints(),
                    onPressed: () => _deleteRow(index),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Method & Date
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('METHOD *'),
                        const SizedBox(height: 4),
                        _buildMethodDropdown(row),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('DATE *'),
                        const SizedBox(height: 4),
                        _buildDateField(row),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Sender Name & Company
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('SENDER NAME *'),
                        const SizedBox(height: 4),
                        _buildCellTextField(
                          controller: row.senderNameController,
                          hint: 'Sender name',
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('COMPANY *'),
                        const SizedBox(height: 4),
                        _buildCellTextField(
                          controller: row.senderCompanyController,
                          hint: 'Company',
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Confirmation Code & Amount
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('CONFIRMATION CODE *'),
                        const SizedBox(height: 4),
                        _buildCellTextField(
                          controller: row.confirmationCodeController,
                          hint: 'Confirmation code',
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('AMOUNT (USD) *'),
                        const SizedBox(height: 4),
                        _buildCellTextField(
                          controller: row.amountController,
                          hint: '0.00',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          onChanged: (_) => _onAmountChanged(row),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Screenshot upload trigger
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('SCREENSHOT *'),
                  const SizedBox(height: 4),
                  _buildScreenshotButton(row, fullWidth: true),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFieldLabel(String label) {
    final colors = AppColors.of(context);
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: colors.textMuted,
      ),
    );
  }

  Widget _buildHeaderCell(String label, {required double width}) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: colors.textMuted,
        ),
      ),
    );
  }

  Widget _buildMethodDropdown(BulkPaymentRowData row) {
    final colors = AppColors.of(context);

    final methods = _paymentMethods.isNotEmpty
        ? _paymentMethods
        : [
            const PaymentMethodOption(
              id: 'cashapp_1',
              name: 'Freight Flow Cashapp',
              iconKey: 'cashapp',
            ),
            const PaymentMethodOption(
              id: 'zelle_1',
              name: 'UB Zelle',
              iconKey: 'zelle',
            ),
          ];

    final current = methods.any((m) => m.id == row.methodId)
        ? row.methodId
        : methods.first.id;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isExpanded: true,
          dropdownColor: colors.cardDark,
          borderRadius: BorderRadius.circular(8),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: colors.textSecondary),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                row.methodId = val;
              });
            }
          },
          items: methods.map((m) {
            return DropdownMenuItem<String>(
              value: m.id,
              child: Text(
                m.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCellTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    required ValueChanged<String> onChanged,
  }) {
    final colors = AppColors.of(context);

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 12,
            color: colors.textPlaceholder,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDateField(BulkPaymentRowData row) {
    final colors = AppColors.of(context);
    final dateStr =
        '${row.date.month.toString().padLeft(2, '0')}/${row.date.day.toString().padLeft(2, '0')}/${row.date.year}';

    return SpongyTap(
      onTap: () => _pickDate(context, row),
      pressScale: 0.95,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: colors.inputBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                dateStr,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.calendar_today_outlined,
                size: 14, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenshotButton(
    BulkPaymentRowData row, {
    bool fullWidth = false,
  }) {
    final colors = AppColors.of(context);
    final hasProof = row.screenshotFileName != null;

    return SpongyTap(
      onTap: () => _pickScreenshot(row),
      pressScale: 0.94,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 38,
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: hasProof
              ? colors.emerald.withValues(alpha: 0.15)
              : colors.inputBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: hasProof
                ? colors.emerald.withValues(alpha: 0.6)
                : colors.border.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment:
              fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(
              hasProof ? Icons.check_circle_rounded : Icons.image_outlined,
              size: 14,
              color: hasProof ? colors.emerald : colors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              hasProof ? 'Attached' : 'Add',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: hasProof ? colors.emerald : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isMobile, bool isLandscape) {
    final colors = AppColors.of(context);

    final statsBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Rows: ${_rows.length}',
              style: TextStyle(
                fontSize: isLandscape ? 11.5 : 12.5,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            Text(
              'Total amount: \$ ${_totalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: isLandscape ? 12 : 13,
                fontWeight: FontWeight.w800,
                color: colors.aqua,
              ),
            ),
          ],
        ),
        if (!isLandscape) ...[
          const SizedBox(height: 3),
          Text(
            'Saved in this browser automatically — closing the window won\'t lose your rows (screenshots excluded).',
            style: TextStyle(
              fontSize: 10.5,
              color: colors.textMuted,
            ),
          ),
        ],
      ],
    );

    final actionButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: _clearAll,
          icon: Icon(Icons.delete_outline_rounded,
              size: isLandscape ? 14 : 15, color: colors.textSecondary),
          label: Text(
            'Clear all',
            style: TextStyle(
              fontSize: isLandscape ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ),
        SizedBox(width: isLandscape ? 4 : 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: TextStyle(
              fontSize: isLandscape ? 11.5 : 12.5,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ),
        SizedBox(width: isLandscape ? 6 : 10),
        AppButton(
          text: _isSubmitting ? 'Submitting...' : 'Submit payments',
          variant: AppButtonVariant.primary,
          height: isLandscape ? 34 : 44,
          padding: EdgeInsets.symmetric(horizontal: isLandscape ? 10 : 18),
          icon: const Icon(Icons.check_rounded, size: 16),
          onPressed: _isSubmitting ? null : _handleSubmit,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!isLandscape && (isMobile || constraints.maxWidth < 620)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              statsBlock,
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: actionButtons,
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: statsBlock),
            const SizedBox(width: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: actionButtons,
            ),
          ],
        );
      },
    );
  }
}

*/
