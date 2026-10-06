/// Unit conversion and formatting. Values are always stored in metric.
library;

enum UnitSystem {
  metric,
  imperial;

  String get label => this == metric ? 'Metric' : 'Imperial';
}

const double _cmPerInch = 2.54;
const double _kgPerLb = 0.45359237;

(int feet, int inches) cmToFeetInches(double cm) {
  final totalInches = (cm / _cmPerInch).round();
  return (totalInches ~/ 12, totalInches % 12);
}

double feetInchesToCm(int feet, int inches) => (feet * 12 + inches) * _cmPerInch;

double kgToLb(double kg) => kg / _kgPerLb;

double lbToKg(double lb) => lb * _kgPerLb;

String formatHeight(double cm, UnitSystem units) {
  if (units == UnitSystem.metric) return '${cm.round()} cm';
  final (ft, inch) = cmToFeetInches(cm);
  return '$ft′ $inch″';
}

String formatWeight(double kg, UnitSystem units) {
  if (units == UnitSystem.metric) return '${_trim(kg)} kg';
  return '${kgToLb(kg).round()} lb';
}

String _trim(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
