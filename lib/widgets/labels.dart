import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Small "Estimate" pill. Every nutrition number sits near one of these.
class EstimateBadge extends StatelessWidget {
  const EstimateBadge({super.key, this.label = 'Estimate'});

  final String label;

  @override
  Widget build(BuildContext context) => _Pill(label: label, icon: Icons.tune_rounded, color: NqColors.amber);
}

/// Small "Demo" pill for sample (non-live) output.
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.label = 'Demo'});

  final String label;

  @override
  Widget build(BuildContext context) =>
      _Pill(label: label, icon: Icons.science_outlined, color: NqColors.amber);
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: NqText.caption.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

/// Calm, tinted explanation box (demo notices, safeguards, tips).
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color = NqColors.amber,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(NqRadius.control),
      border: Border.all(color: color.withValues(alpha: 0.22), width: 0.8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: NqText.subhead),
              const SizedBox(height: 3),
              Text(message, style: NqText.footnote.copyWith(color: NqColors.textSecondary)),
              if (action != null) ...[const SizedBox(height: 6), action!],
            ],
          ),
        ),
      ],
    ),
  );
}

/// Coloured dot + label, used in macro legends.
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
