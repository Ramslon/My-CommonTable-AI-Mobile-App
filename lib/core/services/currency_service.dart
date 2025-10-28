class CurrencyService {
  static String format(double amount, String code) {
    switch (code.toLowerCase()) {
      case 'kes':
        return 'KSh ${amount.toStringAsFixed(2)}';
      case 'eur':
        return '€${amount.toStringAsFixed(2)}';
      case 'usd':
      default:
            return '\$ ${amount.toStringAsFixed(2)}'; // using safe dollar sign
    }
  }

  static String symbol(String code) {
    switch (code.toLowerCase()) {
      case 'kes':
        return 'KSh';
      case 'eur':
        return '€';
      case 'usd':
      default:
            return '\$'; // using safe dollar sign
    }
  }
}
