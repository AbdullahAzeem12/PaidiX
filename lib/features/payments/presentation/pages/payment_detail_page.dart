/// Server-backed detail and status timeline for one customer payment.

import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/paidix_toast.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/payments_repository_impl.dart';
import '../../domain/payment_models.dart';

class PaymentDetailPage extends StatefulWidget {
  final PaymentsRepositoryImpl paymentsRepository;
  final String paymentId;
  final PaymentItem? initialPayment;

  const PaymentDetailPage({
    super.key,
    required this.paymentsRepository,
    required this.paymentId,
    this.initialPayment,
  });

  @override
  State<PaymentDetailPage> createState() => _PaymentDetailPageState();
}

class _PaymentDetailPageState extends State<PaymentDetailPage>
    with WidgetsBindingObserver {
  late PaymentItem? _payment;
  Timer? _refreshTimer;
  bool _loading = false;
  bool _refreshing = false;
  bool _confirming = false;
  bool _requestInFlight = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _payment = widget.initialPayment;
    unawaited(_loadDetails());
    _startPolling();
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    if (!AppConfig.hasCustomBackend) return;
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_loadDetails());
    });
  }

  void _stopPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      unawaited(_loadDetails());
    } else {
      _stopPolling();
    }
  }

  Future<void> _loadDetails({bool showError = false}) async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    if (_payment == null && mounted) setState(() => _loading = true);
    try {
      final latest = await widget.paymentsRepository.getPaymentDetails(
        widget.paymentId,
      );
      if (mounted) {
        setState(() {
          _payment = latest;
          _loadFailed = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          if (_payment == null) _loadFailed = true;
        });
        if (showError) {
          PaidiXToast.showError(context, _errorMessage(error));
        }
      }
    } finally {
      _requestInFlight = false;
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (_requestInFlight) return;
    setState(() => _refreshing = true);
    await _loadDetails(showError: true);
  }

  String _errorMessage(Object error) {
    final text = '$error'.replaceFirst('Exception: ', '').trim();
    return text.isEmpty
        ? 'Could not load this payment. Please try again.'
        : text;
  }

  Future<void> _confirmReceipt() async {
    final noteController = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final colors = AppColors.of(dialogContext);
        final width = MediaQuery.sizeOf(dialogContext).width;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusXl),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * .86,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(width < 380 ? 18 : 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirm PKR received',
                    style: TextStyle(
                      fontFamily: AppTheme.activeFontFamily,
                      color: colors.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Confirm only after the transfer reaches your bank account. '
                    'This closes the payment.',
                    style: TextStyle(color: colors.textSecondary, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: noteController,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      hintText: 'Add a note for the payment record',
                      filled: true,
                      fillColor: colors.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: AppSpacing.radiusMd,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Cancel'),
                      ),
                      AppButton(
                        text: 'Confirm receipt',
                        icon: const Icon(Icons.check_rounded, size: 18),
                        onPressed: () =>
                            Navigator.of(dialogContext)
                                .pop(noteController.text.trim()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    noteController.dispose();
    if (note == null || !mounted) return;

    setState(() => _confirming = true);
    try {
      final latest = await widget.paymentsRepository.confirmCustomerReceipt(
        widget.paymentId,
        note: note,
      );
      if (!mounted) return;
      setState(() => _payment = latest);
      PaidiXToast.showSuccess(context, 'Thanks! Payment status is updated.');
    } catch (error) {
      if (mounted) PaidiXToast.showError(context, _errorMessage(error));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final payment = _payment;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.aqua,
          backgroundColor: colors.card,
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: payment == null
                    ? _buildLoadingOrError(colors)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(context, payment, colors),
                          const SizedBox(height: 22),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final main = _buildMainContent(
                                context,
                                payment,
                                colors,
                              );
                              final progress = _buildProgress(payment, colors);
                              if (constraints.maxWidth < 900) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ...main,
                                    const SizedBox(height: 16),
                                    progress,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: main,
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(flex: 3, child: progress),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOrError(PaidiXColorScheme colors) {
    final failed = _loadFailed && !_loading;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600, minHeight: 400),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: _cardDecoration(colors),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                failed ? Icons.cloud_off_outlined : Icons.receipt_long_rounded,
                size: 42,
                color: failed ? colors.statusErrorText : colors.aqua,
              ),
              const SizedBox(height: 16),
              Text(
                failed ? 'Payment details unavailable' : 'Loading payment',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                failed
                    ? 'We could not retrieve this payment from the server.'
                    : 'Getting the latest payment information from the server.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 18),
              if (failed)
                AppButton(
                  text: 'Try again',
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: () => _loadDetails(showError: true),
                )
              else
                CircularProgressIndicator(color: colors.aqua),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    PaymentItem payment,
    PaidiXColorScheme colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/app/payments');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('All payments'),
          style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final headline = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.reference,
                  style: AppTypography.sectionEyebrow.copyWith(
                    color: colors.gold,
                    letterSpacing: 1.7,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatMoney(payment.amount, payment.currencyCode)} from ${payment.sender.isEmpty ? 'Sender' : payment.sender}',
                  style: TextStyle(
                    fontFamily: AppTheme.activeFontFamily,
                    fontSize: constraints.maxWidth < 500 ? 25 : 32,
                    height: 1.15,
                    letterSpacing: -0.6,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const SizedBox(height: 4),
                Text(
                  'Payment date ${AppFormatters.formatDate(payment.transactionDate)}',
                  style: TextStyle(color: colors.textSecondary, height: 1.4),
                ),
                Text(
                  'Submitted ${AppFormatters.formatDateTime(payment.submittedDate)}',
                  style: TextStyle(color: colors.textSecondary, height: 1.4),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBadge(status: payment.status),
                if (payment.autoVerified)
                  _InfoPill(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Auto verified',
                    colors: colors,
                  ),
                OutlinedButton.icon(
                  onPressed: _refreshing ? null : _refresh,
                  icon: _refreshing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.aqua,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            );
            if (constraints.maxWidth < 840) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [headline, const SizedBox(height: 14), actions],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: headline),
                const SizedBox(width: 16),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: actions,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildMainContent(
    BuildContext context,
    PaymentItem payment,
    PaidiXColorScheme colors,
  ) {
    final children = <Widget>[];
    if (payment.status == PaymentStatusType.pkrSent ||
        payment.status == PaymentStatusType.awaitingPkr) {
      children.add(_buildPkrNotice(colors));
      children.add(const SizedBox(height: 16));
    }
    if (payment.status == PaymentStatusType.rejected ||
        payment.status == PaymentStatusType.onHold) {
      final note =
          _latestNote(payment) ??
          payment.verifiedNote ??
          payment.accountantNotes;
      children.add(_buildStatusNote(payment, note, colors));
      children.add(const SizedBox(height: 16));
    }

    children.add(_buildBreakdown(payment, colors));
    children.add(const SizedBox(height: 16));
    children.add(_buildSender(payment, colors));
    if (_hasProof(payment)) {
      children.add(const SizedBox(height: 16));
      children.add(_buildProof(payment, colors));
    }
    if (payment.verifiedDocumentUrl != null ||
        payment.accountantDocumentUrl != null) {
      children.add(const SizedBox(height: 16));
      children.add(_buildTeamDocuments(payment, colors));
    }
    if (_hasTransferInfo(payment)) {
      children.add(const SizedBox(height: 16));
      children.add(_buildTransfer(payment, colors));
    }
    return children;
  }

  Widget _buildPkrNotice(PaidiXColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.cardHighlight,
        borderRadius: AppSpacing.radiusLg,
        border: Border.all(color: colors.aqua.withValues(alpha: .32)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PKR has been sent',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Check your bank account. Confirm after the funds arrive to close this payment.',
                style: TextStyle(color: colors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 14),
              AppButton(
                text: _confirming ? 'Updating...' : 'I received my PKR',
                icon: _confirming
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                onPressed: _confirming ? null : _confirmReceipt,
              ),
            ],
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.account_balance_rounded, color: colors.aqua, size: 23),
              const SizedBox(width: 12),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusNote(
    PaymentItem payment,
    String? note,
    PaidiXColorScheme colors,
  ) {
    final isRejected = payment.status == PaymentStatusType.rejected;
    final accent = isRejected
        ? colors.statusErrorText
        : colors.statusPendingText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: (isRejected ? colors.statusErrorBg : colors.statusPendingBg)
            .withValues(
              alpha: colors.brightness == Brightness.dark ? .32 : .75,
            ),
        borderRadius: AppSpacing.radiusLg,
        border: Border.all(color: accent.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRejected
                ? Icons.error_outline_rounded
                : Icons.pause_circle_outline,
            color: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRejected ? 'Payment rejected' : 'Payment on hold',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    note,
                    style: TextStyle(color: colors.textSecondary, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdown(PaymentItem payment, PaidiXColorScheme colors) {
    return _SectionCard(
      title: 'Breakdown',
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 470 ? 1 : 2;
              return _ResponsiveFields(
                columns: columns,
                children: [
                  _DetailField(
                    label: 'Amount received',
                    value: _formatMoney(payment.amount, payment.currencyCode),
                    prominent: true,
                    colors: colors,
                  ),
                  _DetailField(
                    label: 'Exchange rate',
                    value: payment.exchangeRate > 0
                        ? '1 ${payment.currencyCode} = ${payment.exchangeRate.toStringAsFixed(6)} PKR'
                        : 'Pending',
                    colors: colors,
                  ),
                  _DetailField(
                    label: 'Service fee',
                    value: payment.feePercentage == null
                        ? 'Pending'
                        : '${AppFormatters.formatPercentage(payment.feePercentage)} = ${_formatMoney(payment.feeAmount, payment.currencyCode)}',
                    colors: colors,
                  ),
                  _DetailField(
                    label: 'Net in foreign currency',
                    value: payment.netAmountForeign == null
                        ? 'Pending'
                        : _formatMoney(
                            payment.netAmountForeign,
                            payment.currencyCode,
                          ),
                    colors: colors,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Divider(color: colors.divider, height: 1),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final value = payment.netPkr > 0
                  ? AppFormatters.formatPkr(payment.netPkr)
                  : 'Pending calculation';
              final headline = Text(
                value,
                style: TextStyle(
                  fontFamily: AppTheme.activeFontFamily,
                  color: payment.netPkr > 0
                      ? colors.textPrimary
                      : colors.textMuted,
                  fontSize: constraints.maxWidth < 420 ? 27 : 38,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOU RECEIVE', style: _labelStyle(colors)),
                  const SizedBox(height: 5),
                  headline,
                  if (payment.netPkr > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Net PKR to your bank',
                      style: TextStyle(color: colors.aquaDark, fontSize: 13),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSender(PaymentItem payment, PaidiXColorScheme colors) {
    return _SectionCard(
      title: 'Sender',
      colors: colors,
      child: LayoutBuilder(
        builder: (context, constraints) => _ResponsiveFields(
          columns: constraints.maxWidth < 480 ? 1 : 2,
          children: [
            _DetailField(
              label: 'Name',
              value: _display(payment.sender),
              colors: colors,
            ),
            _DetailField(
              label: 'Company',
              value: _display(payment.senderCompany),
              colors: colors,
            ),
            _DetailField(
              label: 'Payment method',
              value: _display(
                payment.paymentMethodLabel ?? payment.paymentMethodCode,
              ),
              colors: colors,
            ),
            _DetailField(
              label: 'Confirmation code',
              value: _display(payment.externalTransactionId),
              colors: colors,
              mono: true,
            ),
            _DetailField(
              label: 'Transaction date',
              value: AppFormatters.formatDate(payment.transactionDate),
              colors: colors,
            ),
            _DetailField(
              label: 'Submitted',
              value: AppFormatters.formatDateTime(payment.submittedDate),
              colors: colors,
            ),
          ],
        ),
      ),
    );
  }

  bool _hasProof(PaymentItem payment) =>
      payment.screenshotTransactionUrl != null ||
      payment.screenshotEmailUrl != null ||
      payment.proofBytes != null ||
      (payment.proofFilePath?.startsWith('http') ?? false);

  Widget _buildProof(PaymentItem payment, PaidiXColorScheme colors) {
    final transactionUrl =
        payment.screenshotTransactionUrl ??
        ((payment.proofFilePath?.startsWith('http') ?? false)
            ? payment.proofFilePath
            : null);
    return _SectionCard(
      title: 'Your proof',
      colors: colors,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 480 ? 1 : 2;
          final tiles = <Widget>[];
          if (transactionUrl != null || payment.proofBytes != null) {
            tiles.add(
              _ProofTile(
                label: 'Transaction screenshot',
                url: transactionUrl,
                bytes: payment.proofBytes,
                colors: colors,
              ),
            );
          }
          if (payment.screenshotEmailUrl != null) {
            tiles.add(
              _ProofTile(
                label: 'Email screenshot',
                url: payment.screenshotEmailUrl,
                colors: colors,
              ),
            );
          }
          return _ResponsiveFields(columns: columns, children: tiles);
        },
      ),
    );
  }

  Widget _buildTeamDocuments(PaymentItem payment, PaidiXColorScheme colors) {
    return _SectionCard(
      title: 'Documents from our team',
      colors: colors,
      child: Column(
        children: [
          if (payment.verifiedDocumentUrl != null)
            _DocumentLink(
              label: 'Verification document',
              url: payment.verifiedDocumentUrl!,
              details:
                  [
                        payment.verifiedByName,
                        payment.verifiedByEmail,
                        payment.verifiedAt == null
                            ? null
                            : AppFormatters.formatDateTime(payment.verifiedAt),
                      ]
                      .whereType<String>()
                      .where((value) => value.trim().isNotEmpty)
                      .join(' · '),
              colors: colors,
            ),
          if (payment.verifiedDocumentUrl != null &&
              payment.accountantDocumentUrl != null)
            Divider(color: colors.divider, height: 24),
          if (payment.accountantDocumentUrl != null)
            _DocumentLink(
              label: 'Additional document',
              url: payment.accountantDocumentUrl!,
              details: _display(payment.handledByEmail),
              colors: colors,
            ),
          if (payment.verifiedNote != null ||
              payment.accountantNotes != null) ...[
            const SizedBox(height: 14),
            _NoteBlock(
              note: [payment.verifiedNote, payment.accountantNotes]
                  .whereType<String>()
                  .where((value) => value.trim().isNotEmpty)
                  .join('\n'),
              colors: colors,
            ),
          ],
        ],
      ),
    );
  }

  bool _hasTransferInfo(PaymentItem payment) =>
      payment.hasPkrTransfer ||
      payment.transferAmountPkr != null ||
      payment.transferBankTransactionId != null ||
      payment.transferReceiptUrl != null ||
      payment.transferReceiptUrls.isNotEmpty;

  Widget _buildTransfer(PaymentItem payment, PaidiXColorScheme colors) {
    final receipts = <String>{
      ...payment.transferReceiptUrls,
      if (payment.transferReceiptUrl != null) payment.transferReceiptUrl!,
    }.toList(growable: false);
    return _SectionCard(
      title: 'PKR transfer proof',
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => _ResponsiveFields(
              columns: constraints.maxWidth < 480 ? 1 : 2,
              children: [
                _DetailField(
                  label: 'Amount transferred',
                  value: AppFormatters.formatPkr(
                    payment.transferAmountPkr ?? payment.netPkr,
                  ),
                  colors: colors,
                ),
                if (payment.transferDeductionPkr != null &&
                    payment.transferDeductionPkr! > 0)
                  _DetailField(
                    label: 'Deduction',
                    value:
                        '${AppFormatters.formatPkr(payment.transferDeductionPkr)} · Original ${AppFormatters.formatPkr(payment.transferOriginalAmountPkr ?? payment.netPkr)}',
                    colors: colors,
                  ),
                if (payment.transferBankTransactionId != null)
                  _DetailField(
                    label: 'Bank reference',
                    value: payment.transferBankTransactionId!,
                    colors: colors,
                    mono: true,
                  ),
                if (payment.transferDate != null)
                  _DetailField(
                    label: 'Transfer date',
                    value: AppFormatters.formatDate(payment.transferDate),
                    colors: colors,
                  ),
                if (payment.transferRecordedAt != null)
                  _DetailField(
                    label: 'Recorded on',
                    value: AppFormatters.formatDateTime(
                      payment.transferRecordedAt,
                    ),
                    colors: colors,
                  ),
              ],
            ),
          ),
          if (payment.transferNotes != null &&
              payment.transferNotes!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _NoteBlock(note: payment.transferNotes!, colors: colors),
          ],
          const SizedBox(height: 14),
          if (receipts.isEmpty)
            Text(
              'No receipt was uploaded.',
              style: TextStyle(color: colors.textMuted, fontSize: 13),
            )
          else
            ...receipts.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == receipts.length - 1 ? 0 : 10,
                ),
                child: _DocumentLink(
                  label: receipts.length == 1
                      ? 'PKR transfer receipt'
                      : 'PKR transfer receipt ${entry.key + 1}',
                  url: entry.value,
                  colors: colors,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgress(PaymentItem payment, PaidiXColorScheme colors) {
    final status = _normalizedStatus(payment.status.name);
    final submitted = true;
    final processing = const {
      'under_review',
      'pending_review',
      'verified',
      'pkr_sent',
      'awaiting_pkr',
      'completed',
    }.contains(status);
    final pkrSent = const {
      'pkr_sent',
      'awaiting_pkr',
      'completed',
    }.contains(status);
    final completed = status == 'completed';
    final steps = <_ProgressStepData>[
      _ProgressStepData(
        title: 'Submitted',
        detail: 'Your payment submission is recorded.',
        reached: submitted,
        time: _firstTime(payment, const {'submitted'}) ?? payment.submittedDate,
        note: _latestNoteFor(payment, const {'submitted'}),
      ),
      _ProgressStepData(
        title: 'Under Processing',
        detail: 'Our team is reviewing the payment documents.',
        reached: processing,
        time: _firstTime(payment, const {'under_review', 'verified'}),
        note: _latestNoteFor(payment, const {'under_review', 'verified'}),
      ),
      _ProgressStepData(
        title: 'PKR Sent',
        detail: 'PKR will be transferred once processing is complete.',
        reached: pkrSent,
        time: _firstTime(payment, const {'pkr_sent'}),
        note: _latestNoteFor(payment, const {'pkr_sent'}),
      ),
      _ProgressStepData(
        title: payment.forceCompletedBy == null
            ? 'Completed by Customer'
            : 'Completed',
        detail: payment.forceCompletedBy == null
            ? 'You confirmed receipt. This payment is closed.'
            : 'This payment was closed by the PaidiX team.',
        reached: completed,
        time:
            payment.customerConfirmedAt ??
            _firstTime(payment, const {'completed'}) ??
            payment.completedAt,
        note: _latestNoteFor(payment, const {'completed'}),
      ),
    ];

    return _SectionCard(
      title: 'Progress',
      colors: colors,
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _ProgressStep(
              step: steps[i],
              isLast: i == steps.length - 1,
              colors: colors,
            ),
          if (payment.status == PaymentStatusType.rejected ||
              payment.status == PaymentStatusType.onHold) ...[
            Divider(color: colors.divider, height: 26),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(status: payment.status),
            ),
            if (_latestNote(payment) != null) ...[
              const SizedBox(height: 9),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _latestNote(payment)!,
                  style: TextStyle(color: colors.textSecondary, height: 1.4),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String? _latestNote(PaymentItem payment) {
    for (final item in payment.statusHistory.reversed) {
      final note = item.note?.trim();
      if (note != null && note.isNotEmpty) return note;
    }
    return null;
  }

  DateTime? _firstTime(PaymentItem payment, Set<String> statuses) {
    final matches =
        payment.statusHistory
            .where(
              (item) => statuses.contains(_normalizedStatus(item.toStatus)),
            )
            .where((item) => item.createdAt != null)
            .toList()
          ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    return matches.isEmpty ? null : matches.first.createdAt;
  }

  String? _latestNoteFor(PaymentItem payment, Set<String> statuses) {
    final matches =
        payment.statusHistory
            .where(
              (item) => statuses.contains(_normalizedStatus(item.toStatus)),
            )
            .where((item) => item.note?.trim().isNotEmpty ?? false)
            .toList()
          ..sort(
            (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
              b.createdAt ?? DateTime(0),
            ),
          );
    return matches.isEmpty ? null : matches.last.note;
  }

  String _normalizedStatus(String status) => status
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]}_${match[2]}',
      )
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s-]+'), '_');

  String _formatMoney(double? amount, String currency) {
    switch (currency.trim().toUpperCase()) {
      case 'USD':
        return AppFormatters.formatUsd(amount);
      case 'PKR':
        return AppFormatters.formatPkr(amount);
      default:
        if (amount == null) return '—';
        return '${currency.toUpperCase()} ${amount.toStringAsFixed(2)}';
    }
  }

  String _display(String? value) =>
      value == null || value.trim().isEmpty ? '—' : value.trim();

  BoxDecoration _cardDecoration(PaidiXColorScheme colors) => BoxDecoration(
    color: colors.card,
    borderRadius: AppSpacing.radiusLg,
    border: Border.all(color: colors.border, width: 1.1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(
          alpha: colors.brightness == Brightness.dark ? .16 : .035,
        ),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
    ],
  );

  TextStyle _labelStyle(PaidiXColorScheme colors) =>
      AppTypography.tableHeader.copyWith(color: colors.textSecondary);
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final PaidiXColorScheme colors;

  const _SectionCard({
    required this.title,
    required this.child,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: AppSpacing.radiusLg,
        border: Border.all(color: colors.border, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: colors.brightness == Brightness.dark ? .16 : .035,
            ),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTypography.tableHeader.copyWith(
              color: colors.textMuted,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  final int columns;
  final List<Widget> children;

  const _ResponsiveFields({required this.columns, required this.children});

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            children[i],
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 18,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _DetailField extends StatelessWidget {
  final String label;
  final String value;
  final PaidiXColorScheme colors;
  final bool prominent;
  final bool mono;

  const _DetailField({
    required this.label,
    required this.value,
    required this.colors,
    this.prominent = false,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.tableHeader.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 5),
        SelectableText(
          value,
          style: TextStyle(
            fontFamily: mono ? 'monospace' : AppTheme.activeFontFamily,
            fontSize: prominent ? 27 : 15,
            height: 1.35,
            fontWeight: prominent ? FontWeight.w700 : FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ProgressStepData {
  final String title;
  final String detail;
  final bool reached;
  final DateTime? time;
  final String? note;

  const _ProgressStepData({
    required this.title,
    required this.detail,
    required this.reached,
    this.time,
    this.note,
  });
}

class _ProgressStep extends StatelessWidget {
  final _ProgressStepData step;
  final bool isLast;
  final PaidiXColorScheme colors;

  const _ProgressStep({
    required this.step,
    required this.isLast,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final accent = step.reached ? colors.aqua : colors.borderSubtle;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: step.reached
                          ? colors.aqua.withValues(alpha: .24)
                          : colors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      color: step.reached
                          ? colors.textPrimary
                          : colors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    step.detail,
                    style: TextStyle(color: colors.textSecondary, height: 1.35),
                  ),
                  if (step.time != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.formatDateTime(step.time),
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                  if (step.note != null && step.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      step.note!,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final PaidiXColorScheme colors;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: colors.cardHighlight,
      borderRadius: AppSpacing.radiusPill,
      border: Border.all(color: colors.borderSubtle),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colors.aqua),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
      ],
    ),
  );
}

class _ProofTile extends StatelessWidget {
  final String label;
  final String? url;
  final Uint8List? bytes;
  final PaidiXColorScheme colors;

  const _ProofTile({
    required this.label,
    required this.url,
    required this.colors,
    this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = url == null ? null : _resolveMediaUrl(url!);
    final image = bytes != null
        ? Image.memory(bytes!, fit: BoxFit.cover)
        : (resolvedUrl == null
              ? null
              : Image.network(
                  resolvedUrl,
                  headers: ApiClient.instance.imageHeadersFor(resolvedUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholder(),
                ));
    return InkWell(
      onTap: image == null ? null : () => _showImage(context, resolvedUrl),
      borderRadius: AppSpacing.radiusMd,
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardDark,
          borderRadius: AppSpacing.radiusMd,
          border: Border.all(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(aspectRatio: 4 / 3, child: image ?? _placeholder()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Center(
    child: Icon(Icons.broken_image_outlined, color: colors.textMuted, size: 34),
  );

  void _showImage(BuildContext context, String? resolvedUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .86),
      builder: (context) {
        final media = MediaQuery.sizeOf(context);
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: colors.card,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1000,
              maxHeight: media.height * .88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: bytes != null
                        ? Image.memory(bytes!, fit: BoxFit.contain)
                        : Image.network(
                            resolvedUrl!,
                            headers: ApiClient.instance.imageHeadersFor(
                              resolvedUrl,
                            ),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => _placeholder(),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DocumentLink extends StatelessWidget {
  final String label;
  final String url;
  final String? details;
  final PaidiXColorScheme colors;

  const _DocumentLink({
    required this.label,
    required this.url,
    required this.colors,
    this.details,
  });

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(_resolveMediaUrl(url));
    if (uri == null ||
        !(await launchUrl(uri, mode: LaunchMode.externalApplication))) {
      if (context.mounted) {
        PaidiXToast.showError(context, 'Could not open this document.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: colors.cardDark,
      borderRadius: AppSpacing.radiusMd,
      border: Border.all(color: colors.border),
    ),
    child: Row(
      children: [
        Icon(Icons.description_outlined, color: colors.aqua, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (details != null && details!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  details!,
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => _open(context),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('Open'),
        ),
      ],
    ),
  );
}

class _NoteBlock extends StatelessWidget {
  final String note;
  final PaidiXColorScheme colors;

  const _NoteBlock({required this.note, required this.colors});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: colors.cardDark,
      borderRadius: AppSpacing.radiusMd,
      border: Border.all(color: colors.border),
    ),
    child: Text(
      note,
      style: TextStyle(
        color: colors.textSecondary,
        fontStyle: FontStyle.italic,
        height: 1.4,
      ),
    ),
  );
}

String _resolveMediaUrl(String value) {
  final parsed = Uri.tryParse(value);
  if (parsed != null && parsed.hasScheme) return value;
  return ApiClient.instance.resolveMediaUrl(value);
}
