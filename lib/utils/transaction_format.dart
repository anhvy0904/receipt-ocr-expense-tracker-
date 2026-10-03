/// Expand large finite amounts so form values never contain exponent notation.
String amountInputText(double amount) {
  if (!amount.isFinite) return '';
  final text = amount.toString();
  if (!text.toLowerCase().contains('e')) return text;
  final parts = text.toLowerCase().split('e');
  final mantissa = parts.first.split('.');
  final digits = mantissa.join();
  final decimalIndex = mantissa.first.length + int.parse(parts.last);
  if (decimalIndex <= 0) return '0.${'0' * -decimalIndex}$digits';
  if (decimalIndex >= digits.length) {
    return '$digits${'0' * (decimalIndex - digits.length)}';
  }
  return '${digits.substring(0, decimalIndex)}.${digits.substring(decimalIndex)}';
}

String formatVnd(double amount) {
  if (!amount.isFinite) return 'Amount unavailable';
  final text = amount.abs() >= 1e21
      ? amountInputText(amount)
      : amount.toStringAsFixed(2);
  final parts = text.split('.');
  final grouped = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
  final fraction = parts.length == 2
      ? parts[1].replaceFirst(RegExp(r'0+$'), '')
      : '';
  return '$grouped${fraction.isEmpty ? '' : ',$fraction'} ₫';
}

String formatTransactionDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year.toString().padLeft(4, '0')}';
}
