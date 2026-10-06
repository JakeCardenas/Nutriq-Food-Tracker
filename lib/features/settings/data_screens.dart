import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/app_config.dart';
import '../../app/app_scope.dart';
import '../../app/format.dart';
import '../../app/theme.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/buttons.dart';
import '../../widgets/meal_row.dart';
import '../../widgets/surfaces.dart';
import '../meal_editor/feedback_prompt.dart';

/// Foods saved without logging.
class SavedFoodsScreen extends StatelessWidget {
  const SavedFoodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final log = AppScope.of(context).log;
    return Scaffold(
      appBar: AppBar(title: const Text('My foods')),
      body: ListenableBuilder(
        listenable: log,
        builder: (context, _) {
          final foods = log.savedFoods;
          if (foods.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(NqSpace.xxxl),
                child: Text(
                  'Nothing saved yet. When reviewing a meal, tap a food and choose “Save to My foods” — '
                  'or “Save foods without logging”.',
                  style: NqText.callout,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(NqSpace.page, NqSpace.sm, NqSpace.page, NqSpace.xxxl),
            children: [
              NqGroup(
                footer: 'Saved foods appear first when you add food to a meal. Swipe left to delete.',
                children: [
                  for (final f in foods)
                    Dismissible(
                      key: ValueKey(f.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => log.deleteSavedFood(f.id),
                      background: Container(
                        color: NqColors.coral.withValues(alpha: 0.2),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_outline_rounded, color: NqColors.coral),
                      ),
                      child: NqRow(
                        title: f.item.name,
                        subtitle:
                            '${f.item.servingLabel} · P ${fmtGrams(f.item.proteinPerServing)} · '
                            'C ${fmtGrams(f.item.carbsPerServing)} · F ${fmtGrams(f.item.fatPerServing)}',
                        value: '${fmtKcal(f.item.caloriesPerServing)} kcal',
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Rate recent scans and copy a summary to share with the developer.
class ScanFeedbackScreen extends StatelessWidget {
  const ScanFeedbackScreen({super.key});

  static String summary(BuildContext context) {
    final scope = AppScope.of(context);
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    final lines = [
      '${AppConfig.appName} ${AppConfig.version} scan feedback (${scope.analysis.label})',
      for (final f in scope.log.feedback)
        '- ${fmt.format(f.createdAt)} · ${f.mealSummary} · ${f.estimatedCalories} kcal est. · '
            '${f.rating.label}${f.wasDemo ? ' · demo' : ''}${f.note == null ? '' : ' · “${f.note}”'}',
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final log = AppScope.of(context).log;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan feedback')),
      body: ListenableBuilder(
        listenable: log,
        builder: (context, _) {
          final meals = log.recentScannedMeals();
          return ListView(
            padding: const EdgeInsets.fromLTRB(NqSpace.page, NqSpace.sm, NqSpace.page, NqSpace.xxxl),
            children: [
              Text(
                'Was a scan estimate too high, about right, or too low? Your answers stay on this phone. '
                'If you’re testing Nutriq for a friend, copy the summary and send it to them.',
                style: NqText.callout,
              ),
              const SizedBox(height: NqSpace.lg),
              if (meals.isEmpty)
                const NqCard(
                  child: Text('Scan a meal first — it will show up here to rate.', style: NqText.callout),
                )
              else
                for (final m in meals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: NqSpace.md),
                    child: NqCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              MealThumb(meal: m, size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${m.title} · ${dateTimeLabel(m.loggedAt)}', style: NqText.subhead),
                                    Text(
                                      '${m.itemSummary} · ≈ ${fmtKcal(m.totals.calories)} kcal',
                                      style: NqText.footnote,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: NqSpace.md),
                          FeedbackPrompt(meal: m),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: NqSpace.md),
              SecondaryButton(
                label: 'Copy feedback summary',
                icon: Icons.copy_rounded,
                onPressed: log.feedback.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: summary(context)));
                        if (context.mounted) showToast(context, 'Copied — paste it in a message');
                      },
              ),
            ],
          );
        },
      ),
    );
  }
}
