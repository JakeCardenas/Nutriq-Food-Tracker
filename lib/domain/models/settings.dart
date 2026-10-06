import '../units.dart';

export '../units.dart' show UnitSystem;

class AppSettings {
  const AppSettings({this.units = UnitSystem.metric, this.dayStartHour = 0, this.onboardingComplete = false});

  final UnitSystem units;

  /// Hour (0–6) when a new logging day begins. Helps late nights and night shifts.
  final int dayStartHour;
  final bool onboardingComplete;

  AppSettings copyWith({UnitSystem? units, int? dayStartHour, bool? onboardingComplete}) => AppSettings(
    units: units ?? this.units,
    dayStartHour: dayStartHour ?? this.dayStartHour,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
  );

  Map<String, Object?> toJson() => {
    'units': units.name,
    'dayStartHour': dayStartHour,
    'onboardingComplete': onboardingComplete,
  };

  factory AppSettings.fromJson(Map<String, Object?> j) => AppSettings(
    units: UnitSystem.values.asNameMap()[j['units']] ?? UnitSystem.metric,
    dayStartHour: j['dayStartHour'] as int? ?? 0,
    onboardingComplete: j['onboardingComplete'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.units == units &&
      other.dayStartHour == dayStartHour &&
      other.onboardingComplete == onboardingComplete;

  @override
  int get hashCode => Object.hash(units, dayStartHour, onboardingComplete);
}
