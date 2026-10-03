String formatAnalyticsVnd(BigInt cents) {
  final whole = (cents ~/ BigInt.from(100)).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
  final tail = (cents % BigInt.from(100))
      .toString()
      .padLeft(2, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '$whole${tail.isEmpty ? '' : ',$tail'} ₫';
}

/// Compact labels keep legends/scales readable; tooltips expose full amounts.
String compactAnalyticsVnd(BigInt cents) {
  final whole = cents ~/ BigInt.from(100);
  if (whole < BigInt.from(1000000)) return formatAnalyticsVnd(cents);
  final digits = whole.toString();
  final exponent = digits.length - 1;
  final scale = exponent >= 15 ? exponent : (exponent ~/ 3) * 3;
  final unit = {6: 'triệu', 9: 'tỷ', 12: 'nghìn tỷ'}[scale];
  final divisor = BigInt.from(10).pow(scale);
  final tenths = (whole * BigInt.from(10)) ~/ divisor;
  final main = tenths ~/ BigInt.from(10);
  final decimal = tenths % BigInt.from(10);
  final value = '$main${decimal == BigInt.zero ? '' : ',$decimal'}';
  return unit == null ? '$value × 10^$scale ₫' : '$value $unit ₫';
}
