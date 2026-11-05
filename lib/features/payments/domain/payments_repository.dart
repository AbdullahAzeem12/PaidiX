/// Defines payments repository in the payments feature's domain layer.

import 'payment_models.dart';

abstract class PaymentsRepository {
  /// Stream or notifier of the current list of payments
  List<PaymentItem> get payments;

  /// Returns the payment options available to the new-payment form.
  Future<List<PaymentMethodOption>> getPaymentMethods();

  /// Returns the processing-fee percentage used when calculating a payment.
  Future<double> getFeePercentage();

  /// Returns the USD-to-PKR rate used when calculating the converted total.
  Future<double> getUsdToPkrRate();

  /// Submits a payment and returns the resulting record with its calculated totals.
  Future<PaymentItem> submitPayment(PaymentSubmission submission);

  /// Filters by search text, status, and date range; currency filtering is not
  /// currently applied by the repository implementation.
  List<PaymentItem> filterPayments(PaymentFilter filter);
}

