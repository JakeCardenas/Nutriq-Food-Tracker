import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/format.dart';
import '../app/theme.dart';
import 'pressable.dart';

/// Outlined pill stepper: − value + (44 pt targets, light haptic per step).
class StepperControl extends StatelessWidget {
  const StepperControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = 0.25,
    this.min = 0.25,
    this.max = 20,
    this.suffix,
    this.semanticLabel = 'Servings',
    this.format = fmtAmount,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double step;
  final double min;
  final double max;
  final String? suffix;
  final String semanticLabel;
  final String Function(double) format;

  void _change(double next) {
    final clamped = next.clamp(min, max).toDouble();
    if (clamped == value) return;
    HapticFeedback.selectionClick();
    onChanged(double.parse(clamped.toStringAsFixed(2)));
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      value: '${format(value)}${suffix == null ? '' : ' $suffix'}',
      increasedValue: format((value + step).clamp(min, max).toDouble()),
      decreasedValue: format((value - step).clamp(min, max).toDouble()),
      onIncrease: () => _change(value + step),
      onDecrease: () => _change(value - step),
      child: Container(
        decoration: BoxDecoration(
          color: NqColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: NqColors.hairline, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepButton(icon: Icons.remove_rounded, onTap: value > min ? () => _change(value - step) : null),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 36),
              child: Text('${format(value)}${suffix ?? ''}', textAlign: TextAlign.center, style: NqText.numberSmall),
            ),
            _StepButton(icon: Icons.add_rounded, onTap: value < max ? () => _change(value + step) : null),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Pressable(
      onTap: onTap,
      scale: 0.88,
      child: SizedBox(
        width: 44,
        height: 40,
        child: Icon(icon, size: 18, color: onTap == null ? NqColors.textTertiary : NqColors.ink),
      ),
    ),
  );
}

/// Mutually exclusive chips (meal type, rating, …): gray, black when selected.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> options;
  final T? selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final o in options)
        Semantics(
          selected: o == selected,
          button: true,
          child: Pressable(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(o);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: o == selected ? NqColors.inkSoft : NqColors.fill,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                labelOf(o),
                style: NqText.subhead.copyWith(color: o == selected ? NqColors.onInk : NqColors.ink),
              ),
            ),
          ),
        ),
    ],
  );
}

/// Large selectable tile: light gray, black when selected (single- or multi-select).
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.multi = false,
    this.centered = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final bool multi;
  final bool centered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? NqColors.onInk : NqColors.ink;
    final sub = selected ? NqColors.onInk.withValues(alpha: 0.72) : NqColors.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        scale: 0.985,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? NqColors.inkSoft : NqColors.fill,
            borderRadius: BorderRadius.circular(NqRadius.tile),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withValues(alpha: 0.12) : NqColors.card,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: fg),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      textAlign: centered ? TextAlign.center : TextAlign.start,
                      style: NqText.headline.copyWith(color: fg),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        textAlign: centered ? TextAlign.center : TextAlign.start,
                        style: NqText.footnote.copyWith(color: sub),
                      ),
                    ],
                  ],
                ),
              ),
              if (multi) ...[
                const SizedBox(width: 10),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? NqColors.onInk : NqColors.textTertiary,
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-option segmented control (e.g. Imperial / Metric).
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: NqColors.fill, borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final o in options)
          Semantics(
            selected: o == selected,
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(o);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                constraints: const BoxConstraints(minHeight: 36, minWidth: 92),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: o == selected ? NqColors.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: o == selected
                      ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))]
                      : null,
                ),
                child: Text(
                  labelOf(o),
                  style: NqText.subhead.copyWith(color: o == selected ? NqColors.ink : NqColors.textSecondary),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// iOS-style wheel for picking a number (age, height, weight…).
class NumberWheel extends StatefulWidget {
  const NumberWheel({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    this.width = 120,
    this.semanticLabel,
  });

  final List<int> values;
  final int selected;
  final ValueChanged<int> onChanged;
  final String Function(int) labelOf;
  final double width;
  final String? semanticLabel;

  @override
  State<NumberWheel> createState() => _NumberWheelState();
}

class _NumberWheelState extends State<NumberWheel> {
  late final FixedExtentScrollController _controller = FixedExtentScrollController(
    initialItem: widget.values.indexOf(widget.selected).clamp(0, widget.values.length - 1),
  );

  @override
  void didUpdateWidget(NumberWheel old) {
    super.didUpdateWidget(old);
    final index = widget.values.indexOf(widget.selected);
    if (index >= 0 && _controller.hasClients && _controller.selectedItem != index) {
      _controller.jumpToItem(index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticLabel,
    value: widget.labelOf(widget.selected),
    child: SizedBox(
      width: widget.width,
      height: 210,
      child: CupertinoPicker.builder(
        scrollController: _controller,
        itemExtent: 42,
        diameterRatio: 1.25,
        // Painted over the selected row, so it must stay translucent.
        selectionOverlay: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: NqColors.ink.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onSelectedItemChanged: (i) => widget.onChanged(widget.values[i]),
        childCount: widget.values.length,
        itemBuilder: (context, i) =>
            Center(child: Text(widget.labelOf(widget.values[i]), style: NqText.headline.copyWith(fontSize: 19))),
      ),
    ),
  );
}
