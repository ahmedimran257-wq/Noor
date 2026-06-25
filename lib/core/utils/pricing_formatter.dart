// lib/core/utils/pricing_formatter.dart
// ============================================================
// MITHAQ — Pricing Formatter Utility
// Formats price amounts with proper currency symbols and
// locale-appropriate number formatting.
// ============================================================

class PricingFormatter {
  PricingFormatter._();

  /// Formats a numeric [price] with the given [currencySymbol].
  ///
  /// Examples:
  ///   formatPrice(249, '₹')       → '₹249'
  ///   formatPrice(79000, 'Rp')    → 'Rp79,000'
  ///   formatPrice(9.99, '\$')     → '\$9.99'
  ///   formatPrice(2499, 'Rs.')    → 'Rs.2,499'
  static String formatPrice(num price, String currencySymbol) {
    final formatted = _formatNumber(price);
    return '$currencySymbol$formatted';
  }

  /// Formats a monthly CTA string.
  static String formatMonthlyCta(num price, String currencySymbol) {
    return 'Subscribe — ${formatPrice(price, currencySymbol)} / month';
  }

  /// Formats an annual CTA string.
  static String formatAnnualCta(num price, String currencySymbol) {
    return 'Subscribe — ${formatPrice(price, currencySymbol)} / year';
  }

  /// Calculates savings percentage between monthly and annual pricing.
  static int calculateSavings(num monthlyPrice, num annualPrice) {
    final monthlyCost = monthlyPrice * 12;
    if (monthlyCost <= 0) return 0;
    final savings = ((monthlyCost - annualPrice) / monthlyCost * 100).round();
    return savings.clamp(0, 100);
  }

  /// Formats a number with thousands separators.
  /// Handles both integers and decimals.
  static String _formatNumber(num value) {
    if (value is int || value == value.roundToDouble()) {
      // Integer formatting with commas
      final intVal = value.toInt();
      final str = intVal.toString();
      final buf = StringBuffer();
      for (var i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
        buf.write(str[i]);
      }
      return buf.toString();
    } else {
      // Decimal formatting
      final parts = value.toString().split('.');
      final intPart = int.parse(parts[0]);
      final decPart = parts.length > 1 ? parts[1] : '';
      final formatted = _formatNumber(intPart);
      return decPart.isNotEmpty ? '$formatted.$decPart' : formatted;
    }
  }
}
