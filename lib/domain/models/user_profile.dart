import 'package:flutter/foundation.dart';

enum FitnessGoal {
  loseFat('Lose body fat', 'Gradually, without extreme restriction'),
  maintain('Maintain', 'Keep things steady'),
  gainMuscle('Gain muscle', 'Eat enough to support growth'),
  buildStrength('Build strength', 'Fuel your training'),
  generalFitness('Improve general fitness', 'Feel and move better'),
  eatConsistently('Eat more consistently', 'Build a regular rhythm');

  const FitnessGoal(this.title, this.subtitle);
  final String title;
  final String subtitle;

  bool get isWeightLoss => this == loseFat;
}

enum ActivityLevel {
  sedentary(1.2, 'Mostly sitting', 'Desk work, little planned exercise'),
  light(1.375, 'Lightly active', 'Light exercise 1–3 days a week'),
  moderate(1.55, 'Moderately active', 'Exercise 3–5 days a week'),
  active(1.725, 'Very active', 'Hard exercise 6–7 days a week'),
  veryActive(1.9, 'Extremely active', 'Physical job plus hard training');

  const ActivityLevel(this.factor, this.title, this.description);
  final double factor;
  final String title;
  final String description;
}

/// Only used for the calorie formula's constant. Optional.
enum SexForEstimate {
  female('Female'),
  male('Male');

  const SexForEstimate(this.label);
  final String label;
}

enum HealthConsideration {
  pregnant('Pregnant'),
  breastfeeding('Breastfeeding'),
  medicalCondition('A medical condition that affects eating or weight');

  const HealthConsideration(this.label);
  final String label;
}

class CalorieRange {
  const CalorieRange({required this.min, required this.max, this.custom = false});

  final int min;
  final int max;

  /// True when the person typed their own range rather than using the estimate.
  final bool custom;

  int get mid => ((min + max) / 2).round();

  bool contains(num kcal) => kcal >= min && kcal <= max;

  Map<String, Object?> toJson() => {'min': min, 'max': max, 'custom': custom};

  factory CalorieRange.fromJson(Map<String, Object?> j) =>
      CalorieRange(min: j['min'] as int, max: j['max'] as int, custom: j['custom'] as bool? ?? false);

  @override
  bool operator ==(Object other) =>
      other is CalorieRange && other.min == min && other.max == max && other.custom == custom;

  @override
  int get hashCode => Object.hash(min, max, custom);
}

const _unset = Object();

/// Everything in here is optional and stays on the device.
class UserProfile {
  const UserProfile({
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.goalWeightKg,
    this.activity,
    this.goal,
    this.workoutDaysPerWeek,
    this.health = const {},
    this.calorieGoal,
    this.proteinTargetG,
  });

  final int? age;
  final SexForEstimate? sex;
  final double? heightCm;
  final double? weightKg;
  final double? goalWeightKg;
  final ActivityLevel? activity;
  final FitnessGoal? goal;
  final int? workoutDaysPerWeek;
  final Set<HealthConsideration> health;
  final CalorieRange? calorieGoal;
  final int? proteinTargetG;

  bool get isMinor => age != null && age! < 18;
  bool get hasHealthConsideration => health.isNotEmpty;

  /// Weight-loss targets and dieting coaching are switched off for these people.
  bool get dietingGuidanceRestricted => isMinor || hasHealthConsideration;

  UserProfile copyWith({
    Object? age = _unset,
    Object? sex = _unset,
    Object? heightCm = _unset,
    Object? weightKg = _unset,
    Object? goalWeightKg = _unset,
    Object? activity = _unset,
    Object? goal = _unset,
    Object? workoutDaysPerWeek = _unset,
    Set<HealthConsideration>? health,
    Object? calorieGoal = _unset,
    Object? proteinTargetG = _unset,
  }) => UserProfile(
    age: age == _unset ? this.age : age as int?,
    sex: sex == _unset ? this.sex : sex as SexForEstimate?,
    heightCm: heightCm == _unset ? this.heightCm : heightCm as double?,
    weightKg: weightKg == _unset ? this.weightKg : weightKg as double?,
    goalWeightKg: goalWeightKg == _unset ? this.goalWeightKg : goalWeightKg as double?,
    activity: activity == _unset ? this.activity : activity as ActivityLevel?,
    goal: goal == _unset ? this.goal : goal as FitnessGoal?,
    workoutDaysPerWeek: workoutDaysPerWeek == _unset ? this.workoutDaysPerWeek : workoutDaysPerWeek as int?,
    health: health ?? this.health,
    calorieGoal: calorieGoal == _unset ? this.calorieGoal : calorieGoal as CalorieRange?,
    proteinTargetG: proteinTargetG == _unset ? this.proteinTargetG : proteinTargetG as int?,
  );

  Map<String, Object?> toJson() => {
    'age': age,
    'sex': sex?.name,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'goalWeightKg': goalWeightKg,
    'activity': activity?.name,
    'goal': goal?.name,
    'workoutDaysPerWeek': workoutDaysPerWeek,
    'health': health.map((h) => h.name).toList(),
    'calorieGoal': calorieGoal?.toJson(),
    'proteinTargetG': proteinTargetG,
  };

  factory UserProfile.fromJson(Map<String, Object?> j) {
    T? byName<T extends Enum>(List<T> values, Object? name) =>
        name == null ? null : values.asNameMap()[name as String];
    return UserProfile(
      age: j['age'] as int?,
      sex: byName(SexForEstimate.values, j['sex']),
      heightCm: (j['heightCm'] as num?)?.toDouble(),
      weightKg: (j['weightKg'] as num?)?.toDouble(),
      goalWeightKg: (j['goalWeightKg'] as num?)?.toDouble(),
      activity: byName(ActivityLevel.values, j['activity']),
      goal: byName(FitnessGoal.values, j['goal']),
      workoutDaysPerWeek: j['workoutDaysPerWeek'] as int?,
      health: ((j['health'] as List?) ?? const [])
          .map((n) => byName(HealthConsideration.values, n))
          .whereType<HealthConsideration>()
          .toSet(),
      calorieGoal: j['calorieGoal'] == null
          ? null
          : CalorieRange.fromJson((j['calorieGoal'] as Map).cast<String, Object?>()),
      proteinTargetG: j['proteinTargetG'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.age == age &&
      other.sex == sex &&
      other.heightCm == heightCm &&
      other.weightKg == weightKg &&
      other.goalWeightKg == goalWeightKg &&
      other.activity == activity &&
      other.goal == goal &&
      other.workoutDaysPerWeek == workoutDaysPerWeek &&
      setEquals(other.health, health) &&
      other.calorieGoal == calorieGoal &&
      other.proteinTargetG == proteinTargetG;

  @override
  int get hashCode => Object.hash(
    age,
    sex,
    heightCm,
    weightKg,
    goalWeightKg,
    activity,
    goal,
    workoutDaysPerWeek,
    Object.hashAllUnordered(health),
    calorieGoal,
    proteinTargetG,
  );
}
