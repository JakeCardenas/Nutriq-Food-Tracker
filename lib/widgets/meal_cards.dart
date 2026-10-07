import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/format.dart';
import '../app/theme.dart';
import '../domain/models/meal.dart';
import '../domain/models/scan_draft.dart';
import 'buttons.dart';
import 'labels.dart';
import 'pressable.dart';

/// A logged meal: photo on the left, name + time, calories and macros.
class MealCard extends StatelessWidget {
  const MealCard({super.key, required this.meal, required this.onTap});

  final Meal meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = meal.totals;
    final names = meal.items.isEmpty ? 'No foods' : meal.itemSummary;
    return Semantics(
      button: true,
      label: '${meal.title} at ${timeLabel(meal.loggedAt)}, $names, about ${fmtKcal(t.calories)} calories, estimated',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.985,
        child: Container(
          height: 104,
          decoration: BoxDecoration(
            color: NqColors.card,
            borderRadius: BorderRadius.circular(NqRadius.card),
            border: Border.all(color: NqColors.hairline),
            boxShadow: NqShadow.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              MealThumb(meal: meal, size: 104, square: true),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              meal.name?.trim().isNotEmpty ?? false ? meal.title : names,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: NqText.subhead,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _TimePill(text: timeLabel(meal.loggedAt)),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, size: 18, color: NqColors.ink),
                          const SizedBox(width: 4),
                          Text('${fmtKcal(t.calories)} kcal', style: NqText.headline),
                          if (meal.source == MealSource.demoScan) ...[const SizedBox(width: 8), const DemoBadge()],
                        ],
                      ),
                      Wrap(
                        spacing: 12,
                        children: [
                          MacroValue(macro: Macro.protein, text: '${t.protein.round()}g'),
                          MacroValue(macro: Macro.carbs, text: '${t.carbs.round()}g'),
                          MacroValue(macro: Macro.fat, text: '${t.fat.round()}g'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: NqColors.fill, borderRadius: BorderRadius.circular(999)),
    child: Text(text, style: NqText.caption.copyWith(fontSize: 11)),
  );
}

/// Meal photo, or a calm icon tile when there isn't one.
class MealThumb extends StatelessWidget {
  const MealThumb({super.key, required this.meal, this.size = 52, this.square = false});

  final Meal meal;
  final double size;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final path = meal.photoPath;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: NqColors.fill, borderRadius: square ? null : BorderRadius.circular(12)),
      child: Icon(_iconFor(meal.type), color: NqColors.textSecondary, size: size * 0.34),
    );
    if (path == null) return fallback;
    final image = Image.file(
      AppScope.of(context).photos.resolve(path),
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      errorBuilder: (_, _, _) => fallback,
    );
    return square ? image : ClipRRect(borderRadius: BorderRadius.circular(12), child: image);
  }

  static IconData _iconFor(MealType t) => switch (t) {
    MealType.breakfast => Icons.wb_twilight_rounded,
    MealType.lunch => Icons.wb_sunny_outlined,
    MealType.dinner => Icons.nights_stay_outlined,
    MealType.snack => Icons.cookie_outlined,
  };
}

/// A scan draft on Today: analyzing (with progress), ready to review, or failed.
class DraftCard extends StatelessWidget {
  const DraftCard({
    super.key,
    required this.draft,
    required this.onReview,
    required this.onRetry,
    required this.onManual,
    required this.onDiscard,
  });

  final ScanDraft draft;
  final VoidCallback onReview;
  final VoidCallback onRetry;
  final VoidCallback onManual;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final photo = AppScope.of(context).photos.resolve(draft.photoPath);
    final ready = draft.status == DraftStatus.ready;
    final failed = draft.status == DraftStatus.failed;
    // Real recognition names what it saw; the demo keeps its "estimate" wording.
    final noFood = ready && draft.items.isEmpty;
    final found = draft.items.map((i) => i.name.split(',').first).take(3).join(' · ');
    final readyTitle = noFood
        ? 'No food found'
        : draft.isDemo
        ? 'Estimate ready'
        : 'Foods found';
    final readyText = noFood
        ? 'Tap to tell Nutriq what’s in it.'
        : draft.isDemo
        ? 'Tap to check and fix the foods before logging.'
        : '$found — tap to check the amounts.';
    return Semantics(
      liveRegion: true,
      button: ready,
      label: switch (draft.status) {
        DraftStatus.analyzing => 'Analyzing your meal photo',
        DraftStatus.ready => '$readyTitle. ${readyText.replaceAll(' — tap', '. Double tap')}',
        DraftStatus.failed => 'Couldn’t analyze this photo',
      },
      child: Pressable(
        onTap: ready ? onReview : null,
        scale: 0.985,
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          decoration: BoxDecoration(
            color: NqColors.card,
            borderRadius: BorderRadius.circular(NqRadius.card),
            border: Border.all(color: NqColors.hairline),
            boxShadow: NqShadow.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 104,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        photo,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(color: NqColors.fill),
                      ),
                      if (draft.status == DraftStatus.analyzing) ...[
                        ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
                        Center(child: _AnalyzingPercent(started: draft.createdAt)),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(switch (draft.status) {
                                DraftStatus.analyzing => 'Analyzing your meal…',
                                DraftStatus.ready => readyTitle,
                                DraftStatus.failed => 'Couldn’t analyze',
                              }, style: NqText.subhead),
                            ),
                            if (draft.isDemo) const DemoBadge(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          switch (draft.status) {
                            DraftStatus.analyzing =>
                              draft.isDemo
                                  ? 'Preparing a sample estimate. Your photo stays on this phone.'
                                  : 'Looking for food on this phone — your photo stays here.',
                            DraftStatus.ready => readyText,
                            DraftStatus.failed => draft.error ?? 'Something went wrong.',
                          },
                          style: NqText.footnote,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (failed)
                          Wrap(
                            children: [
                              QuietButton(label: 'Retry', icon: Icons.refresh_rounded, onPressed: onRetry),
                              QuietButton(label: 'Log manually', onPressed: onManual),
                              QuietButton(label: 'Discard', color: NqColors.danger, onPressed: onDiscard),
                            ],
                          ),
                        if (ready)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Review →', style: NqText.subhead.copyWith(color: NqColors.ink)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Eases toward 95 % over the expected analysis time; the card flips to
/// "ready" when the real result arrives.
class _AnalyzingPercent extends StatefulWidget {
  const _AnalyzingPercent({required this.started});
  final DateTime started;

  @override
  State<_AnalyzingPercent> createState() => _AnalyzingPercentState();
}

class _AnalyzingPercentState extends State<_AnalyzingPercent> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.started).inMilliseconds / 2500;
    final progress = (1 - 1 / (1 + elapsed * 2.2)).clamp(0.0, 0.95);
    return SizedBox.square(
      dimension: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4,
            color: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
          ),
          Text(
            '${(progress * 100).round()}%',
            style: NqText.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
