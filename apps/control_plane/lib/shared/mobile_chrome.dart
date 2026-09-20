import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/design_tokens.dart';
import '../core/plain_language.dart';
import '../core/theme.dart';
import 'design_primitives.dart';

/// Mobile chrome from the Penpot `BPM ·` boards.
///
/// The mobile composition replaces the rail with a 56px top bar and an 80px
/// bottom navigation bar. Detail screens swap the top bar for a back link,
/// because on mobile the breadcrumb is the only way back.

/// `Top Bg` — brand on the left, live stamp on the right.
class MobileTopBar extends StatelessWidget {
  const MobileTopBar({super.key, this.liveLabel = 'LIVE'});

  final String liveLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: ShipItMetrics.mobileTopBarHeight,
      decoration: BoxDecoration(
        color: palette.rail,
        border: Border(
          bottom: BorderSide(
            color: palette.rule,
            width: ShipItMetrics.hairline,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: ShipItMetrics.mobileGutter,
      ),
      child: Row(
        children: [
          const Image(
            image: AssetImage('assets/brand/logomark.png'),
            width: 22,
            height: 22,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 8),
          Text(
            'SHIP IT',
            style: ShipItType.brand.copyWith(color: palette.inkPrimary),
          ),
          const Spacer(),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: palette.positive,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          MicroLabel(liveLabel, color: palette.inkSecondary),
        ],
      ),
    );
  }
}

/// Detail-screen top bar: a single back link (`‹ All work`).
class MobileBackBar extends StatelessWidget {
  const MobileBackBar({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: ShipItMetrics.mobileTopBarHeight,
      decoration: BoxDecoration(
        color: palette.rail,
        border: Border(
          bottom: BorderSide(
            color: palette.rule,
            width: ShipItMetrics.hairline,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: ShipItMetrics.mobileGutter,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          button: true,
          label: 'Back to $label',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '‹  ',
                    style: ShipItType.link.copyWith(color: palette.accent),
                  ),
                  Text(
                    label,
                    style: ShipItType.link.copyWith(color: palette.accent),
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

/// `Nav Bg` — three destinations with a pill on the active icon and an
/// attention badge carrying the outstanding decision count.
class MobileNavBar extends StatelessWidget {
  const MobileNavBar({super.key, this.needsYouCount});

  final int? needsYouCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final path = GoRouterState.of(context).uri.path;
    final index = path.startsWith('/runs')
        ? 1
        : path.startsWith('/needs-you')
        ? 2
        : path.startsWith('/products')
        ? 3
        : 0;

    return Container(
      height: ShipItMetrics.mobileNavBarHeight,
      decoration: BoxDecoration(
        color: palette.rail,
        border: Border(
          top: BorderSide(color: palette.rule, width: ShipItMetrics.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              label: 'Overview',
              icon: _NavGlyph.grid,
              active: index == 0,
              onTap: () => context.go('/'),
            ),
          ),
          Expanded(
            child: _NavItem(
              label: 'All work',
              icon: _NavGlyph.list,
              active: index == 1,
              onTap: () => context.go('/runs'),
            ),
          ),
          Expanded(
            child: _NavItem(
              label: 'Needs you',
              icon: _NavGlyph.alert,
              active: index == 2,
              badge: (needsYouCount ?? 0) > 0 ? needsYouCount : null,
              onTap: () => context.go('/needs-you'),
            ),
          ),
          Expanded(
            child: _NavItem(
              label: 'Products',
              icon: _NavGlyph.box,
              active: index == 3,
              onTap: () => context.go('/products'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The board draws its own glyphs from rectangles rather than using an icon
/// font, so they are reproduced here as shapes for an exact match.
enum _NavGlyph { grid, list, alert, box }

/// `Nav Pill` dimensions; also the constant footprint of every destination's
/// icon area, so the badge never moves.
const double _pillWidth = 52;
const double _pillHeight = 26;

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final String label;
  final _NavGlyph icon;
  final bool active;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = active ? palette.inkPrimary : palette.inkTertiary;

    return Semantics(
      button: true,
      selected: active,
      label: badge == null ? label : '$label, $badge waiting',
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Fixed footprint whether or not this destination is selected.
            // Sizing the stack to its children would let the 52px active pill
            // widen it, which drags the badge sideways on selection.
            SizedBox(
              width: _pillWidth,
              height: _pillHeight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (active)
                    Container(
                      decoration: BoxDecoration(
                        color: palette.rule.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(_pillHeight / 2),
                      ),
                    ),
                  _Glyph(kind: icon, color: tone),
                  if (badge != null)
                    Positioned(
                      // Board: badge spans x 336..354 against an icon centred
                      // on 325, i.e. 3px past the pill's trailing edge.
                      right: -3,
                      top: -6,
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: palette.attentionTick,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$badge',
                          style: ShipItType.ref.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF241A02),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: ShipItType.navLabelMobile.copyWith(
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: tone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.kind, required this.color});

  final _NavGlyph kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case _NavGlyph.grid:
        return SizedBox(
          width: 13,
          height: 13,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var row = 0; row < 2; row++)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var col = 0; col < 2; col++)
                      Container(width: 5, height: 5, color: color),
                  ],
                ),
            ],
          ),
        );
      case _NavGlyph.list:
        return SizedBox(
          width: 14,
          height: 10,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 3; i++)
                Container(width: 14, height: 2, color: color),
            ],
          ),
        );
      case _NavGlyph.alert:
        return SizedBox(
          width: 2,
          height: 12,
          child: Column(
            children: [
              Container(width: 2, height: 8, color: color),
              const SizedBox(height: 2),
              Container(width: 2, height: 2, color: color),
            ],
          ),
        );
      // An open box outline — the Penpot board draws Products as a 14x10
      // rectangle built from the same 2px bars as the other glyphs, rather
      // than introducing an icon font the rest of the rail does not use.
      case _NavGlyph.box:
        return SizedBox(
          width: 14,
          height: 10,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: Container(width: 14, height: 2, color: color),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(width: 14, height: 2, color: color),
              ),
              Positioned(
                top: 2,
                left: 0,
                child: Container(width: 2, height: 6, color: color),
              ),
              Positioned(
                top: 2,
                right: 0,
                child: Container(width: 2, height: 6, color: color),
              ),
            ],
          ),
        );
    }
  }
}

/// A full-width primary action, as used at the foot of every mobile card and
/// detail screen.
class MobilePrimaryButton extends StatelessWidget {
  const MobilePrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : 150,
      height: fullWidth ? 36 : 26,
      child: FilledButton(
        onPressed: onPressed,
        child: Text(label, style: ShipItType.buttonLabelMobile),
      ),
    );
  }
}

/// True when the mobile composition should be used.
bool isMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width < ShipItMetrics.mobileBreakpoint;

/// A compact two-line work row (Penpot `Row Title` / `Row State` / `Row Age`).
///
/// Used on both mobile list screens: title on the first line, reference and
/// plain status on the second, elapsed time right-aligned.
class MobileWorkRow extends StatelessWidget {
  const MobileWorkRow({
    super.key,
    required this.id,
    required this.title,
    required this.status,
    required this.elapsed,
    required this.onTap,
    this.showRef = true,
    this.showChevron = false,
  });

  final String id;
  final String title;
  final PlainStatus status;
  final Duration? elapsed;
  final VoidCallback onTap;

  /// The Overview list omits the reference; All work shows it.
  final bool showRef;

  /// All work shows a trailing chevron to advertise the row is tappable.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: '$title, ${status.label}',
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AccentTick(
                      color: status.tickColor(palette),
                      height: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ShipItType.rowTitleMobile.copyWith(
                            color: palette.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (showRef) ...[
                              Text(
                                PlainLanguage.refLabel(id),
                                style: ShipItType.status.copyWith(
                                  color: palette.inkTertiary,
                                ),
                              ),
                              const SizedBox(width: 14),
                            ],
                            Flexible(
                              child: Text(
                                status.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ShipItType.status.copyWith(
                                  color: status.textColor(palette),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      PlainLanguage.elapsed(elapsed),
                      style: ShipItType.monoMeta.copyWith(
                        color: palette.inkTertiary,
                      ),
                    ),
                  ),
                  if (showChevron)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 18),
                      child: Text(
                        '›',
                        style: ShipItType.link.copyWith(color: palette.accent),
                      ),
                    ),
                ],
              ),
            ),
            const ContentRule(),
          ],
        ),
      ),
    );
  }
}
