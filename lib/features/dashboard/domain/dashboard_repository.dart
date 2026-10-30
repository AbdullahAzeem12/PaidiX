import 'dashboard_models.dart';

abstract class DashboardRepository {
  Future<CustomerScore?> getCustomerScore();
  Future<FinancialSummary> getFinancialSummary();
}

