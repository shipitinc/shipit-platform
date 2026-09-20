import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/design_tokens.dart';
import '../core/theme.dart';
import '../core/theme_controller.dart';

/// The left navigation rail.
///
/// Geometry is transcribed from the Penpot board `BP · Home` (light/dark):
/// 200px rail with a 1px divider on its trailing edge; 20px gutter; brand
/// lockup at y=22; rule at y=78; four nav rows at y=96/126/156/186 (30px pitch)
/// with right-aligned counts; rule at y=224; the "YOU" block from y=238.
///
/// The design deliberately uses text-only navigation — no icons — with a 2×12
/// accent mark marking the active row.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    this.needsYouCount,
    this.allWorkCount,
    this.productCount,
  });

  /// Count shown against "Needs you". Rendered in the attention tone because
  /// the design colours a non-zero backlog amber.
  final int? needsYouCount;

  /// Count shown against "All work".
  final int? allWorkCount;

  /// Count shown against "Products".
  final int? productCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final currentPath = GoRouterState.of(context).uri.path;

    return Container(
      width: ShipItMetrics.railWidth,
      decoration: BoxDecoration(
        color: palette.rail,
        border: Border(
          right: BorderSide(color: palette.rule, width: ShipItMetrics.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 22),
          const _BrandLockup(),
          // Rule at y=78; brand block ends at y=70.
          const SizedBox(height: 8),
          const _RailRule(),
          const SizedBox(height: 17),
          _NavRow(
            label: 'Overview',
            active: _isOverview(currentPath),
            onTap: () => context.go('/'),
          ),
          const SizedBox(height: 11),
          _NavRow(
            label: 'All work',
            count: allWorkCount,
            active: currentPath.startsWith('/runs'),
            onTap: () => context.go('/runs'),
          ),
          const SizedBox(height: 11),
          _NavRow(
            label: 'Needs you',
            count: needsYouCount,
            countIsAttention: (needsYouCount ?? 0) > 0,
            active: currentPath.startsWith('/needs-you'),
            onTap: () => context.go('/needs-you'),
          ),
          const SizedBox(height: 11),
          _NavRow(
            label: 'Products',
            count: productCount,
            active: currentPath.startsWith('/products'),
            onTap: () => context.go('/products'),
          ),
          const SizedBox(height: 19),
          const _RailRule(),
          const SizedBox(height: 13),
          const _IdentityBlock(),
          const Spacer(),
          const _ThemeControl(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static bool _isOverview(String path) =>
      path == '/' ||
      (!path.startsWith('/runs') &&
          !path.startsWith('/needs-you') &&
          !path.startsWith('/products'));
}

/// `Brand Logomark` (26×26 at x=20) + `Wordmark` / `Wordmark Sub`.
class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ShipItMetrics.railGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // `Brand Logomark`: 26×26 at the rail gutter.
              const Image(
                image: AssetImage('assets/brand/logomark.png'),
                width: 26,
                height: 26,
                // The asset is exported at exactly 1x, so let the engine
                // resample smoothly on high-DPR displays.
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 8),
              Text(
                'SHIP IT',
                style: ShipItType.brand.copyWith(color: palette.inkPrimary),
              ),
            ],
          ),
          // `Wordmark Sub` sits at y=56; the lockup row occupies 22..48.
          const SizedBox(height: 8),
          Text(
            'CONTROL PLANE',
            style: ShipItType.railMicro.copyWith(color: palette.inkTertiary),
          ),
        ],
      ),
    );
  }
}

/// `Rail Rule` — a 160px hairline inset by the 20px gutter.
class _RailRule extends StatelessWidget {
  const _RailRule();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ShipItMetrics.railGutter),
      child: Container(
        height: ShipItMetrics.hairline,
        color: context.palette.rule,
      ),
    );
  }
}

/// A single navigation row: 2×12 active mark at the gutter, label at x=30,
/// optional right-aligned mono count.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
    this.countIsAttention = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? count;
  final bool countIsAttention;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: active,
      label: count == null ? label : '$label, $count',
      child: InkWell(
        onTap: onTap,
        hoverColor: palette.rule.withValues(alpha: 0.4),
        child: SizedBox(
          height: 19,
          child: Row(
            children: [
              // Nav labels share the rail's 20px gutter with the brand, the
              // rules and the YOU block, so every item on the rail lines up.
              // The 2px active mark therefore sits in the outer margin rather
              // than pushing the label inwards.
              SizedBox(
                width: ShipItMetrics.railGutter,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: ShipItMetrics.railActiveMarkInset,
                    ),
                    child: Container(
                      width: ShipItMetrics.tickWidth,
                      height: 12,
                      color: active
                          ? palette.accentTick
                          : const Color(0x00000000),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  style: active
                      ? ShipItType.navActive.copyWith(color: palette.inkPrimary)
                      : ShipItType.rowTitle.copyWith(
                          color: palette.inkSecondary,
                        ),
                ),
              ),
              if (count != null)
                Padding(
                  padding: const EdgeInsets.only(
                    right: ShipItMetrics.railGutter,
                  ),
                  child: Text(
                    '$count',
                    style: ShipItType.ref.copyWith(
                      color: countIsAttention
                          ? palette.attention
                          : palette.inkTertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "YOU" block: section label plus the two durability assurances the
/// design prints verbatim.
class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ShipItMetrics.railGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOU',
            style: ShipItType.railMicro.copyWith(color: palette.inkTertiary),
          ),
          const SizedBox(height: 4),
          Text(
            'Signed in on this device',
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 3),
          Text(
            'Decisions are recorded',
            style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
          ),
        ],
      ),
    );
  }
}

/// Theme override control.
///
/// The design ships a light and a dark board without drawing a switcher, so
/// this is presented in the design's own idiom — a micro mono label, bottom of
/// the rail — rather than as a Material control that would break the language.
class _ThemeControl extends StatelessWidget {
  const _ThemeControl();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final controller = ThemeControllerScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();

    final label = switch (controller.mode) {
      ThemeMode.system => 'THEME · AUTO',
      ThemeMode.light => 'THEME · LIGHT',
      ThemeMode.dark => 'THEME · DARK',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ShipItMetrics.railGutter),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          button: true,
          label:
              'Theme, ${controller.followsPlatform ? 'following system' : controller.mode.name}',
          child: InkWell(
            onTap: controller.cycle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                label,
                style: ShipItType.railMicro.copyWith(
                  color: palette.inkTertiary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Exposes the [ThemeController] to the rail without a service locator.
class ThemeControllerScope extends InheritedNotifier<ThemeController> {
  const ThemeControllerScope({
    super.key,
    required ThemeController super.notifier,
    required super.child,
  });

  static ThemeController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ThemeControllerScope>()
      ?.notifier;
}
