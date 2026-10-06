import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../domain/ids.dart';
import '../../domain/models/meal.dart';
import '../../domain/models/scan_feedback.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import 'food_item_form.dart';

/// "How did this estimate look?" — too high / about right / too low + note.
/// Stored on the device only; testers can copy it from Settings.
class FeedbackPrompt extends StatelessWidget {
  const FeedbackPrompt({super.key, required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final log = AppScope.of(context).log;
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        final current = log.feedbackFor(meal.id);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChoiceChips<FeedbackRating>(
              options: FeedbackRating.values,
              selected: current?.rating,
              labelOf: (r) => r.label,
              onSelected: (r) => _save(context, r, current?.note),
            ),
            if (current != null)
              QuietButton(
                label: current.note == null ? 'Add a note' : 'Edit note',
                icon: Icons.notes_rounded,
                onPressed: () => _editNote(context, current),
              ),
          ],
        );
      },
    );
  }

  Future<void> _save(BuildContext context, FeedbackRating rating, String? note) async {
    await AppScope.of(context).log.addFeedback(
      ScanFeedback(
        id: newId(),
        mealId: meal.id,
        mealSummary: meal.itemSummary,
        estimatedCalories: meal.totals.calories.round(),
        rating: rating,
        wasDemo: meal.source == MealSource.demoScan,
        createdAt: DateTime.now(),
        note: note,
      ),
    );
    if (context.mounted) showToast(context, 'Thanks — saved on this device.');
  }

  Future<void> _editNote(BuildContext context, ScanFeedback current) async {
    final controller = TextEditingController(text: current.note ?? '');
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SheetBody(
        title: 'Add a note',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              maxLength: 300,
              decoration: const InputDecoration(hintText: 'e.g. “Rice portion was smaller”'),
            ),
            const SizedBox(height: NqSpace.md),
            PrimaryButton(
              label: 'Save note',
              height: 52,
              onPressed: () => Navigator.pop(context, controller.text.trim()),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (note == null || !context.mounted) return;
    await _save(context, current.rating, note.isEmpty ? null : note);
  }
}
