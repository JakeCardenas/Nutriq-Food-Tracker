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
import '../../widgets/sheet.dart';
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

/// One editor for every meal — reviewing a scan, adding one manually, or
/// editing a saved meal — laid out as a nutrition sheet over the meal photo.
/// Pops with an [EditorResult], or null when closed without changes.
class MealEditorScreen extends StatefulWidget {
  const MealEditorScreen({
    super.key,
    this.existing,
    this.initialItems = const [],
    this.photoPath,
    this.source = MealSource.manual,
    this.demoSampleName,
    this.openAddFood = false,
    this.startManualEntry = false,
    this.emptyResult = false,
    this.initialLoggedAt,
    this.draftId,
  });

  /// Opens an existing meal for editing.
  MealEditorScreen.edit(Meal meal, {Key? key})
    : this(key: key, existing: meal, initialItems: meal.items, photoPath: meal.photoPath, source: meal.source);

  final Meal? existing;
  final List<FoodItem> initialItems;
  final String? photoPath;
  final MealSource source;
  final String? demoSampleName;

  /// Opens "Add an ingredient" on arrival — straight to the form when [startManualEntry].
  final bool openAddFood;
  final bool startManualEntry;

  /// True when analysis returned no foods — shows "add what you ate".
  final bool emptyResult;

  /// Pre-set date/time for a new meal (e.g. adding to a past day).
  final DateTime? initialLoggedAt;

  /// The scan draft this review came from; it's cleared once the meal is logged.
  final String? draftId;

  @override
  State<MealEditorScreen> createState() => _MealEditorScreenState();
}

class _MealEditorScreenState extends State<MealEditorScreen> {
  late List<FoodItem> _items = [...widget.initialItems];
  late DateTime _loggedAt = widget.existing?.loggedAt ?? widget.initialLoggedAt ?? DateTime.now();
  late MealType _type = widget.existing?.type ?? MealType.suggestFor(_loggedAt);
  late String? _name = widget.existing?.name;
  double _portion = 1;
  final _scroll = ScrollController();
  double _photoHeight = 0;

  /// The sheet has scrolled over the photo: the header turns solid.
  bool _collapsed = false;
  bool _typeTouched = false;
  bool _changed = false;
  bool _saving = false;

  bool get _isNew => widget.existing == null;
  bool get _isDemo => widget.source == MealSource.demoScan;
  bool get _dirty => _changed || (_isNew && widget.draftId == null && _items.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final collapsed = widget.photoPath != null && _scroll.offset > _photoHeight - 90;
      if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    });
    if (widget.openAddFood) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _addFood(startManual: widget.startManualEntry || _hasNoSuggestions()),
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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

  /// Scales every ingredient when the whole meal's portion changes.
  void _setPortion(double next) {
    final factor = next / _portion;
    _update(() {
      _items = [for (final i in _items) i.copyWith(servings: double.parse((i.servings * factor).toStringAsFixed(2)))];
      _portion = next;
    });
  }

  String _whenLabel(DateTime t) {
    final label = dayLabel(t, DateTime.now());
    return label == 'Today' ? timeLabel(t) : (label == 'Yesterday' ? 'Yesterday · ${timeLabel(t)}' : dateTimeLabel(t));
  }

  Future<void> _pickTime() async {
    final picked = await pickDateTime(context, _loggedAt);
    if (picked == null) return;
    _update(() {
      _loggedAt = picked;
      if (!_typeTouched) _type = MealType.suggestFor(picked);
    });
  }

  Future<void> _rename() async {
    final name = await showTextEntrySheet(context, title: 'Meal name', initial: _name ?? '', hint: _fallbackName());
    if (name == null || !mounted) return;
    _update(() => _name = name.isEmpty ? null : name);
  }

  String _fallbackName() {
    if (_items.isEmpty) return _type.label;
    final names = _items.take(2).map((i) => i.name).join(' & ');
    return _items.length > 2 ? '$names +${_items.length - 2}' : names;
  }

  Future<void> _save() async {
    if (_items.isEmpty || _saving) return;
    setState(() => _saving = true);
    final scope = AppScope.of(context);
    final log = scope.log;
    final meal = Meal(
      id: widget.existing?.id ?? newId(),
      loggedAt: _loggedAt,
      type: _type,
      source: widget.source,
      items: _items,
      photoPath: widget.photoPath,
      note: widget.existing?.note,
      name: _name,
    );
    await log.saveMeal(meal);
    final draftId = widget.draftId;
    if (draftId != null) await scope.scans.markLogged(draftId);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    final day = log.dayOf(meal);
    final today = log.today();
    final where = day == today ? 'today' : dayLabel(day, today);
    Navigator.pop(
      context,
      EditorResult(
        _isNew
            ? 'Meal logged ${where == 'today' ? 'for today' : 'for ${where == 'Yesterday' ? 'yesterday' : where}'}'
            : 'Changes saved',
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

  Future<void> _close() async {
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    final ok = await confirmAction(
      context,
      title: _isNew ? 'Discard this meal?' : 'Discard changes?',
      message: widget.draftId != null
          ? 'Your edits won’t be saved. The scan stays on Today so you can log it later.'
          : (_isNew ? 'Nothing will be saved to your log.' : 'Your edits to this meal will be lost.'),
      confirmLabel: 'Discard',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final totals = NutritionTotals.sum(_items.map((i) => i.totals));
    final photo = widget.photoPath;
    final title = widget.existing != null || widget.source != MealSource.manual ? 'Nutrition' : 'Add meal';
    final media = MediaQuery.of(context);
    final photoHeight = photo == null ? 0.0 : (media.size.height * 0.42).clamp(240.0, 400.0);
    _photoHeight = photoHeight;
    final overPhoto = photo != null && !_collapsed;

    final sheet = Container(
      decoration: const BoxDecoration(
        color: NqColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(NqSpace.page, 22, NqSpace.page, NqSpace.xxxl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _content(totals)),
    );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overPhoto ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: photo == null ? NqColors.card : Colors.black,
          body: Stack(
            children: [
              if (photo != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: photoHeight + 40,
                  child: Image.file(
                    AppScope.of(context).photos.resolve(photo),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: NqColors.fillPressed,
                      child: Center(child: Icon(Icons.image_not_supported_outlined, color: NqColors.textTertiary)),
                    ),
                  ),
                ),
              if (photo != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: media.padding.top + 90,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x66000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),
                ),
              ListView(
                controller: _scroll,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(top: photo == null ? media.padding.top + 60 : photoHeight - 24),
                children: [sheet],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TopBar(title: title, onPhoto: overPhoto, onClose: _close, onDelete: _isNew ? null : _delete),
              ),
            ],
          ),
          bottomNavigationBar: _BottomActions(
            isNew: _isNew,
            hasItems: _items.isNotEmpty,
            saving: _saving,
            onSave: _save,
            onSaveFoods: _saveFoodsOnly,
          ),
        ),
      ),
    );
  }

  List<Widget> _content(NutritionTotals totals) => [
    Row(
      children: [
        Pressable(
          onTap: _pickTime,
          semanticLabel: 'Time: ${_whenLabel(_loggedAt)}. Double tap to change.',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: NqColors.fill, borderRadius: BorderRadius.circular(999)),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded, size: 16, color: NqColors.ink),
                  const SizedBox(width: 6),
                  Text(_whenLabel(_loggedAt), style: NqText.caption.copyWith(color: NqColors.ink, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        if (_isDemo) ...[const DemoBadge(), const SizedBox(width: 6)],
        const EstimateBadge(),
      ],
    ),
    const SizedBox(height: 14),
    Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Pressable(
            onTap: _rename,
            semanticLabel: 'Meal name: ${_name ?? _fallbackName()}. Double tap to rename.',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      _name ?? _fallbackName(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NqText.title.copyWith(
                        color: _name == null && _items.isEmpty ? NqColors.textTertiary : NqColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined, size: 16, color: NqColors.textTertiary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (_items.isNotEmpty)
          StepperControl(
            value: _portion,
            step: 0.5,
            min: 0.5,
            max: 10,
            semanticLabel: 'Portions of this meal',
            onChanged: _setPortion,
          ),
      ],
    ),
    const SizedBox(height: 12),
    ChoiceChips<MealType>(
      options: MealType.values,
      selected: _type,
      labelOf: (t) => t.label,
      onSelected: (t) => _update(() {
        _type = t;
        _typeTouched = true;
      }),
    ),
    const SizedBox(height: 18),
    _CaloriesCard(calories: totals.calories),
    const SizedBox(height: 10),
    Row(
      children: [
        Expanded(
          child: _MacroCard(macro: Macro.protein, grams: totals.protein),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MacroCard(macro: Macro.carbs, grams: totals.carbs),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MacroCard(macro: Macro.fat, grams: totals.fat),
        ),
      ],
    ),
    if (_isDemo) ...[
      const SizedBox(height: 14),
      NoticeCard(
        tone: NoticeTone.demo,
        icon: Icons.science_outlined,
        title: 'Demo result — not from your photo',
        message:
            'Nutriq showed a sample meal${widget.demoSampleName == null ? '' : ' (“${widget.demoSampleName}”)'} '
            'so you can try the flow. It didn’t analyze your photo. Edit the ingredients to match what you ate.',
      ),
    ],
    if (widget.emptyResult) ...[
      const SizedBox(height: 14),
      const NoticeCard(
        icon: Icons.search_off_rounded,
        title: 'No foods suggested',
        message: 'We couldn’t suggest foods for this photo. Add what you ate below.',
      ),
    ],
    SectionHeader(
      'Ingredients',
      top: NqSpace.xl,
      trailing: QuietButton(label: 'Add', icon: Icons.add_rounded, onPressed: _addFood),
    ),
    if (_items.isEmpty)
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: NqColors.fill, borderRadius: BorderRadius.circular(NqRadius.tile)),
        child: Column(
          children: [
            const Text('No ingredients yet', style: NqText.headline),
            const SizedBox(height: 4),
            Text(
              'Add what you ate — pick from your foods or enter it by hand.',
              style: NqText.footnote,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SecondaryButton(label: 'Add ingredient', icon: Icons.add_rounded, height: 46, onPressed: _addFood),
          ],
        ),
      )
    else ...[
      for (final item in _items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Dismissible(
            key: ValueKey(item.id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => _remove(item),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                color: NqColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(NqRadius.tile),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: NqColors.danger),
            ),
            child: _IngredientCard(
              item: item,
              onTap: () => _editItem(item),
              onServings: (v) =>
                  _update(() => _items = [for (final i in _items) i.id == item.id ? i.copyWith(servings: v) : i]),
            ),
          ),
        ),
      Text(
        'Tap an ingredient to rename it or fix its nutrition. Swipe left to remove. Photo estimates can miss oils, '
        'sauces and portion sizes.',
        style: NqText.caption,
      ),
    ],
    _DayHint(loggedAt: _loggedAt),
    if (!_isNew && widget.existing!.source != MealSource.manual) ...[
      const SectionHeader('How did this estimate look?', top: NqSpace.xl),
      FeedbackPrompt(meal: widget.existing!),
    ],
  ];
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onPhoto, required this.onClose, required this.onDelete});

  final String title;
  final bool onPhoto;
  final VoidCallback onClose;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    decoration: BoxDecoration(
      color: onPhoto ? Colors.transparent : NqColors.card,
      border: Border(bottom: BorderSide(color: onPhoto ? Colors.transparent : NqColors.hairline)),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(
          children: [
            CircleButton(icon: Icons.close_rounded, tooltip: 'Close', onPhoto: onPhoto, onPressed: onClose),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: NqText.headline.copyWith(color: onPhoto ? Colors.white : NqColors.ink),
              ),
            ),
            if (onDelete != null)
              CircleButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete meal',
                onPhoto: onPhoto,
                onPressed: onDelete,
              )
            else
              const SizedBox(width: 44),
          ],
        ),
      ),
    ),
  );
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.isNew,
    required this.hasItems,
    required this.saving,
    required this.onSave,
    required this.onSaveFoods,
  });

  final bool isNew;
  final bool hasItems;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onSaveFoods;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: NqColors.card,
      border: Border(top: BorderSide(color: NqColors.hairline)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(NqSpace.page, 12, NqSpace.page, 8),
        child: Row(
          children: [
            if (isNew) ...[
              Expanded(
                child: SecondaryButton(
                  label: 'Save foods',
                  icon: Icons.bookmark_border_rounded,
                  onPressed: hasItems ? onSaveFoods : null,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: PrimaryButton(
                label: isNew ? 'Log meal' : 'Save changes',
                busy: saving,
                onPressed: hasItems ? onSave : null,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CaloriesCard extends StatelessWidget {
  const _CaloriesCard({required this.calories});
  final double calories;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'About ${fmtKcal(calories)} calories, estimated',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NqColors.card,
        borderRadius: BorderRadius.circular(NqRadius.tile),
        border: Border.all(color: NqColors.hairline, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: NqColors.fill, shape: BoxShape.circle),
            child: const Icon(Icons.local_fire_department_rounded, color: NqColors.ink, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Calories', style: NqText.footnote),
              Text(fmtKcal(calories), style: NqText.heroNumber.copyWith(fontSize: 32)),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.macro, required this.grams});
  final Macro macro;
  final double grams;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${macro.label}: about ${grams.round()} grams',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: NqColors.card,
        borderRadius: BorderRadius.circular(NqRadius.tile),
        border: Border.all(color: NqColors.hairline, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(macro.icon, size: 16, color: macro.color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(macro.label, style: NqText.caption, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${grams.round()}g', style: NqText.metric),
        ],
      ),
    ),
  );
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({required this.item, required this.onTap, required this.onServings});

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
          color: NqColors.card,
          borderRadius: BorderRadius.circular(NqRadius.tile),
          border: Border.all(color: NqColors.hairline, width: 1.2),
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
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(item.servingLabel, style: NqText.footnote),
                MacroValue(macro: Macro.protein, text: '${t.protein.round()}g'),
                MacroValue(macro: Macro.carbs, text: '${t.carbs.round()}g'),
                MacroValue(macro: Macro.fat, text: '${t.fat.round()}g'),
              ],
            ),
            if (item.isLowConfidence) ...[
              const SizedBox(height: 8),
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
      padding: const EdgeInsets.only(top: NqSpace.md),
      child: Text(
        'Counts toward ${shortDate(day)} — your day starts at $start AM (change in Settings).',
        style: NqText.footnote,
      ),
    );
  }
}
