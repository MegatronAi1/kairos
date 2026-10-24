import 'package:flutter/material.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    super.key,
    this.message,
    this.icon = LucideIcons.inbox,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) =>
      _Centered(icon: icon, color: KColors.textMuted, title: title, message: message, action: action);
}

class ErrorState extends StatelessWidget {
  const ErrorState({required this.title, super.key, this.message, this.onRetry});

  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _Centered(
    icon: LucideIcons.alertTriangle,
    color: KColors.stateAlarm,
    title: title,
    message: message,
    action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
  );
}

class _Centered extends StatelessWidget {
  const _Centered({required this.icon, required this.color, required this.title, this.message, this.action});

  final IconData icon;
  final Color color;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(KSpace.s8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: KSpace.s3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: KText.ui(KSize.lg, weight: FontWeight.w500),
          ),
          if (message != null) ...[
            const SizedBox(height: KSpace.s1),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: KText.ui(KSize.md, color: KColors.textSecondary),
            ),
          ],
          if (action != null) ...[const SizedBox(height: KSpace.s4), action!],
        ],
      ),
    ),
  );
}

/// Pulsing placeholder block for loading states.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width = double.infinity, this.radius = KRadius.control});

  final double height;
  final double width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.4, end: 0.9).animate(_c),
    child: Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: KColors.bgElevated,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}
