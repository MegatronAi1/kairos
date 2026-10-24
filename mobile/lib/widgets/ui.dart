import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Space under scrolling content so the floating nav bar never covers it.
const kNavClearance = 112.0;

/// The one Ask Kairos button: green with white text in light mode, white with
/// dark text in dark mode. Use it everywhere the copilot is offered.
class AskKairosButton extends StatelessWidget {
  const AskKairosButton({
    required this.onPressed,
    super.key,
    this.label = 'Ask Kairos',
    this.compact = false,
  });

  final VoidCallback onPressed;
  final String label;
  final bool compact;

  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? Colors.white : KPalette.light.accentX500;

  static Color foreground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0E13) : Colors.white;

  @override
  Widget build(BuildContext context) {
    final bg = background(context);
    final fg = foreground(context);
    return Material(
      color: bg,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onPressed();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20, vertical: compact ? 10 : 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.sparkles, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: KText.ui(KSize.md, weight: FontWeight.w600, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded surface card with a soft shadow in light mode.
class KCard extends StatelessWidget {
  const KCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(KSpace.s4),
    this.onTap,
    this.borderColor,
    this.color,
    this.radius = KR.card,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // repaint on light/dark switch (tab screens keep their elements)
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? KColors.borderSubtle, width: borderColor == null ? 1 : 1.5),
    );
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: cardShadow()),
      child: Material(
        color: color ?? KColors.bgSurface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Large page title with an optional line under it and trailing actions.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // repaint on light/dark switch (tab screens keep their elements)
    return Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s3, KSpace.s4, KSpace.s3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: KText.ui(KSize.sm, weight: FontWeight.w500, color: KColors.textMuted),
                  ),
                Text(title, style: KText.display(28, weight: FontWeight.w800)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small section label with an optional action on the right.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // repaint on light/dark switch (tab screens keep their elements)
    return Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s6, KSpace.s4, KSpace.s3),
      child: Row(
        children: [
          Expanded(child: Text(text, style: KText.display(KSize.lg + 1))),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: KText.ui(KSize.sm, weight: FontWeight.w600, color: KColors.accentX500),
              ),
            ),
        ],
      ),
    );
  }
}

/// Coloured dot + label pill for a health state.
class StateDot extends StatelessWidget {
  const StateDot(this.state, {super.key, this.size = 8});

  final HealthState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // repaint on light/dark switch (tab screens keep their elements)
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: stateColor(state), shape: BoxShape.circle),
    );
  }
}

/// Small rounded tag ("93% typical", "30 h left").
class Tag extends StatelessWidget {
  const Tag(this.text, {required this.color, super.key, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // repaint on light/dark switch (tab screens keep their elements)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KR.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(
            text,
            style: KText.ui(KSize.xs, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// One item of the floating bottom navigation bar.
class NavItem {
  const NavItem(this.icon, this.label, {this.badge = 0});

  final IconData icon;
  final String label;
  final int badge;
}

/// Floating, pill-shaped bottom navigation: the active tab is a filled pill with
/// icon and label; the others show their icon only.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({required this.items, required this.index, required this.onTap, super.key});

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduce = MediaQuery.of(context).disableAnimations;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KR.pill),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.45 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KR.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: (dark ? KColors.bgElevated : Colors.white).withValues(alpha: dark ? 0.86 : 0.9),
                borderRadius: BorderRadius.circular(KR.pill),
                border: Border.all(color: KColors.borderSubtle),
              ),
              child: Row(
                children: [
                  for (final (i, item) in items.indexed)
                    Expanded(
                      flex: i == index ? 2 : 1,
                      child: _NavButton(
                        item: item,
                        active: i == index,
                        reduce: reduce,
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          onTap(i);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active, required this.reduce, required this.onTap});

  final NavItem item;
  final bool active;
  final bool reduce;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AskKairosButton.foreground(context) : KColors.textSecondary;
    return Semantics(
      selected: active,
      button: true,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: reduce ? Duration.zero : KMotion.base,
            curve: KMotion.standard,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active ? AskKairosButton.background(context) : Colors.transparent,
              borderRadius: BorderRadius.circular(KR.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Badge(
                  isLabelVisible: item.badge > 0,
                  backgroundColor: KColors.stateAlarm,
                  label: Text(
                    '${item.badge}',
                    style: KText.ui(10, weight: FontWeight.w700, color: Colors.white),
                  ),
                  child: Icon(item.icon, size: 21, color: fg),
                ),
                if (active) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: KText.ui(KSize.sm, weight: FontWeight.w700, color: fg),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal scroller of choice chips, used for every filter row.
class FilterChipsRow<T> extends StatelessWidget {
  const FilterChipsRow({
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.label,
    super.key,
    this.leading,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T) label;
  final Widget? Function(T)? leading;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // repaint on light/dark switch (tab screens keep their elements)
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: KSpace.s4),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: KSpace.s2),
        itemBuilder: (_, i) {
          final o = options[i];
          final on = o == selected;
          return ChoiceChip(
            selected: on,
            onSelected: (_) => onSelected(o),
            avatar: leading?.call(o),
            label: Text(label(o)),
            labelStyle: KText.ui(
              KSize.sm,
              weight: FontWeight.w600,
              color: on ? KColors.accentX500 : KColors.textSecondary,
            ),
            side: BorderSide(color: on ? KColors.accentX500 : KColors.borderSubtle),
          );
        },
      ),
    );
  }
}
