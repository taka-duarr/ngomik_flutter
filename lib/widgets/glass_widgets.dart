import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'bouncing_tap.dart';
import 'liquid_glass_container.dart';

/// Square glass icon button (back, bookmark, actions in headers).
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? iconColor;
  final double size;
  final bool frosted;
  final bool active;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.iconColor,
    this.size = 40,
    this.frosted = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = LiquidGlassContainer(
      width: size,
      height: size,
      borderRadius: AppRadius.md,
      frosted: frosted,
      color: active ? AppColors.primarySoft : null,
      border: active ? Border.all(color: AppColors.borderGlow) : null,
      boxShadow: const [],
      onTap: onTap,
      scaleFactor: 0.9,
      child: Center(
        child: Icon(
          icon,
          size: 19,
          color: iconColor ?? (active ? AppColors.primaryLight : AppColors.textPrimary),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: tooltip,
      child: tooltip == null ? button : Tooltip(message: tooltip!, child: button),
    );
  }
}

/// Section title with an optional trailing "see all" link.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 12, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          ?trailing,
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryLight,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Small rounded tag. `filled` = magenta (selected / genre), otherwise glass.
class GlassTag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool filled;
  final Widget? leading;

  const GlassTag({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.filled = false,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : (color ?? AppColors.textPrimary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? AppColors.primary : const Color(0x8C1C2038),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: filled ? Colors.transparent : (color?.withValues(alpha: 0.35) ?? AppColors.border),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: fg,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable pill used for filters (home tabs, genres).
class GlassPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const GlassPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: BouncingTap(
        scaleFactor: 0.94,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : const Color(0x591C2038),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected ? AppColors.primaryLight.withValues(alpha: 0.5) : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: selected ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered glass card for empty / signed-out states.
class GlassEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const GlassEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LiquidGlassContainer(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        borderRadius: AppRadius.xl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.borderAccent),
              ),
              child: Icon(icon, size: 28, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.45),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.arrow_forward_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
