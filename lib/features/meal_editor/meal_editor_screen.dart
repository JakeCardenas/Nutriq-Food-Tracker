import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../app/format.dart';
import '../../app/theme.dart';
import '../../domain/day_boundary.dart';
import '../../domain/ids.dart';
import '../../domain/models/food_item.dart';
import '../../domain/models/meal.dart';
import '../../domain/models/nutrition.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/labels.dart';
import '../../widgets/pressable.dart';
import '../../widgets/surfaces.dart';
import 'add_food_sheet.dart';
import 'feedback_prompt.dart';
import 'food_item_form.dart';

/// What the editor did, for the caller's confirmation toast.
class EditorResult {
  const EditorResult(this.message, {this.mealSaved = false});
  final String message;

  /// False when only foods were saved (or the meal was deleted).
  final bool mealSaved;
}

/// One editor for every meal: reviewing a scan, adding manually, or editing
/// a saved meal. Pops with an [EditorResult], or null when cancelled.
class MealEditorScreen extends StatefulWidget {
  const MealEditorScreen({
    super.key,
    this.existing,
    this.initialItems = const [],
    this.photoPath,
    this.source = MealSource.manual,
    this.demoSampleName,
    this.openAddFood = false,
    this.emptyResult = false,
    this.initialLoggedAt,
  });

  /// Opens an existing meal for editing.
  MealEditorScreen.edit(Meal meal, {Key? key})
    : this(
        key: key,
        existing: meal,
        initialItems: meal.items,
        photoPath: meal.photoPath,
        source: meal.source,
      );

  final Meal? existing;
  final List<FoodItem> initialItems;
  final String? photoPath;
  final MealSource source;
  final String? demoSampleName;
  final bool openAddFood;

  /// True when analysis returned no foods — shows "add what you ate".
  final bool emptyResult;

  /// Pre-set date/time for a new meal (e.g. adding to a past day from History).
  final DateTime? initialLoggedAt;

  @override
  State<MealEditorScreen> createState() => _MealEditorScreenState();
}

class _MealEditorScreenState extends State<MealEditorScreen> {
  late List<FoodItem> _items = [...widget.initialItems];
  late DateTime _loggedAt = widget.existing?.loggedAt ?? widget.initialLoggedAt ?? DateTime.now();
  late MealType _type = widget.existing?.type ?? MealType.suggestFor(_loggedAt);
  bool _typeTouched = false;
  bool _changed = false;
  bool _saving = false;

  bool get _isNew => widget.existing == null;
  bool get _isDemo => widget.source == MealSource.demoScan;
  bool get _dirty => _changed || (_isNew && _items.isNotEmpty);

  @override
  void initState() {
    super.initState();
    if (widget.openAddFood) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _addFood(startManual: _hasNoSuggestions()));
    }
  }

  bool _hasNoSuggestions() {
    final log = AppScope.of(context).log;
    return log.savedFoods.isEmpty && log.recentFoods(limit: 1).isEmpty;
  }

  void _update(VoidCallback change) => setState(() {
    change();
    _changed = true;
  });

  Future<void> _addFood({bool startManual = false}) async {
    final item = await showAddFoodSheet(context, startManual: startManual);
    if (item != null) _update(() => _items = [..._items, item]);
  }

  Future<void> _editItem(FoodItem item) async {
    final log = AppScope.of(context).log;
    final result = await showFoodItemSheet(context, item: item, onSaveToMyFoods: log.saveFood);
    if (result == null) return;
    switch (result.action) {
      case FoodSheetAction.update:
        _update(() => _items = [for (final i in _items) i.id == item.id ? result.item! : i]);
      case FoodSheetAction.remove:
        _remove(item);
    }
  }

  void _remove(FoodItem item) {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index < 0) return;
    _update(() => _items = [..._items]..removeAt(index));
    showToast(
      context,
      'Removed ${item.name}',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          if (!mounted) return;
          _update(() => _items = [..._items]..insert(index.clamp(0, _items.length), item));
        },
      ),
    );
  }

  /// "Today · 12:44 PM", "Yesterday · 9:10 PM" or "Mon, Oct 5 · 9:10 PM".
  String _whenLabel(DateTime t) {
    final now = DateTime.now();
    final label = dayLabel(t, now);
    return label == 'Today' || label == 'Yesterday' ? '$label · ${timeLabel(t)}' : dateTimeLabel(t);
  }

  Future<void> _pickTime() async {
    final picked = await pickDateTime(context, _loggedAt);
    if (picked == null) return;
    _update(() {
      _loggedAt = picked;
      if (!_typeTouched) _type = MealType.suggestFor(picked);
    });
  }

  Future<void> _save() async {
    if (_items.isEmpty || _saving) return;
    setState(() => _saving = true);
    final log = AppScope.of(context).log;
    final meal = Meal(
      id: widget.existing?.id ?? newId(),
      loggedAt: _loggedAt,
      type: _type,
      source: widget.source,
      items: _items,
      photoPath: widget.photoPath,
      note: widget.existing?.note,
    );
    await log.saveMeal(meal);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    final day = log.dayOf(meal);
    final today = log.today();
    final where = day == today ? 'today' : dayLabel(day, today);
    Navigator.pop(
      context,
      EditorResult(
        _isNew ? 'Meal saved to ${where == 'Yesterday' ? 'yesterday' : where}' : 'Changes saved',
        mealSaved: true,
      ),
    );
  }

  Future<void> _saveFoodsOnly() async {
    final log = AppScope.of(context).log;
    for (final item in _items) {
      await log.saveFood(item);
    }
    if (!mounted) return;
    final n = _items.length;
    Navigator.pop(context, EditorResult('$n ${n == 1 ? 'food' : 'foods'} saved to My foods — not logged'));
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: 'Delete this meal?',
      message: 'It will be removed from your log${widget.photoPath != null ? ', along with its photo' : ''}.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    await AppScope.of(context).log.deleteMeal(widget.existing!);
    if (mounted) Navigator.pop(context, const EditorResult('Meal deleted'));
  }

  Future<void> _confirmDiscard() async {
    final ok = await confirmAction(
      context,
      title: _isNew ? 'Discard this meal?' : 'Discard changes?',
      message: _isNew ? 'Nothing will be saved to your log.' : 'Your edits to this meal will be lost.',
      confirmLabel: 'Discard',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final totals = NutritionTotals.sum(_items.map((i) => i.totals));
    final title = widget.existing != null
        ? 'Meal'
        : widget.source == MealSource.manual
        ? 'Add meal'
        : 'Review estimate';

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _dirty ? _confirmDiscard() : Navigator.pop(context),
          ),
          actions: [
            if (!_isNew)
              IconButton(
                tooltip: 'Delete meal',
                icon: const Icon(Icons.delete_outline_rounded, color: NqColors.coral),
                onPressed: _delete,
              ),
          ],
        ),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(NqSpace.page, NqSpace.sm, NqSpace.page, NqSpace.xxxl),
          children: [
            if (_isDemo) ...[
              NoticeCard(
                icon: Icons.science_outlined,
                title: 'Demo result — not from your photo',
                message:
                    'Nutriq showed a sample meal${widget.demoSampleName == null ? '' : ' (“${widget.demoSampleName}”)'} '
                    'so you can try the flow. It didn’t analyze your photo. Edit the foods to match what you ate.',
              ),
              const SizedBox(height: NqSpace.lg),
            ],
            if (widget.emptyResult) ...[
              const NoticeCard(
                icon: Icons.search_off_rounded,
                title: 'No foods suggested',
                message: 'We couldn’t suggest foods for this photo. Add what you ate below.',
              ),
              const SizedBox(height: NqSpace.lg),
            ],
            if (widget.photoPath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(NqRadius.card),
                child: AspectRatio(
                  aspectRatio: 2,
                  child: Image.file(
                    AppScope.of(context).photos.resolve(widget.photoPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: NqColors.raised,
                      child: Center(
                        child: Icon(Icons.image_not_supported_outlined, color: NqColors.textTertiary),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NqSpace.lg),
            ],
            _TotalsCard(totals: totals),
            SectionHeader(
              'Foods',
              trailing: QuietButton(label: 'Add food', icon: Icons.add_rounded, onPressed: _addFood),
            ),
            if (_items.isEmpty)
              NqCard(
                child: Column(
                  children: [
                    const Text('No foods yet', style: NqText.headline),
                    const SizedBox(height: 4),
                    Text(
                      'Add what you ate — search your foods or enter it manually.',
                      style: NqText.footnote,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NqSpace.md),
                    SecondaryButton(
                      label: 'Add food',
                      icon: Icons.add_rounded,
                      height: 48,
                      onPressed: _addFood,
                    ),
                  ],
                ),
              )
            else
              for (final item in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: NqSpace.sm),
                  child: Dismissible(
                    key: ValueKey(item.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _remove(item),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      decoration: BoxDecoration(
                        color: NqColors.coral.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(NqRadius.card),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: NqColors.coral),
                    ),
                    child: _FoodCard(
                      item: item,
                      onTap: () => _editItem(item),
                      onServings: (v) => _update(
                        () =>
                            _items = [for (final i in _items) i.id == item.id ? i.copyWith(servings: v) : i],
                      ),
                    ),
                  ),
                ),
            if (_items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Tap a food to rename it or fix its nutrition. Swipe left to remove.',
                  style: NqText.caption,
                ),
              ),
            const SectionHeader('When'),
            NqGroup(
              children: [
                NqRow(
                  icon: Icons.schedule_rounded,
                  title: 'Date & time',
                  value: _whenLabel(_loggedAt),
                  onTap: _pickTime,
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: ChoiceChips<MealType>(
                    options: MealType.values,
                    selected: _type,
                    labelOf: (t) => t.label,
                    onSelected: (t) => _update(() {
                      _type = t;
                      _typeTouched = true;
                    }),
                  ),
                ),
              ],
            ),
            _DayHint(loggedAt: _loggedAt),
            if (!_isNew && widget.existing!.source != MealSource.manual) ...[
              const SectionHeader('How did this estimate look?'),
              FeedbackPrompt(meal: widget.existing!),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(NqSpace.page, NqSpace.sm, NqSpace.page, NqSpace.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PrimaryButton(
                  label: _isNew ? 'Save to log' : 'Save changes',
                  icon: Icons.check_rounded,
                  busy: _saving,
                  onPressed: _items.isEmpty ? null : _save,
                ),
                if (_isNew && _items.isNotEmpty)
                  QuietButton(
                    label: 'Save foods without logging',
                    color: NqColors.textSecondary,
                    onPressed: _saveFoodsOnly,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals});

  final NutritionTotals totals;

  @override
  Widget build(BuildContext context) => NqCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Estimated total', style: NqText.footnote)),
            const EstimateBadge(),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(fmtKcal(totals.calories), style: NqText.heroNumber.copyWith(fontSize: 40)),
              ),
            ),
            const SizedBox(width: 6),
            Text('kcal', style: NqText.callout),
          ],
        ),
        const SizedBox(height: NqSpace.md),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            LegendDot(color: NqColors.protein, label: 'Protein ${fmtGrams(totals.protein)}'),
            LegendDot(color: NqColors.carbs, label: 'Carbs ${fmtGrams(totals.carbs)}'),
            LegendDot(color: NqColors.fat, label: 'Fat ${fmtGrams(totals.fat)}'),
          ],
        ),
        const SizedBox(height: NqSpace.md),
        Text(
          'Photo estimates can miss oils, sauces and portion sizes — check each item.',
          style: NqText.caption,
        ),
      ],
    ),
  );
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.item, required this.onTap, required this.onServings});

  final FoodItem item;
  final VoidCallback onTap;
  final ValueChanged<double> onServings;

  @override
  Widget build(BuildContext context) {
    final t = item.totals;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      semanticLabel: 'Edit ${item.name}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        decoration: BoxDecoration(
          color: NqColors.surface,
          borderRadius: BorderRadius.circular(NqRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text(item.name, style: NqText.headline)),
                const SizedBox(width: 8),
                Text(fmtKcal(t.calories), style: NqText.numberSmall.copyWith(fontSize: 17)),
                Text(' kcal', style: NqText.footnote),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${item.servingLabel} · P ${fmtGrams(t.protein)} · C ${fmtGrams(t.carbs)} · F ${fmtGrams(t.fat)}',
              style: NqText.footnote,
            ),
            if (item.isLowConfidence) ...[
              const SizedBox(height: 6),
              const EstimateBadge(label: 'Low confidence — check this'),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                StepperControl(value: item.servings, onChanged: onServings, suffix: '×'),
                const SizedBox(width: 10),
                Text('servings', style: NqText.footnote),
                const Spacer(),
                const Icon(Icons.edit_outlined, size: 18, color: NqColors.textTertiary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Explains which day a late-night meal counts toward.
class _DayHint extends StatelessWidget {
  const _DayHint({required this.loggedAt});

  final DateTime loggedAt;

  @override
  Widget build(BuildContext context) {
    final log = AppScope.of(context).log;
    final start = log.dayStartHour;
    final day = logicalDay(loggedAt, start);
    if (start == 0 || day == dateOnly(loggedAt)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, NqSpace.sm, 16, 0),
      child: Text(
        'Counts toward ${shortDate(day)} — your day starts at $start AM (change in Settings).',
        style: NqText.footnote,
      ),
    );
  }
}
