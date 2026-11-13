/// Defines payments repository impl in the payments feature's data layer.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/payment_models.dart';
import '../domain/payments_repository.dart';

class PaymentsRepositoryImpl implements PaymentsRepository {
  final ValueNotifier<List<PaymentItem>> _paymentsNotifier;
  final ApiClient _apiClient;
  final ValueNotifier<PaymentsServerSummary?> _serverSummaryNotifier =
      ValueNotifier<PaymentsServerSummary?>(null);
  Future<bool>? _refreshInFlight;
  Future<List<PaymentMethodOption>>? _paymentMethodsInFlight;
  Timer? _pollTimer;
  int _pollSubscribers = 0;
  bool _hasLoadedFromServer = false;

  static const Duration _pollInterval = Duration(seconds: 5);
  static const int _serverPageSize = 100;
  static const int _maxServerPages = 100;

  PaymentsRepositoryImpl([List<PaymentItem>? initialPayments])
    : _paymentsNotifier = ValueNotifier<List<PaymentItem>>(
        initialPayments != null ? List.from(initialPayments) : [],
      ),
      _apiClient = ApiClient.instance;

  ValueListenable<List<PaymentItem>> get paymentsListenable =>
      _paymentsNotifier;

  ValueListenable<PaymentsServerSummary?> get serverSummaryListenable =>
      _serverSummaryNotifier;

  PaymentsServerSummary? get serverSummary => _serverSummaryNotifier.value;

  bool get hasLoadedFromServer => _hasLoadedFromServer;

  @override
  List<PaymentItem> get payments => List.unmodifiable(_paymentsNotifier.value);

  /// Clears in-memory payments.
  void clearPayments() {
    _paymentsNotifier.value = [];
    _serverSummaryNotifier.value = null;
    _hasLoadedFromServer = false;
  }

  /// Starts one shared five-second poll while Dashboard or My Payments is
  /// visible. The returned callback releases this screen's polling lease.
  VoidCallback watchServerUpdates() {
    _pollSubscribers++;
    if (_pollSubscribers == 1 && AppConfig.hasCustomBackend) {
      _pollTimer = Timer.periodic(_pollInterval, (_) {
        unawaited(refreshServerData());
      });
    }
    // Refresh on screen entry as well as on the shared timer. This also covers
    // a page becoming active while another shell route already owns the poll.
    if (AppConfig.hasCustomBackend) unawaited(refreshServerData());

    var released = false;
    return () {
      if (released) return;
      released = true;
      if (_pollSubscribers > 0) _pollSubscribers--;
      if (_pollSubscribers == 0) {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    };
  }

  /// Fetches payment records and their server-calculated aggregates. Existing
  /// data stays visible if either request fails, and concurrent refreshes are
  /// coalesced so multiple screens never create duplicate poll traffic.
  Future<void> refreshServerData() {
    return refreshServerDataWithResult().then<void>((_) {});
  }

  /// Refreshes the current server snapshot and reports whether both the
  /// payments list and summary were fetched successfully.
  Future<bool> refreshServerDataWithResult() {
    if (!AppConfig.hasCustomBackend) return Future<bool>.value(true);
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final refresh = _refreshServerData();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    });
  }

  /// Loads the authoritative detail record for one payment.
  ///
  /// The endpoint is refreshed independently from the list snapshot because
  /// it contains status history, verification and transfer documents, and
  /// other fields that are intentionally not duplicated on payment cards.
  Future<PaymentItem> getPaymentDetails(String id) async {
    if (!AppConfig.hasCustomBackend) {
      final local = _findPayment(id);
      if (local == null) {
        throw const FormatException('This payment is no longer available.');
      }
      return local;
    }

    final response = await _apiClient.get(
      '/transactions/payments/${Uri.encodeComponent(id)}/',
    );
    final record = _unwrapPaymentRecord(response);
    final payment = _paymentFromServer(record, preserveExisting: false);
    _replacePayment(payment);
    return payment;
  }

  /// Confirms receipt of the PKR transfer through the documented customer
  /// action, then reloads the record so the server's completed status wins.
  Future<PaymentItem> confirmCustomerReceipt(
    String id, {
    String note = '',
  }) async {
    if (!AppConfig.hasCustomBackend) {
      throw const FormatException(
        'Confirming a PKR transfer requires a server connection.',
      );
    }

    await _apiClient.post(
      '/transactions/payments/${Uri.encodeComponent(id)}/customer-confirm/',
      body: {'note': note.trim()},
    );
    final payment = await getPaymentDetails(id);
    unawaited(refreshServerData());
    return payment;
  }

  void _replacePayment(PaymentItem payment) {
    final current = List<PaymentItem>.from(_paymentsNotifier.value);
    final index = current.indexWhere((item) => item.id == payment.id);
    if (index < 0) {
      current.insert(0, payment);
    } else {
      current[index] = payment;
    }
    _paymentsNotifier.value = current;
  }

  Future<bool> _refreshServerData() async {
    final results = await Future.wait<bool>([
      _refreshPaymentSnapshot(),
      _refreshSummarySnapshot(),
    ]);
    return results.every((success) => success);
  }

  Future<bool> _refreshPaymentSnapshot() async {
    try {
      final paymentResult = await _fetchServerPayments();
      final hasChanged = !_samePayments(_paymentsNotifier.value, paymentResult);
      final shouldNotify = hasChanged || !_hasLoadedFromServer;
      // Update this before notifying listeners so an empty successful response
      // leaves loading states immediately instead of rendering one extra time.
      _hasLoadedFromServer = true;
      if (shouldNotify) {
        _paymentsNotifier.value = List<PaymentItem>.from(paymentResult);
      }
      return true;
    } catch (error) {
      debugPrint('[PaymentsRepository] Payment refresh failed: $error');
      return false;
    }
  }

  Future<bool> _refreshSummarySnapshot() async {
    try {
      _serverSummaryNotifier.value = await _fetchServerSummary();
      return true;
    } catch (error) {
      debugPrint('[PaymentsRepository] Summary refresh failed: $error');
      return false;
    }
  }

  Future<List<PaymentItem>> _fetchServerPayments() async {
    final records = <Map<String, dynamic>>[];
    var page = 1;
    var hasNextPage = true;

    while (hasNextPage && page <= _maxServerPages) {
      final response = await _apiClient.get(
        '/transactions/payments/?page=$page&page_size=$_serverPageSize'
        '&ordering=-created_at',
      );
      final pageData = _parsePaymentPage(response);
      records.addAll(pageData.records);

      hasNextPage =
          pageData.hasNext ||
          (pageData.totalCount != null &&
              records.length < pageData.totalCount!);
      if (pageData.records.isEmpty) hasNextPage = false;
      page++;
    }

    return records
        .map((record) => _paymentFromServer(record))
        .toList(growable: false);
  }

  Future<PaymentsServerSummary> _fetchServerSummary() async {
    final response = await _apiClient.get('/transactions/payments/summary/');
    final record = _unwrapSummaryRecord(response);
    return PaymentsServerSummary(
      totalCount: _integer(record['total_count']),
      submittedTotal: _number(record['submitted_total']),
      grossPkrReceived: _number(record['gross_pkr_received']),
      transferred: _number(record['transferred']),
      pendingCount: _integer(record['pending']),
      completedCount: _integer(record['completed']),
      rejectedCount: _integer(record['rejected']),
    );
  }

  _PaymentPage _parsePaymentPage(Map<String, dynamic> response) {
    dynamic payload = response;
    for (var depth = 0; depth < 4; depth++) {
      if (payload is List) {
        return _PaymentPage(_mapList(payload), null, false);
      }
      if (payload is! Map) break;
      final map = Map<String, dynamic>.from(payload);
      final results = map['results'] ?? map['payments'] ?? map['items'];
      if (results is List) {
        final next = map['next'];
        return _PaymentPage(
          _mapList(results),
          _integer(map['count'] ?? map['total_count']),
          next != null && '$next'.trim().isNotEmpty,
        );
      }
      final nested = map['data'] ?? map['result'];
      if (nested == null) break;
      payload = nested;
    }
    throw const FormatException(
      'The payments endpoint returned an unexpected response shape.',
    );
  }

  Map<String, dynamic> _unwrapSummaryRecord(Map<String, dynamic> response) {
    var record = response;
    for (var depth = 0; depth < 4; depth++) {
      final nested = record['data'] ?? record['summary'] ?? record['result'];
      if (nested is Map) {
        record = Map<String, dynamic>.from(nested);
      } else {
        break;
      }
    }
    return record;
  }

  List<Map<String, dynamic>> _mapList(List values) => values
      .whereType<Map>()
      .map((record) => Map<String, dynamic>.from(record))
      .toList(growable: false);

  bool _samePayments(List<PaymentItem> current, List<PaymentItem> next) {
    if (current.length != next.length) return false;
    for (var index = 0; index < current.length; index++) {
      final left = current[index];
      final right = next[index];
      if (left.id != right.id ||
          left.reference != right.reference ||
          left.status != right.status ||
          left.amount != right.amount ||
          left.netPkr != right.netPkr ||
          left.exchangeRate != right.exchangeRate ||
          left.sender != right.sender ||
          left.senderCompany != right.senderCompany ||
          left.currencyCode != right.currencyCode ||
          left.transactionDate != right.transactionDate ||
          left.submittedDate != right.submittedDate ||
          left.proofFilePath != right.proofFilePath) {
        return false;
      }
    }
    return true;
  }

  // Legacy offline/test simulation defaults. Live values come from the server.
  final double _feePercentage = 12.0;
  final double _usdToPkrRate = 273.0;

  int _referenceCounter = 1334;

  /// Returns the payment methods the authenticated server currently allows this
  /// customer to use. The `for_me=true` scope is authoritative: production
  /// must never fall back to locally listed methods when the request fails or
  /// the server returns an empty list.
  @override
  Future<List<PaymentMethodOption>> getPaymentMethods() {
    if (!AppConfig.hasCustomBackend) {
      // Offline/test fixture only. Live accounts always use the scoped API.
      return Future.value(const [
        PaymentMethodOption(
          id: 'cashapp_1',
          name: 'Freight Flow Cashapp',
          iconKey: 'cashapp',
        ),
        PaymentMethodOption(id: 'zelle_1', name: 'UB Zelle', iconKey: 'zelle'),
      ]);
    }

    final inFlight = _paymentMethodsInFlight;
    if (inFlight != null) return inFlight;

    final request = _fetchPaymentMethodsForCurrentUser();
    _paymentMethodsInFlight = request;
    return request.whenComplete(() {
      if (identical(_paymentMethodsInFlight, request)) {
        _paymentMethodsInFlight = null;
      }
    });
  }

  Future<List<PaymentMethodOption>> _fetchPaymentMethodsForCurrentUser() async {
    final response = await _apiClient.get(
      '/core/payment-methods/?active_only=true&for_me=true',
    );
    final records = _paymentMethodRecords(response);
    final methods = <({int order, PaymentMethodOption method})>[];

    for (final record in records) {
      final code = '${record['code'] ?? ''}'.trim();
      // `active_only=true` is also enforced by the API, but require its
      // explicit active flag here so malformed or partial records fail closed.
      if (code.isEmpty || record['is_active'] != true) continue;
      if (record['is_allowed'] == false || record['allowed'] == false) {
        continue;
      }

      final methodType = '${record['method_type'] ?? code}'.toLowerCase();
      final orderValue = record['sort_order'];
      methods.add((
        order: orderValue is num
            ? orderValue.toInt()
            : int.tryParse('$orderValue') ?? 0,
        method: PaymentMethodOption(
          // Keep the exact backend code. This is the value submitted to the
          // payment endpoint; labels and icon names are presentation only.
          id: code,
          name: '${record['label'] ?? code}'.trim(),
          iconKey: methodType,
        ),
      ));
    }

    methods.sort((left, right) => left.order.compareTo(right.order));
    return List<PaymentMethodOption>.unmodifiable(
      methods.map((entry) => entry.method),
    );
  }

  List<Map<String, dynamic>> _paymentMethodRecords(
    Map<String, dynamic> response,
  ) {
    dynamic payload = response;
    for (var depth = 0; depth < 5; depth++) {
      if (payload is List) {
        return payload
            .whereType<Map>()
            .map((record) => Map<String, dynamic>.from(record))
            .toList(growable: false);
      }
      if (payload is! Map) break;

      final map = Map<String, dynamic>.from(payload);
      if (map.containsKey('code')) return [map];

      dynamic nested;
      for (final key in const [
        'results',
        'payment_methods',
        'methods',
        'items',
        'data',
        'result',
      ]) {
        if (map.containsKey(key) && map[key] != null) {
          nested = map[key];
          break;
        }
      }
      if (nested == null) break;
      payload = nested;
    }

    throw const FormatException(
      'The payment methods endpoint returned an unexpected response shape.',
    );
  }

  /// Returns the legacy offline/test fee estimate.
  @override
  Future<double> getFeePercentage() async => _feePercentage;

  /// Returns the legacy offline/test USD-to-PKR estimate.
  @override
  Future<double> getUsdToPkrRate() async => _usdToPkrRate;

  /// Calculates the fee and net PKR, creates a completed payment, and inserts
  /// it at the front of the shared list in offline/test mode. Live sessions
  /// create the payment through the authenticated customer API and use the
  /// server response as the source of truth.
  @override
  Future<PaymentItem> submitPayment(PaymentSubmission submission) async {
    if (AppConfig.hasCustomBackend) {
      return _submitPaymentToServer(submission);
    }

    final feeAmount = (submission.amount * _feePercentage) / 100.0;
    final netUsd = submission.amount - feeAmount;
    final netPkr = netUsd * _usdToPkrRate;

    final refNumber = 'PBX-2026-00${_referenceCounter++}';
    final now = DateTime.now();

    final newPayment = PaymentItem(
      id: 'pay_${now.millisecondsSinceEpoch}',
      reference: refNumber,
      sender: submission.senderName,
      senderCompany: submission.senderCompany,
      amount: submission.amount,
      exchangeRate: _usdToPkrRate,
      feeAmount: feeAmount,
      netPkr: netPkr,
      status: PaymentStatusType.completed,
      transactionDate: submission.transactionDate ?? now,
      submittedDate: now,
      proofFileName: submission.proofFileName,
      proofFilePath: submission.proofFilePath,
      proofBytes: submission.proofBytes,
    );

    final updated = List<PaymentItem>.from(_paymentsNotifier.value)
      ..insert(0, newPayment);
    _paymentsNotifier.value = updated;

    return newPayment;
  }

  Future<PaymentItem> _submitPaymentToServer(
    PaymentSubmission submission,
  ) async {
    final fields = <String, String>{
      'payment_method': submission.methodId,
      'amount': submission.amount.toString(),
      'sender_company': submission.senderCompany,
      'currency': submission.currencyCode,
      if (submission.senderName.trim().isNotEmpty)
        'sender_name': submission.senderName.trim(),
      if (submission.confirmationCode.trim().isNotEmpty)
        'external_transaction_id': submission.confirmationCode.trim(),
      if (submission.transactionDate != null)
        'occurred_on': _formatApiDate(submission.transactionDate!),
    };

    final response = await _apiClient.postMultipart(
      '/transactions/payments/',
      fields: fields,
      filesBuilder: () {
        final bytes = submission.proofBytes;
        if (bytes == null) return const <http.MultipartFile>[];
        return [
          http.MultipartFile.fromBytes(
            'screenshot_transaction',
            bytes,
            filename: submission.proofFileName ?? 'payment_screenshot.jpg',
          ),
        ];
      },
    );

    final record = _unwrapPaymentRecord(response);
    final item = _paymentFromServer(record, submission: submission);
    _paymentsNotifier.value = [
      item,
      ..._paymentsNotifier.value.where((existing) => existing.id != item.id),
    ];
    unawaited(refreshServerData());
    return item;
  }

  Map<String, dynamic> _unwrapPaymentRecord(Map<String, dynamic> response) {
    var record = response;
    for (var depth = 0; depth < 3; depth++) {
      final nested = record['data'] ?? record['payment'] ?? record['result'];
      if (nested is Map<String, dynamic>) {
        record = nested;
      } else {
        break;
      }
    }
    if (record['id'] == null) {
      throw const FormatException(
        'The server accepted the payment but did not return its payment ID.',
      );
    }
    return record;
  }

  PaymentItem _paymentFromServer(
    Map<String, dynamic> record, {
    PaymentSubmission? submission,
    bool preserveExisting = true,
  }) {
    final id = '${record['id']}'.trim();
    final reference = '${record['reference'] ?? id}'.trim();
    final existing = preserveExisting ? _findPayment(id) : null;
    final amount =
        _number(record['amount']) ??
        submission?.amount ??
        existing?.amount ??
        0;
    final feePercentage = _number(record['fee_percentage']);
    final exchangeRate =
        _number(record['exchange_rate'] ?? record['real_exchange_rate']) ?? 0;
    final status = _paymentStatus(record['status']);
    final now = DateTime.now();
    final occurredOn =
        _firstDateTime(record, const [
          'occurred_on',
          'transaction_date',
          'payment_date',
          'transaction_at',
        ]) ??
        submission?.transactionDate ??
        existing?.transactionDate ??
        now;
    final createdAt =
        _firstDateTime(record, const [
          'created_at',
          'submitted_at',
          'submitted_on',
        ]) ??
        existing?.submittedDate ??
        now;
    final screenshotUrl = _optionalString(
      record['screenshot_transaction'] ?? record['screenshot_transaction_url'],
    );
    final rawPaymentMethod = record['payment_method'];
    final paymentMethodRecord = rawPaymentMethod is Map
        ? Map<String, dynamic>.from(rawPaymentMethod)
        : null;
    final history = _statusHistory(record['status_history']);
    final transferReceipts = _stringList(record['transfer_receipts']);
    final currencyCode =
        '${record['currency_code'] ?? record['currency'] ?? submission?.currencyCode ?? existing?.currencyCode ?? 'USD'}';
    final feeAmount =
        _number(record['fee_amount_foreign'] ?? record['fee_amount']) ??
        (feePercentage == null
            ? existing?.feeAmount ?? 0
            : amount * feePercentage / 100);

    return PaymentItem(
      id: id,
      reference: reference.isEmpty ? id : reference,
      sender:
          '${record['sender_name'] ?? submission?.senderName ?? existing?.sender ?? ''}'
              .trim(),
      senderCompany:
          '${record['sender_company'] ?? submission?.senderCompany ?? existing?.senderCompany ?? ''}'
              .trim(),
      amount: amount,
      exchangeRate: exchangeRate,
      feeAmount: feeAmount,
      netPkr: _number(record['net_pkr']) ?? existing?.netPkr ?? 0,
      status: status,
      transactionDate: occurredOn,
      submittedDate: createdAt,
      currencyCode: currencyCode,
      proofFileName: submission?.proofFileName ?? existing?.proofFileName,
      proofFilePath: screenshotUrl is String && screenshotUrl.isNotEmpty
          ? screenshotUrl
          : (submission?.proofFilePath ?? existing?.proofFilePath),
      proofBytes: submission?.proofBytes ?? existing?.proofBytes,
      feePercentage: feePercentage ?? existing?.feePercentage,
      netAmountForeign:
          _number(record['net_amount_foreign']) ?? existing?.netAmountForeign,
      grossPkr: _number(record['gross_pkr']) ?? existing?.grossPkr,
      paymentMethodCode:
          _optionalString(
            record['payment_method_code'] ??
                paymentMethodRecord?['code'] ??
                (rawPaymentMethod is String ? rawPaymentMethod : null),
          ) ??
          existing?.paymentMethodCode,
      paymentMethodLabel:
          _optionalString(
            record['payment_method_label'] ?? paymentMethodRecord?['label'],
          ) ??
          existing?.paymentMethodLabel,
      externalTransactionId:
          _optionalString(record['external_transaction_id']) ??
          existing?.externalTransactionId,
      screenshotTransactionUrl:
          screenshotUrl ?? existing?.screenshotTransactionUrl,
      screenshotEmailUrl:
          _optionalString(
            record['screenshot_email'] ?? record['screenshot_email_url'],
          ) ??
          existing?.screenshotEmailUrl,
      autoVerified:
          _boolean(record['auto_verified'] ?? record['auto_confirmed']) ??
          existing?.autoVerified ??
          false,
      hasPkrTransfer:
          _boolean(record['has_pkr_transfer']) ??
          existing?.hasPkrTransfer ??
          false,
      statusHistory: history.isNotEmpty
          ? history
          : existing?.statusHistory ?? const [],
      verifiedDocumentUrl:
          _optionalString(
            record['verified_document'] ?? record['verified_document_url'],
          ) ??
          existing?.verifiedDocumentUrl,
      accountantDocumentUrl:
          _optionalString(
            record['accountant_document'] ?? record['accountant_document_url'],
          ) ??
          existing?.accountantDocumentUrl,
      verifiedByName:
          _optionalString(record['verified_by_name']) ??
          existing?.verifiedByName,
      verifiedByEmail:
          _optionalString(record['verified_by_email']) ??
          existing?.verifiedByEmail,
      verifiedAt: _dateTime(record['verified_at']) ?? existing?.verifiedAt,
      verifiedNote:
          _optionalString(record['verified_note']) ?? existing?.verifiedNote,
      handledByEmail:
          _optionalString(record['handled_by_email']) ??
          existing?.handledByEmail,
      accountantNotes:
          _optionalString(record['accountant_notes']) ??
          existing?.accountantNotes,
      transferAmountPkr:
          _number(record['transfer_amount_pkr']) ?? existing?.transferAmountPkr,
      transferDeductionPkr:
          _number(record['transfer_deduction_pkr']) ??
          existing?.transferDeductionPkr,
      transferOriginalAmountPkr:
          _number(record['transfer_original_amount_pkr']) ??
          existing?.transferOriginalAmountPkr,
      transferBankTransactionId:
          _optionalString(record['transfer_bank_transaction_id']) ??
          existing?.transferBankTransactionId,
      transferDate:
          _dateTime(record['transfer_date']) ?? existing?.transferDate,
      transferRecordedAt:
          _dateTime(record['transfer_recorded_at']) ??
          existing?.transferRecordedAt,
      transferNotes:
          _optionalString(record['transfer_notes']) ?? existing?.transferNotes,
      transferReceiptUrls: transferReceipts.isNotEmpty
          ? transferReceipts
          : existing?.transferReceiptUrls ?? const [],
      transferReceiptUrl:
          _optionalString(
            record['transfer_receipt'] ?? record['transfer_receipt_url'],
          ) ??
          existing?.transferReceiptUrl,
      forceCompletedBy:
          _optionalString(record['force_completed_by']) ??
          existing?.forceCompletedBy,
      customerConfirmedAt:
          _dateTime(record['customer_confirmed_at']) ??
          existing?.customerConfirmedAt,
      completedAt: _dateTime(record['completed_at']) ?? existing?.completedAt,
    );
  }

  List<PaymentStatusHistoryItem> _statusHistory(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((record) {
          final history = Map<String, dynamic>.from(record);
          final toStatus = _optionalString(
            history['to_status'] ?? history['status'],
          );
          if (toStatus == null) return null;
          return PaymentStatusHistoryItem(
            fromStatus: _optionalString(history['from_status']),
            toStatus: toStatus,
            note: _optionalString(history['note'] ?? history['description']),
            createdAt: _dateTime(history['created_at'] ?? history['timestamp']),
          );
        })
        .whereType<PaymentStatusHistoryItem>()
        .toList(growable: false);
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((entry) {
          if (entry is Map) {
            final record = Map<String, dynamic>.from(entry);
            return _optionalString(record['url'] ?? record['href']);
          }
          return _optionalString(entry);
        })
        .whereType<String>()
        .toList(growable: false);
  }

  PaymentItem? _findPayment(String id) {
    for (final payment in _paymentsNotifier.value) {
      if (payment.id == id) return payment;
    }
    return null;
  }

  PaymentStatusType _paymentStatus(dynamic value) {
    switch ('$value'.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_')) {
      case 'submitted':
        return PaymentStatusType.submitted;
      case 'under_review':
      case 'underreview':
        return PaymentStatusType.underReview;
      case 'pending_review':
      case 'pendingreview':
        return PaymentStatusType.pendingReview;
      case 'verified':
        return PaymentStatusType.verified;
      case 'pkr_sent':
      case 'pkrsent':
        return PaymentStatusType.pkrSent;
      case 'awaiting_pkr':
      case 'awaitingpkr':
      case 'pkr_pending':
      case 'pkrpending':
        return PaymentStatusType.awaitingPkr;
      case 'completed':
        return PaymentStatusType.completed;
      case 'on_hold':
      case 'onhold':
        return PaymentStatusType.onHold;
      case 'rejected':
        return PaymentStatusType.rejected;
      default:
        // A successful create response is submitted according to the API
        // contract. This fallback also avoids falsely displaying it completed.
        return PaymentStatusType.submitted;
    }
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String? _optionalString(dynamic value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  DateTime? _dateTime(dynamic value) {
    final text = _optionalString(value);
    if (text == null) return null;
    return DateTime.tryParse(text);
  }

  DateTime? _firstDateTime(Map<String, dynamic> record, List<String> keys) {
    for (final key in keys) {
      final value = record[key];
      if (value == null) continue;
      final parsed = DateTime.tryParse('$value'.trim());
      if (parsed != null) return parsed;
    }
    return null;
  }

  bool? _boolean(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
        case '1':
        case 'yes':
          return true;
        case 'false':
        case '0':
        case 'no':
          return false;
      }
    }
    return null;
  }

  int? _integer(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt();
    }
    return null;
  }

  String _formatApiDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Applies text search, status, and date-range filters to the current list.
  @override
  List<PaymentItem> filterPayments(PaymentFilter filter) {
    var result = List<PaymentItem>.from(_paymentsNotifier.value);

    // Dashboard workflow groups share their status membership with the
    // dashboard counts. Exact status filtering below remains available.
    switch (filter.statusGroup) {
      case PaymentStatusGroup.pendingReview:
        result = result.where((item) => item.status.isPendingReview).toList();
        break;
      case PaymentStatusGroup.awaitingPkr:
        result = result.where((item) => item.status.isAwaitingPkr).toList();
        break;
      case null:
        break;
    }

    // Search query filter
    if (filter.searchQuery.trim().isNotEmpty) {
      final q = filter.searchQuery.trim().toLowerCase();
      result = result.where((item) {
        return item.reference.toLowerCase().contains(q) ||
            item.sender.toLowerCase().contains(q) ||
            item.senderCompany.toLowerCase().contains(q) ||
            item.amount.toString().contains(q);
      }).toList();
    }

    // Status filter
    if (filter.status != StatusFilterOption.all) {
      PaymentStatusType? targetType;
      switch (filter.status) {
        case StatusFilterOption.submitted:
          targetType = PaymentStatusType.submitted;
          break;
        case StatusFilterOption.underReview:
          targetType = PaymentStatusType.underReview;
          break;
        case StatusFilterOption.verified:
          targetType = PaymentStatusType.verified;
          break;
        case StatusFilterOption.pkrSent:
          targetType = PaymentStatusType.pkrSent;
          break;
        case StatusFilterOption.completed:
          targetType = PaymentStatusType.completed;
          break;
        case StatusFilterOption.onHold:
          targetType = PaymentStatusType.onHold;
          break;
        case StatusFilterOption.rejected:
          targetType = PaymentStatusType.rejected;
          break;
        case StatusFilterOption.all:
          targetType = null;
          break;
      }
      if (targetType != null) {
        result = result.where((item) {
          if (targetType == PaymentStatusType.underReview) {
            return item.status == PaymentStatusType.underReview ||
                item.status == PaymentStatusType.pendingReview;
          }
          if (targetType == PaymentStatusType.pkrSent) {
            return item.status == PaymentStatusType.pkrSent ||
                item.status == PaymentStatusType.awaitingPkr;
          }
          return item.status == targetType;
        }).toList();
      }
    }

    // Date range filter / Custom dates / Bitnex week
    final now = DateTime.now();
    if (filter.fromDate != null || filter.toDate != null) {
      if (filter.fromDate != null) {
        final start = DateTime(
          filter.fromDate!.year,
          filter.fromDate!.month,
          filter.fromDate!.day,
          0,
          0,
          0,
        );
        result = result
            .where((item) => !item.transactionDate.isBefore(start))
            .toList();
      }
      if (filter.toDate != null) {
        final end = DateTime(
          filter.toDate!.year,
          filter.toDate!.month,
          filter.toDate!.day,
          23,
          59,
          59,
        );
        result = result
            .where((item) => !item.transactionDate.isAfter(end))
            .toList();
      }
    } else if (filter.isBitnexWeek) {
      // Bitnex settlement week (Monday 00:00:00 through Sunday 23:59:59)
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfDay = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );
      result = result
          .where((item) => item.transactionDate.isAfter(startOfDay))
          .toList();
    } else {
      switch (filter.dateRange) {
        case DateRangeFilter.today:
          result = result
              .where(
                (item) =>
                    item.transactionDate.year == now.year &&
                    item.transactionDate.month == now.month &&
                    item.transactionDate.day == now.day,
              )
              .toList();
          break;
        case DateRangeFilter.yesterday:
          final y = now.subtract(const Duration(days: 1));
          result = result
              .where(
                (item) =>
                    item.transactionDate.year == y.year &&
                    item.transactionDate.month == y.month &&
                    item.transactionDate.day == y.day,
              )
              .toList();
          break;
        case DateRangeFilter.last3Days:
          final cutoff = now.subtract(const Duration(days: 3));
          result = result
              .where((item) => item.transactionDate.isAfter(cutoff))
              .toList();
          break;
        case DateRangeFilter.thisWeek:
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final startOfDay = DateTime(
            startOfWeek.year,
            startOfWeek.month,
            startOfWeek.day,
          );
          result = result
              .where((item) => item.transactionDate.isAfter(startOfDay))
              .toList();
          break;
        case DateRangeFilter.lastWeek:
          final startOfLastWeek = now.subtract(
            Duration(days: now.weekday - 1 + 7),
          );
          final endOfLastWeek = now.subtract(Duration(days: now.weekday));
          result = result
              .where(
                (item) =>
                    item.transactionDate.isAfter(startOfLastWeek) &&
                    item.transactionDate.isBefore(endOfLastWeek),
              )
              .toList();
          break;
        case DateRangeFilter.thisMonth:
          result = result
              .where(
                (item) =>
                    item.transactionDate.year == now.year &&
                    item.transactionDate.month == now.month,
              )
              .toList();
          break;
        case DateRangeFilter.lastMonth:
          final prevMonth = now.month == 1 ? 12 : now.month - 1;
          final prevYear = now.month == 1 ? now.year - 1 : now.year;
          result = result
              .where(
                (item) =>
                    item.transactionDate.year == prevYear &&
                    item.transactionDate.month == prevMonth,
              )
              .toList();
          break;
        case DateRangeFilter.last3Months:
          final cutoff = DateTime(now.year, now.month - 3, now.day);
          result = result
              .where((item) => item.transactionDate.isAfter(cutoff))
              .toList();
          break;
        case DateRangeFilter.last6Months:
          final cutoff = DateTime(now.year, now.month - 6, now.day);
          result = result
              .where((item) => item.transactionDate.isAfter(cutoff))
              .toList();
          break;
        case DateRangeFilter.last12Months:
          final cutoff = DateTime(now.year, now.month - 12, now.day);
          result = result
              .where((item) => item.transactionDate.isAfter(cutoff))
              .toList();
          break;
        case DateRangeFilter.thisYear:
          result = result
              .where((item) => item.transactionDate.year == now.year)
              .toList();
          break;
        case DateRangeFilter.lastYear:
          result = result
              .where((item) => item.transactionDate.year == now.year - 1)
              .toList();
          break;
        case DateRangeFilter.allTime:
        case DateRangeFilter.custom:
          break;
      }
    }

    return result;
  }
}

class _PaymentPage {
  final List<Map<String, dynamic>> records;
  final int? totalCount;
  final bool hasNext;

  const _PaymentPage(this.records, this.totalCount, this.hasNext);
}
