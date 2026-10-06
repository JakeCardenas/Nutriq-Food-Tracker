import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/food_item.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/settings.dart';
import 'package:nutriq/domain/models/user_profile.dart';
import 'package:nutriq/services/coach/coach_service.dart';
import 'package:nutriq/services/coach/demo_coach_service.dart';
import 'package:nutriq/state/coach_controller.dart';
import 'package:nutriq/state/meal_log_controller.dart';
import 'package:nutriq/state/profile_controller.dart';

import '../support/memory_local_store.dart';

const _egg = FoodItem(id: 'e', name: 'Eggs', caloriesPerServing: 180, proteinPerServing: 12);

Meal _meal(String id, DateTime at, {String? photo}) => Meal(
  id: id,
  loggedAt: at,
  type: MealType.snack,
  source: photo == null ? MealSource.manual : MealSource.demoScan,
  photoPath: photo,
  items: const [_egg],
);

void main() {
  group('MealLogController', () {
    late MemoryLocalStore store;
    late MealLogController log;
    late List<String> deletedPhotos;
    var dayStart = 4;

    setUp(() async {
      store = MemoryLocalStore();
      deletedPhotos = [];
      dayStart = 4;
      log = MealLogController(store, dayStartHour: () => dayStart, deletePhoto: (p) async => deletedPhotos.add(p));
      await log.load();
    });

    test('a 2:30 AM meal counts toward the previous day when the day starts at 4 AM', () async {
      await log.saveMeal(_meal('late', DateTime(2026, 10, 7, 2, 30)));
      expect(log.mealsForDay(DateTime(2026, 10, 6)).map((m) => m.id), ['late']);
      expect(log.mealsForDay(DateTime(2026, 10, 7)), isEmpty);

      dayStart = 0;
      expect(log.mealsForDay(DateTime(2026, 10, 7)).map((m) => m.id), ['late']);
    });

    test('changing a meal time moves it to another day and persists', () async {
      final m = _meal('m', DateTime(2026, 10, 6, 12));
      await log.saveMeal(m);
      await log.saveMeal(m.copyWith(loggedAt: DateTime(2026, 10, 5, 12)));
      expect(log.mealsForDay(DateTime(2026, 10, 6)), isEmpty);
      expect(log.mealsForDay(DateTime(2026, 10, 5)).single.id, 'm');
      expect((await store.allMeals()).single.loggedAt, DateTime(2026, 10, 5, 12));
    });

    test('totals and 7-day summaries', () async {
      await log.saveMeal(_meal('a', DateTime(2026, 10, 6, 9)));
      await log.saveMeal(_meal('b', DateTime(2026, 10, 6, 13)));
      expect(log.totalsForDay(DateTime(2026, 10, 6)).calories, 360);
      final week = log.summariesEnding(DateTime(2026, 10, 6));
      expect(week.length, 7);
      expect(week.last.mealCount, 2);
      expect(week.first.day, DateTime(2026, 9, 30));
    });

    test('deleting a meal removes its photo file', () async {
      await log.saveMeal(_meal('p', DateTime(2026, 10, 6, 9), photo: 'meal_photos/p.jpg'));
      await log.deleteMeal(log.meals.single);
      expect(log.meals, isEmpty);
      expect(deletedPhotos, ['meal_photos/p.jpg']);
    });

    test('saving a food without logging adds to My foods only', () async {
      await log.saveFood(_egg.copyWith(servings: 2));
      expect(log.meals, isEmpty);
      expect(log.savedFoods.single.item.name, 'Eggs');
      expect(log.savedFoods.single.item.servings, 1);
    });

    test('recent foods are distinct by name, newest first', () async {
      await log.saveMeal(_meal('a', DateTime(2026, 10, 5, 9)));
      await log.saveMeal(
        _meal('b', DateTime(2026, 10, 6, 9)).copyWith(
          items: [
            _egg,
            _egg.copyWith(id: 'x', name: 'Toast'),
          ],
        ),
      );
      expect(log.recentFoods().map((f) => f.name), ['Eggs', 'Toast']);
    });
  });

  group('ProfileController', () {
    test('completing onboarding persists profile and flag', () async {
      final store = MemoryLocalStore();
      final c = ProfileController(store);
      await c.load();
      expect(c.settings.onboardingComplete, isFalse);
      await c.completeOnboarding(const UserProfile(age: 30));
      expect(c.settings.onboardingComplete, isTrue);
      expect((await store.loadProfile())!.age, 30);
      expect((await store.loadSettings()).onboardingComplete, isTrue);
    });

    test('clearing the profile keeps meals and onboarding state', () async {
      final store = MemoryLocalStore(
        profile: const UserProfile(age: 30),
        settings: const AppSettings(onboardingComplete: true),
        meals: [_meal('a', DateTime(2026, 10, 6))],
      );
      final c = ProfileController(store);
      await c.load();
      await c.clearProfile();
      expect(c.profile, isNull);
      expect(c.settings.onboardingComplete, isTrue);
      expect(await store.allMeals(), isNotEmpty);
    });

    test('reset returns to first launch', () async {
      final store = MemoryLocalStore(
        profile: const UserProfile(age: 30),
        settings: const AppSettings(onboardingComplete: true, dayStartHour: 4),
      );
      final c = ProfileController(store);
      await c.load();
      await c.resetAll();
      expect(c.profile, isNull);
      expect(c.settings, const AppSettings());
    });
  });

  group('ProfileController calorie goal (regression: floor must hold when saving)', () {
    const adult = UserProfile(
      age: 30,
      sex: SexForEstimate.male,
      heightCm: 180,
      weightKg: 80,
      activity: ActivityLevel.moderate,
    );

    test('a range below max(1,200, resting energy) is refused and nothing changes', () async {
      final c = ProfileController(MemoryLocalStore(profile: adult));
      await c.load();
      await expectLater(
        c.setCalorieGoal(const CalorieRange(min: 1500, max: 2000)),
        throwsA(isA<CalorieGoalRejected>()),
      );
      expect(c.profile!.calorieGoal, isNull);
    });

    test('a range at or above the floor is saved', () async {
      final c = ProfileController(MemoryLocalStore(profile: adult));
      await c.load();
      await c.setCalorieGoal(const CalorieRange(min: 1800, max: 2200));
      expect(c.profile!.calorieGoal!.min, 1800);
    });

    test('minors cannot save a calorie goal at all', () async {
      final c = ProfileController(MemoryLocalStore(profile: const UserProfile(age: 16)));
      await c.load();
      await expectLater(
        c.setCalorieGoal(const CalorieRange(min: 2000, max: 2200)),
        throwsA(isA<CalorieGoalRejected>()),
      );
    });
  });

  group('CoachController', () {
    test('send appends user then coach message', () async {
      final c = CoachController(
        DemoCoachService(replyDelay: Duration.zero),
        () => CoachContext(
          profile: null,
          today: _egg.totals,
          todayMealCount: 1,
          recentDays: const [],
          now: DateTime(2026, 10, 6, 12),
        ),
      );
      await c.send('How am I doing with my protein today?');
      expect(c.messages.map((m) => m.role), [ChatRole.user, ChatRole.coach]);
      expect(c.messages.last.isDemo, isTrue);
      expect(c.isReplying, isFalse);
    });

    test('prefill sets the draft without sending', () {
      final c = CoachController(DemoCoachService(replyDelay: Duration.zero), () => throw StateError(''));
      c.prefill(CoachPrompts.week);
      expect(c.draft, CoachPrompts.week);
      expect(c.messages, isEmpty);
    });

    test('blank messages are ignored', () async {
      final c = CoachController(DemoCoachService(replyDelay: Duration.zero), () => throw StateError(''));
      await c.send('   ');
      expect(c.messages, isEmpty);
    });
  });
}
