import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_scope.dart';
import 'app/nutriq_app.dart';
import 'app/theme.dart';
import 'data/sqlite_local_store.dart';
import 'services/coach/demo_coach_service.dart';
import 'services/food_analysis/demo_food_analysis_service.dart';
import 'services/photo_service.dart';
import 'state/coach_controller.dart';
import 'state/meal_log_controller.dart';
import 'state/profile_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const _Bootstrap());
}

/// Opens local storage, then starts the app. Shows a retry screen instead of
/// crashing if storage can't be opened.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<AppScope Function(Widget)> _ready = _init();

  Future<AppScope Function(Widget)> _init() async {
    final store = await SqliteLocalStore.open();
    final photos = await DevicePhotoService.create();
    final profile = ProfileController(store);
    final log = MealLogController(
      store,
      dayStartHour: () => profile.settings.dayStartHour,
      deletePhoto: photos.delete,
    );
    await profile.load();
    await log.load();

    // Demo implementations. To connect real services, implement
    // FoodAnalysisService / CoachService against your own backend and swap
    // them in here. Never ship AI-provider keys inside the app.
    final analysis = DemoFoodAnalysisService();
    final coach = CoachController(DemoCoachService(), CoachController.contextFrom(profile, log));

    return (child) =>
        AppScope(profile: profile, log: log, coach: coach, analysis: analysis, photos: photos, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasData) return snapshot.data!(const NutriqApp());
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildNutriqTheme(),
          home: Scaffold(
            body: Center(
              child: snapshot.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Couldn’t open your data', style: NqText.title),
                          const SizedBox(height: 8),
                          Text('${snapshot.error}', style: NqText.footnote, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => setState(() => _ready = _init()),
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
