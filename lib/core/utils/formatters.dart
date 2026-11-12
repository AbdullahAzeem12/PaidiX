/// Defines formatters in the application core utilities and reusable widgets.

class AppFormatters {
  AppFormatters._();

  /// Formats an amount as USD currency: e.g. "$ 171.00"
  static String formatUsd(double? amount) {
    if (amount == null) return '—';
    final parts = _splitDecimals(amount, 2);
    return '\$ ${_formatWithCommas(parts[0])}.${parts[1]}';
  }

  /// Formats an amount as PKR currency: e.g. "Rs 41,081.04"
  static String formatPkr(double? amount) {
    if (amount == null) return '—';
    final parts = _splitDecimals(amount, 2);
    return 'Rs ${_formatWithCommas(parts[0])}.${parts[1]}';
  }

  /// Formats a percentage: e.g. "12.00%"
  static String formatPercentage(double? rate) {
    if (rate == null) return '—';
    final parts = _splitDecimals(rate, 2);
    return '${parts[0]}.${parts[1]}%';
  }

  /// Formats a DateTime into readable MMM d, yyyy: e.g. "Aug 28, 2026"
  static String formatDate(DateTime? date) {
    if (date == null) return '—';
    // API timestamps carry an explicit offset (often +05:00). DateTime.parse
    // stores those instants in UTC; render them in the device's local zone so
    // their calendar date matches the customer website.
    final localDate = date.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[localDate.month - 1];
    return '$m ${localDate.day}, ${localDate.year}';
  }

  /// Formats a DateTime into readable MMM d, yyyy, hh:mm a: e.g. "Oct 29, 2026, 01:09 AM"
  static String formatDateTime(DateTime? date) {
    if (date == null) return '—';
    final localDate = date.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[localDate.month - 1];
    final d = localDate.day.toString().padLeft(2, '0');
    final hour = localDate.hour % 12 == 0 ? 12 : localDate.hour % 12;
    final hourStr = hour.toString().padLeft(2, '0');
    final minuteStr = localDate.minute.toString().padLeft(2, '0');
    final amPm = localDate.hour >= 12 ? 'PM' : 'AM';
    return '$m $d, ${localDate.year}, $hourStr:$minuteStr $amPm';
  }

  /// Formats a DateTime into mm / dd / yyyy for input fields
  static String formatDateInput(DateTime? date) {
    if (date == null) return '';
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$m / $d / ${date.year}';
  }

  /// Splits a fixed-precision number into integer and fractional text parts.
  static List<String> _splitDecimals(double value, int fractionDigits) {
    final fixed = value.toStringAsFixed(fractionDigits);
    final dotIndex = fixed.indexOf('.');
    if (dotIndex == -1) return [fixed, '00'];
    return [fixed.substring(0, dotIndex), fixed.substring(dotIndex + 1)];
  }

  /// Adds digit-grouping commas to an integer string while preserving its sign.
  static String _formatWithCommas(String integerPart) {
    final isNegative = integerPart.startsWith('-');
    final clean = isNegative ? integerPart.substring(1) : integerPart;
    final buffer = StringBuffer();
    final len = clean.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(clean[i]);
    }
    return isNegative ? '-${buffer.toString()}' : buffer.toString();
  }
}
