import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/format.dart';
import '../app/theme.dart';
import '../domain/models/meal.dart';

/// A meal in a list: thumbnail, type + time, foods, calories.
class MealRow extends StatelessWidget {
  const MealRow({super.key, required this.meal, required this.onTap});

  final Meal meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kcal = fmtKcal(meal.totals.calories);
    return Semantics(
      button: true,
      label: '${meal.title} at ${timeLabel(meal.loggedAt)}, ${meal.itemSummary}, about $kcal calories',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              MealThumb(meal: meal, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${meal.title} · ${timeLabel(meal.loggedAt)}', style: NqText.headline),
                    const SizedBox(height: 3),
                    Text(
                      meal.items.isEmpty ? 'No foods' : meal.itemSummary,
                      style: NqText.footnote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(kcal, style: NqText.numberSmall.copyWith(fontSize: 17)),
                  Text('kcal est.', style: NqText.caption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Meal photo, or a calm icon tile when there isn't one.
class MealThumb extends StatelessWidget {
  const MealThumb({super.key, required this.meal, this.size = 52});

  final Meal meal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = meal.photoPath;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: NqColors.raised, borderRadius: BorderRadius.circular(12)),
      child: Icon(_iconFor(meal.type), color: NqColors.textSecondary, size: size * 0.44),
    );
    if (path == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        AppScope.of(context).photos.resolve(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  static IconData _iconFor(MealType t) => switch (t) {
    MealType.breakfast => Icons.wb_twilight_rounded,
    MealType.lunch => Icons.wb_sunny_outlined,
    MealType.dinner => Icons.nights_stay_outlined,
    MealType.snack => Icons.cookie_outlined,
  };
}
