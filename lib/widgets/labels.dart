import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Small "Estimate" pill. Every nutrition number sits near one of these.
class EstimateBadge extends StatelessWidget {
  const EstimateBadge({super.key, this.label = 'Estimate'});

  final String label;

  @override
  Widget build(BuildContext context) =>
      _Pill(label: label, icon: Icons.tune_rounded, fill: NqColors.fill, ink: NqColors.textSecondary);
}

/// Small "Demo" pill for sample (non-live) output.
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.label = 'Demo'});

  final String label;

  @override
  Widget build(BuildContext context) =>
      _Pill(label: label, icon: Icons.science_outlined, fill: NqColors.demoFill, ink: NqColors.demoInk);
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.fill, required this.ink});

  final String label;
  final IconData icon;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: ink),
        const SizedBox(width: 4),
        Text(
          label,
          style: NqText.caption.copyWith(color: ink, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

enum NoticeTone { info, demo, caution, success }

/// Calm, tinted explanation box (demo notices, safeguards, errors).
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tone = NoticeTone.info,
    this.action,
    this.onDismiss,
  });

  final String title;
  final String message;
  final IconData icon;
  final NoticeTone tone;
  final Widget? action;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = switch (tone) {
      NoticeTone.demo => (NqColors.demoFill, NqColors.demoInk),
      NoticeTone.caution => (const Color(0xFFFDECEC), NqColors.danger),
      NoticeTone.success => (const Color(0xFFE9F7EF), NqColors.inRange),
      NoticeTone.info => (NqColors.fill, NqColors.ink),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(NqRadius.tile)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: NqText.subhead.copyWith(color: tone == NoticeTone.info ? NqColors.ink : ink)),
                const SizedBox(height: 3),
                Text(message, style: NqText.footnote.copyWith(color: NqColors.ink.withValues(alpha: 0.72))),
                if (action != null) ...[const SizedBox(height: 4), action!],
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 18, color: NqColors.textSecondary),
            ),
        ],
      ),
    );
  }
}

/// Icon + colour for each macro, used on rings, cards and rows.
enum Macro {
  calories('Calories', Icons.local_fire_department_rounded, NqColors.ink),
  protein('Protein', Icons.egg_alt_rounded, NqColors.protein),
  carbs('Carbs', Icons.bakery_dining_rounded, NqColors.carbs),
  fat('Fats', Icons.water_drop_rounded, NqColors.fat);

  const Macro(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

/// Coloured macro icon followed by a value, e.g. "🥚 18g".
class MacroValue extends StatelessWidget {
  const MacroValue({super.key, required this.macro, required this.text});

  final Macro macro;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(macro.icon, size: 14, color: macro.color),
      const SizedBox(width: 3),
      Text(text, style: NqText.caption.copyWith(color: NqColors.ink.withValues(alpha: 0.75))),
    ],
  );
}

/// Coloured dot + label, used in legends.
class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: NqText.footnote),
    ],
  );
}
