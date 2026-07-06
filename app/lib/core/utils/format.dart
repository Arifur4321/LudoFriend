/// Formatting helpers shared across the economy UI.
library;

/// 1234567 -> "1,234,567".
String formatCoins(int value) {
  final neg = value < 0;
  final digits = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '${neg ? '-' : ''}$buf';
}

/// 20000 -> "20K", 1500000 -> "1.5M" (compact, for tight chips).
String compactCoins(int value) {
  if (value.abs() >= 1000000) {
    final m = value / 1000000;
    return '${_trim(m)}M';
  }
  if (value.abs() >= 1000) {
    final k = value / 1000;
    return '${_trim(k)}K';
  }
  return '$value';
}

String _trim(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}
