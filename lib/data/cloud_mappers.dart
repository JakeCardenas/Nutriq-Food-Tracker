import '../domain/models/meal.dart';
import '../domain/models/saved_food.dart';
import '../domain/models/scan_feedback.dart';
import 'sync_models.dart';

/// Converts between the app's JSON models and the Postgres rows / RPC params
/// defined in `supabase/migrations`. Photos are deliberately never mapped:
/// a device file path is not a cloud photo URL.
abstract final class CloudMappers {
  // ── meals ──────────────────────────────────────────────────────────────

  static Map<String, Object?> mealPushParams(SyncRecord r) {
    if (r.deleted || r.json == null) {
      return {
        'p_meal': {'id': r.id, 'deleted': true, 'client_updated_at': r.updatedAt},
        'p_items': const <Object?>[],
      };
    }
    final meal = Meal.fromJson(r.json!);
    return {
      'p_meal': {
        'id': meal.id,
        'logged_at': meal.loggedAt.toUtc().toIso8601String(),
        'meal_type': meal.type.name,
        'source': meal.source.name,
        'name': meal.name,
        'note': meal.note,
        'deleted': false,
        'client_updated_at': r.updatedAt,
      },
      'p_items': [
        for (final item in meal.items)
          {
            'id': item.id,
            'name': item.name,
            'servings': item.servings,
            'serving_label': item.servingLabel,
            'calories_per_serving': item.caloriesPerServing,
            'protein_per_serving': item.proteinPerServing,
            'carbs_per_serving': item.carbsPerServing,
            'fat_per_serving': item.fatPerServing,
            'confidence': item.confidence,
          },
      ],
    };
  }

  static SyncRecord mealFromRow(Map<String, Object?> row) {
    final id = row['id'] as String;
    final updated = _int(row['client_updated_at']);
    if (row['deleted_at'] != null) {
      return SyncRecord(entity: SyncEntity.meal, id: id, updatedAt: updated, deleted: true);
    }
    final items = ((row['meal_items'] as List?) ?? const []).map((e) => (e as Map).cast<String, Object?>()).toList()
      ..sort((a, b) => _int(a['position']).compareTo(_int(b['position'])));
    return SyncRecord(
      entity: SyncEntity.meal,
      id: id,
      updatedAt: updated,
      json: {
        'id': id,
        'loggedAt': _time(row['logged_at']).millisecondsSinceEpoch,
        'type': row['meal_type'],
        'source': row['source'],
        'name': row['name'],
        'note': row['note'],
        'photoPath': null,
        'items': [
          for (final i in items)
            {
              'id': i['id'],
              'name': i['name'],
              'servings': _num(i['servings']),
              'servingLabel': i['serving_label'],
              'kcal': _num(i['calories_per_serving']),
              'protein': _num(i['protein_per_serving']),
              'carbs': _num(i['carbs_per_serving']),
              'fat': _num(i['fat_per_serving']),
              if (i['confidence'] != null) 'confidence': _num(i['confidence']),
            },
        ],
      },
    );
  }

  // ── profile + settings ─────────────────────────────────────────────────

  static Map<String, Object?> profilePushParams(SyncRecord r) {
    final json = r.json ?? const {};
    final profile = (json['profile'] as Map?)?.cast<String, Object?>();
    final settings = (json['settings'] as Map?)?.cast<String, Object?>() ?? const {};
    final goal = (profile?['calorieGoal'] as Map?)?.cast<String, Object?>();
    return {
      'p': {
        'has_profile': profile != null,
        'age': profile?['age'],
        'sex': profile?['sex'],
        'height_cm': profile?['heightCm'],
        'weight_kg': profile?['weightKg'],
        'goal_weight_kg': profile?['goalWeightKg'],
        'activity': profile?['activity'],
        'goal': profile?['goal'],
        'workout_days_per_week': profile?['workoutDaysPerWeek'],
        'health_considerations': profile?['health'] ?? const <String>[],
        'calorie_goal_min': goal?['min'],
        'calorie_goal_max': goal?['max'],
        'calorie_goal_custom': goal?['custom'] ?? false,
        'protein_target_g': profile?['proteinTargetG'],
        'units': settings['units'] ?? 'metric',
        'day_start_hour': settings['dayStartHour'] ?? 0,
        'onboarding_complete': settings['onboardingComplete'] ?? false,
        'client_updated_at': r.updatedAt,
      },
    };
  }

  static SyncRecord profileFromRow(Map<String, Object?> row) {
    final hasProfile = row['has_profile'] == true;
    final min = row['calorie_goal_min'];
    return SyncRecord(
      entity: SyncEntity.profile,
      id: 'me',
      updatedAt: _int(row['client_updated_at']),
      json: {
        'profile': hasProfile
            ? {
                'age': _intOrNull(row['age']),
                'sex': row['sex'],
                'heightCm': _numOrNull(row['height_cm']),
                'weightKg': _numOrNull(row['weight_kg']),
                'goalWeightKg': _numOrNull(row['goal_weight_kg']),
                'activity': row['activity'],
                'goal': row['goal'],
                'workoutDaysPerWeek': _intOrNull(row['workout_days_per_week']),
                'health': ((row['health_considerations'] as List?) ?? const []).cast<Object?>(),
                'calorieGoal': min == null
                    ? null
                    : {
                        'min': _int(min),
                        'max': _int(row['calorie_goal_max']),
                        'custom': row['calorie_goal_custom'] == true,
                      },
                'proteinTargetG': _intOrNull(row['protein_target_g']),
              }
            : null,
        'settings': {
          'units': row['units'] ?? 'metric',
          'dayStartHour': _intOrNull(row['day_start_hour']) ?? 0,
          'onboardingComplete': row['onboarding_complete'] == true,
        },
      },
    );
  }

  // ── saved foods ────────────────────────────────────────────────────────

  static Map<String, Object?> savedFoodPushParams(SyncRecord r) {
    if (r.deleted || r.json == null) {
      return {
        'p': {'id': r.id, 'deleted': true, 'client_updated_at': r.updatedAt},
      };
    }
    final food = SavedFood.fromJson(r.json!);
    return {
      'p': {
        'id': food.id,
        'name': food.item.name,
        'serving_label': food.item.servingLabel,
        'calories_per_serving': food.item.caloriesPerServing,
        'protein_per_serving': food.item.proteinPerServing,
        'carbs_per_serving': food.item.carbsPerServing,
        'fat_per_serving': food.item.fatPerServing,
        'saved_at': food.savedAt.toUtc().toIso8601String(),
        'deleted': false,
        'client_updated_at': r.updatedAt,
      },
    };
  }

  static SyncRecord savedFoodFromRow(Map<String, Object?> row) {
    final id = row['id'] as String;
    final updated = _int(row['client_updated_at']);
    if (row['deleted_at'] != null) {
      return SyncRecord(entity: SyncEntity.savedFood, id: id, updatedAt: updated, deleted: true);
    }
    return SyncRecord(
      entity: SyncEntity.savedFood,
      id: id,
      updatedAt: updated,
      json: {
        'id': id,
        'savedAt': _time(row['saved_at']).millisecondsSinceEpoch,
        'item': {
          'id': 'food-$id',
          'name': row['name'],
          'servings': 1,
          'servingLabel': row['serving_label'],
          'kcal': _num(row['calories_per_serving']),
          'protein': _num(row['protein_per_serving']),
          'carbs': _num(row['carbs_per_serving']),
          'fat': _num(row['fat_per_serving']),
        },
      },
    );
  }

  // ── scan feedback ──────────────────────────────────────────────────────

  static Map<String, Object?> feedbackPushParams(SyncRecord r) {
    if (r.deleted || r.json == null) {
      return {
        'p': {'id': r.id, 'deleted': true, 'client_updated_at': r.updatedAt},
      };
    }
    final fb = ScanFeedback.fromJson(r.json!);
    return {
      'p': {
        'id': fb.id,
        'meal_id': fb.mealId,
        'meal_summary': fb.mealSummary,
        'estimated_calories': fb.estimatedCalories,
        'rating': fb.rating.name,
        'was_demo': fb.wasDemo,
        'note': fb.note,
        'rated_at': fb.createdAt.toUtc().toIso8601String(),
        'deleted': false,
        'client_updated_at': r.updatedAt,
      },
    };
  }

  static SyncRecord feedbackFromRow(Map<String, Object?> row) {
    final id = row['id'] as String;
    final updated = _int(row['client_updated_at']);
    if (row['deleted_at'] != null) {
      return SyncRecord(entity: SyncEntity.scanFeedback, id: id, updatedAt: updated, deleted: true);
    }
    return SyncRecord(
      entity: SyncEntity.scanFeedback,
      id: id,
      updatedAt: updated,
      json: {
        'id': id,
        'mealId': row['meal_id'],
        'mealSummary': row['meal_summary'],
        'estimatedCalories': _int(row['estimated_calories']),
        'rating': row['rating'],
        'wasDemo': row['was_demo'] == true,
        'createdAt': _time(row['rated_at']).millisecondsSinceEpoch,
        'note': row['note'],
      },
    );
  }

  // ── helpers (PostgREST returns bigint/numeric as numbers or strings) ───

  static int _int(Object? v) => switch (v) {
    int i => i,
    num n => n.toInt(),
    String s => int.tryParse(s) ?? double.tryParse(s)?.toInt() ?? 0,
    _ => 0,
  };

  static int? _intOrNull(Object? v) => v == null ? null : _int(v);

  static double _num(Object? v) => switch (v) {
    num n => n.toDouble(),
    String s => double.tryParse(s) ?? 0,
    _ => 0,
  };

  static double? _numOrNull(Object? v) => v == null ? null : _num(v);

  static DateTime _time(Object? v) => DateTime.parse(v as String).toLocal();
}
