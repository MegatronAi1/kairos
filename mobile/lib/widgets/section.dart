import 'package:flutter/material.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';

/// Section heading in the display face with an optional one-line explanation.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: KSpace.s3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: KText.display(KSize.lg)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: KText.ui(KSize.sm, color: KColors.textSecondary)),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Rounded surface card used to group a section.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({required this.child, super.key, this.padding = const EdgeInsets.all(KSpace.s4)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: KColors.bgSurface,
      borderRadius: BorderRadius.circular(KRadius.card),
      border: Border.all(color: KColors.borderSubtle),
    ),
    child: child,
  );
}
