import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/app/session.dart';
import 'package:nutriq/data/cloud_repository.dart';
import 'package:nutriq/data/sync_models.dart';
import 'package:nutriq/domain/models/food_item.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/settings.dart';
import 'package:nutriq/domain/models/user_profile.dart';
import 'package:nutriq/services/auth/auth_service.dart';
import 'package:nutriq/services/coach/demo_coach_service.dart';
import 'package:nutriq/services/food_analysis/demo_food_analysis_service.dart';
import 'package:nutriq/services/health/health_service.dart';
import 'package:nutriq/state/session_controller.dart';

import '../support/fake_auth.dart';
import '../support/fake_cloud.dart';
import '../support/memory_local_store.dart';
import '../support/test_app.dart';

Meal _meal(String id) => Meal(
  id: id,
  loggedAt: DateTime(2026, 10, 6, 12),
  type: MealType.lunch,
  source: MealSource.manual,
  items: const [FoodItem(id: 'f', name: 'Rice', caloriesPerServing: 200)],
);

const _alice = AuthUser(id: 'alice', email: 'a@example.com', providers: ['email']);
const _bob = AuthUser(id: 'bob', email: 'b@example.com', providers: ['email']);

void main() {
  late FakeAuthService auth;
  late Map<String, MemoryLocalStore> files;
  late Map<String, FakeCloud> clouds;
  late Map<String, FakePhotoService> photos;
  late SessionController sessions;

  MemoryLocalStore file(String key) => files.putIfAbsent(key, () => MemoryLocalStore(tracksChanges: key != 'local'));

  setUp(() async {
    auth = FakeAuthService();
    files = {};
    clouds = {};
    photos = {};
    final services = SessionServices(
      analysis: DemoFoodAnalysisService(delay: Duration.zero),
      coach: DemoCoachService(replyDelay: Duration.zero),
      health: const UnsupportedHealthService(),
    );
    sessions = SessionController(
      auth: auth,
      buildSession: (user) => assembleSession(
        user: user,
        store: file(user?.id ?? 'local'),
        photos: photos[user?.id ?? 'local'] = FakePhotoService(),
        cloud: user == null ? null : clouds.putIfAbsent(user.id, FakeCloud.new),
        services: services,
        syncDebounce: Duration.zero,
      ),
      openLocalStore: () async => file('local'),
      localPhotos: FakePhotoService(),
    );
    await sessions.start();
  });

  tearDown(() => sessions.dispose());

  test('a restarted session gets a fresh key, so no screen from before survives', () async {
    final before = sessions.session!.key;
    await sessions.restartSession();
    await sessions.settle();
    expect(sessions.session!.mode, SessionMode.local);
    expect(sessions.session!.key, isNot(before));
  });

  test('starts in local-only mode when nobody is signed in', () {
    expect(sessions.session!.mode, SessionMode.local);
    expect(sessions.session!.sync, isNull);
  });

  test('signing in switches to that account’s own file and closes the previous one', () async {
    auth.signIn(_alice);
    await sessions.settle();
    expect(sessions.session!.mode, SessionMode.account);
    expect(sessions.session!.user!.id, 'alice');
    expect(files['local']!.closed, isTrue);
    expect(sessions.session!.sync, isNotNull);
  });

  test('accounts never see each other’s meals', () async {
    auth.signIn(_alice);
    await sessions.settle();
    await sessions.session!.log.saveMeal(_meal('alice-lunch'));

    await auth.signOut();
    await sessions.settle();
    expect(sessions.session!.mode, SessionMode.local);
    expect(sessions.session!.log.meals, isEmpty);

    auth.signIn(_bob);
    await sessions.settle();
    expect(sessions.session!.log.meals, isEmpty);

    auth.signIn(_alice);
    await sessions.settle();
    expect(sessions.session!.log.meals.single.id, 'alice-lunch');
  });

  test('local-only data is offered for import, explicitly, once', () async {
    await sessions.session!.log.saveMeal(_meal('local-1'));
    await sessions.session!.profile.completeOnboarding(const UserProfile(age: 30));

    auth.signIn(_alice);
    await sessions.settle();
    final offer = sessions.importOffer!;
    expect(offer.meals, 1);
    expect(offer.hasProfile, isTrue);
    expect(sessions.session!.log.meals, isEmpty, reason: 'nothing uploads before the person agrees');

    final result = await sessions.acceptImport();
    expect(result.meals, 1);
    expect(sessions.importOffer, isNull);
    expect(sessions.session!.log.meals.single.id, 'local-1');
    await sessions.session!.sync!.syncNow();
    expect(clouds['alice']!.count(SyncEntity.meal), 1);
    expect((await files['local']!.allMeals()).single.id, 'local-1', reason: 'local copy kept');

    await auth.signOut();
    await sessions.settle();
    auth.signIn(_alice);
    await sessions.settle();
    expect(sessions.importOffer, isNull, reason: 'already imported');
  });

  test('declining the import is remembered for that account', () async {
    await sessions.session!.log.saveMeal(_meal('local-1'));
    auth.signIn(_alice);
    await sessions.settle();
    await sessions.declineImport();
    expect(sessions.importOffer, isNull);

    await auth.signOut();
    await sessions.settle();
    auth.signIn(_alice);
    await sessions.settle();
    expect(sessions.importOffer, isNull);
    expect(await sessions.localImportSummary(), isNotNull, reason: 'still available from Settings');
  });

  test('creating an account at the end of onboarding imports with consent', () async {
    await sessions.session!.profile.completeOnboarding(const UserProfile(age: 30));
    sessions.expectImportConsent();
    auth.signIn(_alice);
    await sessions.settle();
    expect(sessions.importOffer, isNull);
    expect(sessions.session!.profile.profile!.age, 30);
    expect(sessions.session!.profile.settings.onboardingComplete, isTrue);
  });

  test('a sign-in method linked automatically by email is announced, not silent', () async {
    auth.signIn(_alice);
    await sessions.settle();
    expect(sessions.linkNotice, isNull);
    await auth.signOut();
    await sessions.settle();

    auth.signIn(const AuthUser(id: 'alice', email: 'a@example.com', providers: ['email', 'google']));
    await sessions.settle();
    expect(sessions.linkNotice, contains('Google'));
  });

  test('a method linked in the app does not trigger the notice', () async {
    auth.signIn(_alice);
    await sessions.settle();
    sessions.markLinkedInApp('apple');
    auth.emit(const AuthEvent(AuthEventType.userUpdated, AuthUser(id: 'alice', providers: ['email', 'apple'])));
    await sessions.settle();
    expect(sessions.linkNotice, isNull);
  });

  test('a password-reset link opens the new-password step', () async {
    auth.emit(const AuthEvent(AuthEventType.passwordRecovery, _alice));
    await sessions.settle();
    expect(sessions.passwordRecovery, isTrue);
    sessions.clearPasswordRecovery();
    expect(sessions.passwordRecovery, isFalse);
  });

  test('pending changes are counted before signing out', () async {
    auth.signIn(_alice);
    await sessions.settle();
    clouds['alice']!.offline = true;
    await sessions.session!.log.saveMeal(_meal('offline-meal'));
    expect(await sessions.pendingChanges(), greaterThan(0));
  });

  test('onboarding state comes from the account on a new device', () async {
    files['alice'] = MemoryLocalStore(tracksChanges: true, settings: const AppSettings(onboardingComplete: true));
    auth.signIn(_alice);
    await sessions.settle();
    expect(sessions.session!.profile.settings.onboardingComplete, isTrue);
  });

  group('deleting data is truthful', () {
    Future<void> signInWithMeal() async {
      auth.signIn(_alice);
      await sessions.settle();
      await sessions.session!.log.saveMeal(_meal('alice-lunch'));
      await sessions.session!.sync!.syncNow();
      expect(clouds['alice']!.rows[SyncEntity.meal], isNotEmpty);
    }

    test('deleting cloud data removes it from the server and this phone, but keeps the account', () async {
      await signInWithMeal();
      final alicePhotos = photos['alice']!;
      await sessions.deleteCloudData();
      await sessions.settle();
      expect(clouds['alice']!.rows[SyncEntity.meal], isEmpty);
      expect(clouds['alice']!.deletedAccount, isFalse);
      expect(sessions.session!.user!.id, 'alice');
      expect(sessions.session!.log.meals, isEmpty);
      expect(alicePhotos.deletedAll, isTrue);
    });

    test('deleting the account removes it on the server, wipes this phone’s copy and signs out', () async {
      await signInWithMeal();
      await sessions.deleteAccount();
      await sessions.settle();
      expect(clouds['alice']!.deletedAccount, isTrue);
      expect(sessions.session!.mode, SessionMode.local);
      expect(auth.currentUser, isNull);
      expect(await files['alice']!.allMeals(), isEmpty);
    });

    test('when the delete-account function isn’t deployed, nothing is deleted and the error surfaces', () async {
      await signInWithMeal();
      clouds['alice']!.accountFunctionMissing = true;
      await expectLater(sessions.deleteAccount(), throwsA(isA<CloudNotConfiguredException>()));
      await sessions.settle();
      expect(sessions.session!.user!.id, 'alice');
      expect(sessions.session!.log.meals, hasLength(1));
      expect(clouds['alice']!.rows[SyncEntity.meal], isNotEmpty);
    });

    test('offline: deleting cloud data fails without touching this phone', () async {
      await signInWithMeal();
      clouds['alice']!.offline = true;
      await expectLater(sessions.deleteCloudData(), throwsA(isA<CloudOfflineException>()));
      expect(sessions.session!.log.meals, hasLength(1));
    });

    test('removing the account from this phone keeps cloud data and signs out', () async {
      await signInWithMeal();
      await sessions.removeAccountFromPhone();
      await sessions.settle();
      expect(sessions.session!.mode, SessionMode.local);
      expect(await files['alice']!.allMeals(), isEmpty);
      expect(clouds['alice']!.rows[SyncEntity.meal], isNotEmpty);
    });

    test('local-only mode: deleting this phone’s data returns to onboarding', () async {
      await sessions.session!.profile.completeOnboarding(const UserProfile(age: 30));
      await sessions.session!.log.saveMeal(_meal('local-lunch'));
      final localPhotos = photos['local']!;
      await sessions.deleteLocalData();
      await sessions.settle();
      expect(sessions.session!.mode, SessionMode.local);
      expect(sessions.session!.log.meals, isEmpty);
      expect(sessions.session!.profile.settings.onboardingComplete, isFalse);
      expect(localPhotos.deletedAll, isTrue);
    });
  });

  group('keeping devices in step', () {
    test('an account still signed in at launch pulls changes from other devices right away', () async {
      final server = clouds.putIfAbsent('alice', FakeCloud.new)
        ..serverWrite(SyncEntity.meal, 'from-ipad', _meal('from-ipad').toJson(), 5000);
      final restored = SessionController(
        auth: FakeAuthService(current: _alice),
        buildSession: (user) => assembleSession(
          user: user,
          store: file(user?.id ?? 'local'),
          photos: FakePhotoService(),
          cloud: user == null ? null : server,
          services: SessionServices(
            analysis: DemoFoodAnalysisService(delay: Duration.zero),
            coach: DemoCoachService(replyDelay: Duration.zero),
            health: const UnsupportedHealthService(),
          ),
          syncDebounce: Duration.zero,
        ),
        openLocalStore: () async => file('local'),
        localPhotos: FakePhotoService(),
      );
      addTearDown(restored.dispose);
      await restored.start();
      await restored.settle();
      // No edits and no manual sync: the launch itself must trigger the pull.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(restored.session!.log.meals.map((m) => m.id), ['from-ipad']);
    });

    test('returning to the app pulls changes made elsewhere', () async {
      auth.signIn(_alice);
      await sessions.settle();
      await sessions.session!.sync!.syncNow();
      expect(sessions.session!.log.meals, isEmpty);

      clouds['alice']!.serverWrite(SyncEntity.meal, 'from-ipad', _meal('from-ipad').toJson(), 5000);
      await sessions.appResumed();
      expect(sessions.session!.log.meals.map((m) => m.id), ['from-ipad']);
    });

    test('returning to the app in local-only mode does nothing', () async {
      await sessions.appResumed();
      expect(sessions.session!.sync, isNull);
    });
  });
}
