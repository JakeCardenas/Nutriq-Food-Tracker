import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'pressable.dart';

/// Black pill — the one main action on a screen.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 56,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Pressable(
      onTap: enabled ? onPressed : null,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: height,
        decoration: BoxDecoration(
          color: enabled || busy ? NqColors.inkSoft : NqColors.fillPressed,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: NqColors.onInk),
              )
            : ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: enabled ? NqColors.onInk : NqColors.textTertiary),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: NqText.headline.copyWith(color: enabled ? NqColors.onInk : NqColors.textTertiary),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// White pill with a hairline border for secondary actions.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.height = 56,
    this.color = NqColors.ink,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Custom leading graphic (e.g. a provider logo) instead of [icon].
  final Widget? leading;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: NqColors.card,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: NqColors.hairline, width: 1.2),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              if (icon != null && leading == null) ...[
                Icon(icon, size: 20, color: enabled ? color : NqColors.textTertiary),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: NqText.headline.copyWith(color: enabled ? color : NqColors.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text-only action with a 44 pt touch target.
class QuietButton extends StatelessWidget {
  const QuietButton({super.key, required this.label, required this.onPressed, this.color = NqColors.ink, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onPressed,
    semanticLabel: label,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: color), const SizedBox(width: 6)],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: NqText.subhead.copyWith(color: onPressed == null ? NqColors.textTertiary : color),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Round icon button: light gray on the canvas, or translucent dark over photos.
class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.onPhoto = false,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool onPhoto;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Pressable(
      onTap: onPressed,
      scale: 0.92,
      semanticLabel: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: onPhoto ? Colors.black.withValues(alpha: 0.38) : NqColors.fill,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size * 0.45, color: onPhoto ? Colors.white : NqColors.ink),
      ),
    ),
  );
}
