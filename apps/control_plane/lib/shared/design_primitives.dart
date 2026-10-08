import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../core/theme.dart';

/// Reusable pieces of the design's visual language, so each screen composes
/// them instead of re-deriving spacing and tones.

/// A full-width 1px rule spanning the content column
/// (`Header Rule`, `Metric Rule`, `Row Rule`, `Footer Rule`).
class ContentRule extends StatelessWidget {
  const ContentRule({super.key, this.strong = false});

  /// `Table Head Rule` uses the heavier tone.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: ShipItMetrics.hairline,
      color: strong ? palette.ruleStrong : palette.rule,
    );
  }
}

/// A 2px colour tick — the design's universal status affordance
/// (`Row Tick`, `Metric Tick`, `Gate Edge`, `Job Tick`).
class AccentTick extends StatelessWidget {
  const AccentTick({super.key, required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ShipItMetrics.tickWidth,
      height: height,
      color: color,
    );
  }
}

/// An uppercase mono micro label (`Metric Key`, `Col · …`, `WHAT WE SUGGEST`).
class MicroLabel extends StatelessWidget {
  const MicroLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: ShipItType.microLabel.copyWith(
        color: color ?? context.palette.inkTertiary,
      ),
    );
  }
}

/// The page header: title, subtitle, and the right-hand freshness stamp.
///
/// Penpot: `H1` at y=30, `H1 Sub` at y=60, `Live`/`Live Dot`/`Live Sub` top
/// right, then `Header Rule` at y=90.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.liveLabel,
    this.freshness,
    this.trailing,
  });

  final String title;
  final String subtitle;

  /// e.g. `LIVE`, or `2 WAITING` on the Needs you screen.
  final String? liveLabel;

  /// e.g. `updated 12 seconds ago`.
  final String? freshness;

  /// Replaces the live stamp entirely when supplied.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ShipItType.pageTitle.copyWith(
                      color: palette.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: ShipItType.pageSubtitle.copyWith(
                      color: palette.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (liveLabel != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: palette.positive,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      MicroLabel(liveLabel!, color: palette.inkSecondary),
                    ],
                  ),
                  if (freshness != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      freshness!,
                      style: ShipItType.monoMeta.copyWith(
                        color: palette.inkTertiary,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
        const SizedBox(height: 25),
        const ContentRule(),
      ],
    );
  }
}

/// A section heading with an optional trailing link
/// (`Table Title` + `Table Link`).
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.small = false,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style:
                (small ? ShipItType.sectionTitleSmall : ShipItType.sectionTitle)
                    .copyWith(color: palette.inkPrimary),
          ),
        ),
        if (actionLabel != null)
          InlineLink(label: actionLabel!, onTap: onAction),
      ],
    );
  }
}

/// A text link in the design's idiom: no padding, no underline, accent tone.
class InlineLink extends StatelessWidget {
  const InlineLink({
    super.key,
    required this.label,
    this.onTap,
    this.micro = false,
    this.caret,
  });

  final String label;
  final VoidCallback? onTap;

  /// `Disclose` uses the 10px variant.
  final bool micro;

  /// Trailing disclosure caret. Drawn rather than typed because the design's
  /// ▸/▾ characters are absent from IBM Plex and would fall back
  /// inconsistently across platforms.
  final CaretDirection? caret;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = (micro ? ShipItType.linkMicro : ShipItType.link).copyWith(
      color: palette.accent,
    );
    return Semantics(
      link: true,
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: style),
              if (caret != null) ...[
                const SizedBox(width: 4),
                DesignCaret(direction: caret!, color: palette.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Which way a disclosure caret points.
enum CaretDirection { right, down }

/// A solid triangle matching the design's disclosure marker, in any tone.
///
/// The design types `▸`/`▾`, but those characters are absent from IBM Plex and
/// fall back inconsistently across platforms, so every disclosure marker in the
/// app is this shape instead.
class DesignCaret extends StatelessWidget {
  const DesignCaret({super.key, required this.direction, required this.color});

  final CaretDirection direction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: direction == CaretDirection.right
          ? const Size(4, 6)
          : const Size(6, 4),
      painter: _CaretPainter(direction: direction, color: color),
    );
  }
}

class _CaretPainter extends CustomPainter {
  const _CaretPainter({required this.direction, required this.color});

  final CaretDirection direction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (direction == CaretDirection.right) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CaretPainter oldDelegate) =>
      oldDelegate.direction != direction || oldDelegate.color != color;
}

/// A bordered panel: `Gate Bg` — card fill, hairline border, 3px radius, with
/// an optional leading accent edge.
class DesignPanel extends StatelessWidget {
  const DesignPanel({
    super.key,
    required this.child,
    this.edgeColor,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;

  /// `Gate Edge` — a 2px full-height leading bar.
  final Color? edgeColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(
          color: palette.cardBorder,
          width: ShipItMetrics.hairline,
        ),
        borderRadius: BorderRadius.circular(ShipItMetrics.radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ShipItMetrics.radius),
        // A Stack (rather than a stretched Row) keeps the panel usable inside
        // an unbounded-height column while still letting the accent edge span
        // the full height.
        child: Stack(
          children: [
            Padding(
              padding: padding.add(
                EdgeInsets.only(
                  left: edgeColor == null ? 0 : ShipItMetrics.tickWidth,
                ),
              ),
              child: child,
            ),
            if (edgeColor != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: ShipItMetrics.tickWidth,
                child: ColoredBox(color: edgeColor!),
              ),
          ],
        ),
      ),
    );
  }
}

/// Which edge of the footer row the disclosure sits on.
enum DisclosureAlignment { start, end }

/// The collapsed "Show technical details" disclosure that every screen carries
/// in its footer.
///
/// This is the only place the design permits raw system vocabulary to surface.
class TechnicalDetails extends StatefulWidget {
  const TechnicalDetails({
    super.key,
    required this.lines,
    this.note,
    this.showRule = true,
    this.disclosureAlignment = DisclosureAlignment.end,
  });

  /// Raw, verbatim system facts (state wire values, ids, counts).
  final List<String> lines;

  /// Optional provenance note shown beside the toggle.
  final String? note;

  /// Whether the [ContentRule] divider is painted above the disclosure row.
  ///
  /// Defaults to `true`, which is the treatment on every screen that carries a
  /// disclosure today. `false` is the mobile Add Product footer, whose board
  /// (`BPM - Add Product`) shows a left-aligned disclosure with no divider.
  final bool showRule;

  /// Which edge the disclosure sits on. Defaults to [DisclosureAlignment.end],
  /// which is what a `null` [note] produces today: the note slot expands to fill
  /// the row and pushes the disclosure to the trailing edge.
  final DisclosureAlignment disclosureAlignment;

  @override
  State<TechnicalDetails> createState() => _TechnicalDetailsState();
}

class _TechnicalDetailsState extends State<TechnicalDetails> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final noteStyle = ShipItType.monoMeta.copyWith(color: palette.inkTertiary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_expanded) ...[
          const MicroLabel('TECHNICAL DETAILS'),
          const SizedBox(height: 6),
          for (final line in widget.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                line,
                style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
              ),
            ),
          const SizedBox(height: 12),
        ],
        if (widget.showRule) const ContentRule(),
        const SizedBox(height: 13),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The trailing-edge case keeps the expanding note slot exactly as it
            // was, so a null note still pushes the disclosure to the far edge.
            if (widget.disclosureAlignment == DisclosureAlignment.end)
              Expanded(
                child: widget.note == null
                    ? const SizedBox.shrink()
                    : Text(widget.note!, style: noteStyle),
              )
            else if (widget.note != null)
              Flexible(child: Text(widget.note!, style: noteStyle)),
            InlineLink(
              micro: true,
              label: _expanded
                  ? 'Hide technical details'
                  : 'Show technical details',
              caret: _expanded ? CaretDirection.down : CaretDirection.right,
              onTap: () => setState(() => _expanded = !_expanded),
            ),
          ],
        ),
      ],
    );
  }
}

/// Breadcrumb + title + meta strip shared by Run detail and Decision detail.
///
/// Penpot: `Crumb` (y=26), `H1` (46), then a meta row at y=83 made of a 2px
/// status tick, an uppercase mono status, and mono facts separated by 1px
/// vertical rules, closed by `Header Rule` at y=110.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.parentLabel,
    required this.parentRef,
    required this.onParentTap,
    this.middleLabel,
    this.onMiddleTap,
    required this.title,
    this.statusLabel,
    this.statusColor,
    this.facts = const [],
    this.titleKey,
    this.showBreadcrumb = true,
    this.compact = false,
    this.titleStyle,
    this.headerGap = 11,
  });

  /// e.g. "All work" / "Needs you".
  final String parentLabel;

  /// e.g. "ref WI-9c11".
  final String parentRef;
  final VoidCallback onParentTap;
  final String? middleLabel;
  final VoidCallback? onMiddleTap;
  final String title;

  /// Uppercase, e.g. "WAITING FOR YOU". Null omits the meta strip but keeps
  /// its 14px of height, so the header rule lands where the board puts it —
  /// `BP · Create Defect` has no status row and still draws its rule at y110.
  final String? statusLabel;
  final Color? statusColor;

  /// Mono facts, e.g. "started today at 09:12", "running 3h 12m". A null
  /// colour uses the tertiary ink.
  final List<(String, Color?)> facts;

  /// Key applied to the title, so tests can assert the headline directly.
  final Key? titleKey;

  /// Mobile hides this: the shell already shows a back bar, and repeating the
  /// breadcrumb would give two ways back within 60px of each other.
  final bool showBreadcrumb;

  /// Mobile keeps the status and the single most useful fact, dropping the
  /// separator chain that cannot fit a 390px column.
  final bool compact;

  /// Overrides the headline style. The desktop boards all draw `H1` at the
  /// shared size, but `BPM · Defect Detail` sets its mobile H1 at 20/600, so
  /// the screen that board belongs to passes its own style here.
  final TextStyle? titleStyle;

  /// Space between the headline and the meta strip. `BP · Create Defect`
  /// stacks its `L Title` tighter than the detail boards do.
  final double headerGap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = statusLabel;
    final tone = statusColor ?? palette.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBreadcrumb) ...[
          Row(
            children: [
              InlineLink(label: parentLabel, onTap: onParentTap, micro: true),
              if (middleLabel != null) ...[
                Text(
                  '  /  ',
                  style: ShipItType.monoMeta.copyWith(
                    color: palette.inkTertiary,
                  ),
                ),
                InlineLink(
                  label: middleLabel!,
                  onTap: onMiddleTap ?? () {},
                  micro: true,
                ),
              ],
              Text(
                '  /  $parentRef',
                style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Text(
          title,
          key: titleKey,
          style: (titleStyle ?? ShipItType.pageTitle).copyWith(
            color: palette.inkPrimary,
          ),
        ),
        SizedBox(height: headerGap),
        if (label == null)
          const SizedBox(height: 14)
        else if (compact)
          SizedBox(
            height: 14,
            child: Row(
              children: [
                AccentTick(color: tone, height: 11),
                const SizedBox(width: 8),
                MicroLabel(label, color: tone),
                const Spacer(),
                if (facts.isNotEmpty)
                  Flexible(
                    child: Text(
                      facts.last.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShipItType.monoMeta.copyWith(
                        color: facts.last.$2 ?? palette.inkTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          )
        else
          // A Wrap rather than a Row: the board lays these on one line at
          // 1280, but the chain has no give, so a narrower window or a longer
          // timestamp would overflow it.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 0,
            runSpacing: 6,
            children: [
              SizedBox(
                height: 14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AccentTick(color: tone, height: 11),
                    const SizedBox(width: 8),
                    MicroLabel(label, color: tone),
                  ],
                ),
              ),
              for (final fact in facts)
                SizedBox(
                  height: 14,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 20),
                      Container(width: 1, height: 11, color: palette.rule),
                      const SizedBox(width: 11),
                      Text(
                        fact.$1,
                        style: ShipItType.monoMeta.copyWith(
                          color: fact.$2 ?? palette.inkTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: 13),
        const ContentRule(),
      ],
    );
  }
}

/// Label-over-value rows separated by hairlines.
///
/// Penpot `F K n` / `F V n` / `F Rule n`: key at the row top (14px), value
/// 16px below (18px), hairline 38px down — a 46px pitch.
class DefinitionList extends StatelessWidget {
  const DefinitionList({super.key, required this.entries});

  /// Key, then the value spans. Each span carries its own tone so refs can be
  /// rendered in mono alongside prose.
  final List<DefinitionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries) ...[
          const SizedBox(height: 8),
          MicroLabel(entry.label),
          const SizedBox(height: 4),
          DefaultTextStyle(
            style: (entry.prose ? ShipItType.bodySmall : ShipItType.monoMeta)
                .copyWith(color: palette.inkPrimary),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: entry.value),
                        if (entry.ref != null)
                          TextSpan(
                            text: '  ·  ${entry.ref}',
                            style: TextStyle(color: palette.inkTertiary),
                          ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const ContentRule(),
        ],
      ],
    );
  }
}

/// One row of a [DefinitionList].
class DefinitionEntry {
  const DefinitionEntry({
    required this.label,
    required this.value,
    this.ref,
    this.prose = false,
  });

  /// Uppercase mono key, e.g. "WHAT'S HELD UP".
  final String label;
  final String value;

  /// Optional trailing reference, e.g. "ref JOB-31".
  final String? ref;

  /// Renders the value as Sans prose rather than mono. The boards set most
  /// values in mono but the row that explains a wait in plain language
  /// (`WHY IT'S WAITING` on desktop, both rows on mobile) is Sans.
  final bool prose;
}

/// A bordered panel for the right-hand column (Penpot `R Panel`).
class SidePanel extends StatelessWidget {
  const SidePanel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DesignPanel(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Mono filter tabs with a 2px accent underline on the active item
/// (Penpot `Chip n` / `Chip U n`).
/// `Product: All ▾` — the board's filter disclosure link, wired.
///
/// Drawn as the board draws it, with a menu behind it. The menu opens under the
/// link so the control reads as a filter on what is below rather than as a
/// field in its own right. Shared by both registers so a product can never be
/// filtered one way in one register and another way in the other.
class ProductFilterLink extends StatelessWidget {
  const ProductFilterLink({
    super.key,
    required this.label,
    required this.products,
    required this.onChanged,
  });

  /// What the control currently reads, e.g. `Product: All` or `Product: Cart`.
  final String label;

  /// Every product, `id` / `name`, so the menu keeps offering them all while
  /// one is selected.
  final List<(String, String)> products;

  /// Empty string means "all products".
  final ValueChanged<String> onChanged;

  /// `Product: All` / `Product: <name>` for the given filter and product list.
  ///
  /// A product that has since been removed shows its id rather than silently
  /// reading as "all".
  static String labelFor(String? productId, List<(String, String)> products) {
    if (productId == null) return 'Product: All';
    for (final (id, name) in products) {
      if (id == productId) return 'Product: $name';
    }
    return 'Product: $productId';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PopupMenuButton<String>(
      tooltip: 'Filter by product',
      // The link supplies its own padding; the button must not add any.
      padding: EdgeInsets.zero,
      elevation: 0,
      color: palette.card,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShipItMetrics.radius),
        side: BorderSide(color: palette.cardBorder),
      ),
      onSelected: onChanged,
      itemBuilder: (context) => [
        const PopupMenuItem<String>(value: '', child: Text('All products')),
        for (final (id, name) in products)
          PopupMenuItem<String>(
            value: id,
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      child: InlineLink(label: label, caret: CaretDirection.down),
    );
  }
}

/// A tab in the Reports `Tab Group` treatment.
///
/// The board draws each tab as a block with a 2px accent rule spanning the
/// whole block at its trailing edge, and the inactive tab greyed with no rule
/// at all. Reproducing it as a block rather than underlining the text is what
/// makes the tabs read as peers rather than as a subordinate filter — `Defects`
/// and `Feature requests` are the same kind of thing, and `Bug` and `Feature`
/// are the same kind of choice.
///
/// 32px tall: 14px of type, breathing room, 2px of rule.
class TabUnderline extends StatelessWidget {
  const TabUnderline({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: ShipItType.ref.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? palette.inkPrimary : palette.inkTertiary,
                  ),
                ),
                const Spacer(),
                Container(
                  height: ShipItMetrics.tickWidth,
                  color: active ? palette.accentTick : const Color(0x00000000),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of [TabUnderline]s in the Reports treatment, 24px apart.
///
/// Shared by the two register headers and the two intake forms so a tab cannot
/// look one way in a list and another way on the form it opens.
class TabUnderlineRow extends StatelessWidget {
  const TabUnderlineRow({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 24),
          TabUnderline(
            label: labels[i],
            active: i == activeIndex,
            onTap: () => onSelected(i),
          ),
        ],
      ],
    );
  }
}

class FilterTabs extends StatelessWidget {
  const FilterTabs({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 26),
            child: Semantics(
              button: true,
              selected: i == activeIndex,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onSelected(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labels[i],
                        style: ShipItType.ref.copyWith(
                          fontWeight: i == activeIndex
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: i == activeIndex
                              ? palette.inkPrimary
                              : palette.inkTertiary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: ShipItMetrics.tickWidth,
                        color: i == activeIndex
                            ? palette.accentTick
                            : const Color(0x00000000),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
