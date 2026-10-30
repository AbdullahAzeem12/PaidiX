import 'payment_models.dart';

abstract class PaymentsRepository {
  /// Stream or notifier of the current list of payments
  List<PaymentItem> get payments;

  /// Retrieves supported payment methods configured for this account
  Future<List<PaymentMethodOption>> getPaymentMethods();

  /// Retrieves currently configured processing fee percentage
  Future<double> getFeePercentage();

  /// Retrieves authoritative exchange rate USD -> PKR
  Future<double> getUsdToPkrRate();

  /// Submits a new payment for verification
  Future<PaymentItem> submitPayment(PaymentSubmission submission);

  /// Filters payments based on search, status, currency, and date range
  List<PaymentItem> filterPayments(PaymentFilter filter);
}

