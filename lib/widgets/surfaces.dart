import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'pressable.dart';

/// Rounded graphite surface.
class NqCard extends StatelessWidget {
  const NqCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NqSpace.lg),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? NqColors.surface,
        borderRadius: BorderRadius.circular(NqRadius.card),
      ),
      child: Padding(padding: padding, child: child),
    );
    return onTap == null ? card : Pressable(onTap: onTap, scale: 0.985, child: card);
  }
}

/// Section title above a group, iOS-style.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, NqSpace.xxl, 4, NqSpace.sm),
    child: Row(
      children: [
        Expanded(child: Text(title, style: NqText.headline)),
        ?trailing,
      ],
    ),
  );
}

/// An inset group of rows separated by hairlines (Settings-style).
class NqGroup extends StatelessWidget {
  const NqGroup({super.key, required this.children, this.header, this.footer});

  final List<Widget> children;
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, NqSpace.xxl, 16, NqSpace.sm),
            child: Text(
              header!.toUpperCase(),
              style: NqText.caption.copyWith(letterSpacing: 0.6, color: NqColors.textSecondary),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(NqRadius.card - 4),
          child: ColoredBox(
            color: NqColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Padding(padding: EdgeInsets.only(left: 16), child: Divider()),
                  children[i],
                ],
              ],
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, NqSpace.sm, 16, 0),
            child: Text(footer!, style: NqText.footnote),
          ),
      ],
    );
  }
}

/// One tappable row inside an [NqGroup].
class NqRow extends StatelessWidget {
  const NqRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.icon,
    this.onTap,
    this.destructive = false,
    this.trailing,
    this.showChevron,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool destructive;
  final Widget? trailing;
  final bool? showChevron;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? NqColors.coral : NqColors.textPrimary;
    final chevron = showChevron ?? (onTap != null && !destructive);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: destructive ? NqColors.coral : NqColors.textSecondary),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: NqText.body.copyWith(color: color)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: NqText.footnote),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    value!,
                    textAlign: TextAlign.right,
                    style: NqText.body.copyWith(color: NqColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              ?trailing,
              if (chevron) ...[
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: NqColors.textTertiary, size: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
