import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'pressable.dart';

/// White rounded card with a hairline border and a soft shadow.
class NqCard extends StatelessWidget {
  const NqCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NqSpace.lg),
    this.onTap,
    this.color,
    this.radius = NqRadius.card,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? NqColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: NqColors.hairline),
        boxShadow: color == null ? NqShadow.card : null,
      ),
      child: Padding(padding: padding, child: child),
    );
    return onTap == null ? card : Pressable(onTap: onTap, scale: 0.985, semanticLabel: semanticLabel, child: card);
  }
}

/// Section title above content.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.top = NqSpace.xxl});

  final String title;
  final Widget? trailing;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(2, top, 2, NqSpace.md),
    child: Row(
      children: [
        Expanded(child: Text(title, style: NqText.title.copyWith(fontSize: 20))),
        ?trailing,
      ],
    ),
  );
}

/// A white card of rows separated by hairlines (Settings-style).
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
            padding: const EdgeInsets.fromLTRB(4, NqSpace.xxl, 4, NqSpace.sm),
            child: Text(header!, style: NqText.subhead.copyWith(color: NqColors.textSecondary)),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: NqColors.card,
            borderRadius: BorderRadius.circular(NqRadius.card),
            border: Border.all(color: NqColors.hairline),
            boxShadow: NqShadow.card,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(NqRadius.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Padding(padding: EdgeInsets.only(left: 56), child: Divider()),
                  children[i],
                ],
              ],
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, NqSpace.sm, 4, 0),
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
    final color = destructive ? NqColors.danger : NqColors.ink;
    final chevron = showChevron ?? (onTap != null && !destructive);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: destructive ? NqColors.danger : NqColors.ink),
                const SizedBox(width: 18),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: NqText.body.copyWith(color: color, fontWeight: FontWeight.w500),
                    ),
                    if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: NqText.footnote)],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(
                    value!,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: NqText.callout.copyWith(fontSize: 16),
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
