import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/format.dart';
import '../app/theme.dart';
import 'pressable.dart';

/// − value + with 44pt targets and a light haptic per step.
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
        decoration: BoxDecoration(color: NqColors.raised, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepButton(icon: Icons.remove_rounded, onTap: value > min ? () => _change(value - step) : null),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44),
              child: Text(
                '${format(value)}${suffix ?? ''}',
                textAlign: TextAlign.center,
                style: NqText.numberSmall,
              ),
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
      scale: 0.9,
      child: SizedBox(
        width: 44,
        height: 40,
        child: Icon(icon, size: 20, color: onTap == null ? NqColors.textTertiary : NqColors.textPrimary),
      ),
    ),
  );
}

/// A row of mutually exclusive chips (meal type, units, …).
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: o == selected ? NqColors.sage.withValues(alpha: 0.16) : NqColors.raised,
                borderRadius: BorderRadius.circular(NqRadius.chip),
                border: Border.all(
                  color: o == selected ? NqColors.sage.withValues(alpha: 0.6) : Colors.transparent,
                ),
              ),
              child: Text(
                labelOf(o),
                style: NqText.subhead.copyWith(color: o == selected ? NqColors.sage : NqColors.textPrimary),
              ),
            ),
          ),
        ),
    ],
  );
}

/// Large selectable tile with title and description (onboarding choices).
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.multi = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      scale: 0.985,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? NqColors.sage.withValues(alpha: 0.10) : NqColors.surface,
          borderRadius: BorderRadius.circular(NqRadius.control + 2),
          border: Border.all(color: selected ? NqColors.sage.withValues(alpha: 0.7) : NqColors.hairline),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 24, color: selected ? NqColors.sage : NqColors.textSecondary),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: NqText.headline),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: NqText.footnote),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? (multi ? Icons.check_box_rounded : Icons.check_circle_rounded)
                  : (multi ? Icons.check_box_outline_blank_rounded : Icons.circle_outlined),
              color: selected ? NqColors.sage : NqColors.textTertiary,
              size: 24,
            ),
          ],
        ),
      ),
    ),
  );
}
