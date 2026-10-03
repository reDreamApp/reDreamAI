import 'package:flutter/material.dart';

import 'package:redream_app/core/theme/app_theme.dart';

enum AppButtonStyle { inverse, gradient, outlined }

/// Full-width action button with the three brand looks and a busy state.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.style = AppButtonStyle.inverse,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final child = busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    switch (style) {
      case AppButtonStyle.outlined:
        return OutlinedButton(
          onPressed: enabled ? onPressed : null,
          child: child,
        );
      case AppButtonStyle.inverse:
        return FilledButton(
          onPressed: enabled ? onPressed : null,
          child: child,
        );
      case AppButtonStyle.gradient:
        final gradient = BrandTheme.of(context).accentGradient;
        return Opacity(
          opacity: enabled ? 1 : 0.6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: FilledButton(
              onPressed: enabled ? onPressed : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white70,
                shadowColor: Colors.transparent,
              ),
              child: child,
            ),
          ),
        );
    }
  }
}
