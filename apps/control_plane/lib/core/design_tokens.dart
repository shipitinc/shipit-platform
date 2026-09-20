import 'package:flutter/material.dart';

/// Design tokens transcribed directly from the Penpot source of truth
/// (`control-plane-operator-ui.planning`, boards `BP · … · Light` and
/// `BP · … · Dark`).
///
/// Every value in this file was read out of the design file via the Penpot
/// plugin API — none of it is invented. When the design changes, re-read the
/// board and update here; do not "improve" values locally.
///
/// The two palettes are structurally identical: the design is one system with
/// an inverted surface/ink ramp, so [ShipItPalette] is the single seam the
/// widgets depend on.
@immutable
class ShipItPalette extends ThemeExtension<ShipItPalette> {
  const ShipItPalette({
    required this.canvas,
    required this.rail,
    required this.rule,
    required this.ruleStrong,
    required this.card,
    required this.cardBorder,
    required this.controlBorder,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.accent,
    required this.accentTick,
    required this.attention,
    required this.attentionTick,
    required this.positive,
    required this.negative,
  });

  /// Page background. Penpot: board fill.
  final Color canvas;

  /// Left navigation rail background. Penpot: `Rail Bg`.
  final Color rail;

  /// 1px hairline rules and dividers. Penpot: `Rail Rule`, `Row Rule`.
  final Color rule;

  /// Heavier rule used under table headers. Penpot: `Table Head Rule`.
  final Color ruleStrong;

  /// Raised panel fill. Penpot: `Gate Bg`.
  final Color card;

  /// Panel hairline border. Penpot: `Gate Bg` stroke.
  final Color cardBorder;

  /// Outlined control border. Penpot: `Gate Btn` stroke.
  final Color controlBorder;

  /// Titles, values, row titles.
  final Color inkPrimary;

  /// Body copy, refs, inactive navigation.
  final Color inkSecondary;

  /// Micro labels, descriptions, timestamps.
  final Color inkTertiary;

  /// Links, active navigation, "working on it". Text-safe tone.
  final Color accent;

  /// Accent used for 2px ticks and fills (vivid in both themes).
  final Color accentTick;

  /// "Needs you" / waiting. Text-safe tone.
  final Color attention;

  /// Attention tick fill (vivid amber in both themes).
  final Color attentionTick;

  /// Finished / approved.
  final Color positive;

  /// Failed / rejected.
  final Color negative;

  /// Penpot `BP · … · Light`.
  static const ShipItPalette light = ShipItPalette(
    canvas: Color(0xFFF7F7F5),
    rail: Color(0xFFEFEFEC),
    rule: Color(0xFFDEDEDA),
    ruleStrong: Color(0xFFC4C4BF),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFDEDEDA),
    controlBorder: Color(0xFFC4C4BF),
    inkPrimary: Color(0xFF1F2120),
    inkSecondary: Color(0xFF5A5C5B),
    inkTertiary: Color(0xFF6E706E),
    accent: Color(0xFF1668D6),
    accentTick: Color(0xFF1668D6),
    attention: Color(0xFFA35F00),
    attentionTick: Color(0xFFF7A42C),
    positive: Color(0xFF0E7A56),
    negative: Color(0xFFC22B28),
  );

  /// Penpot `BP · … · Dark`.
  static const ShipItPalette dark = ShipItPalette(
    canvas: Color(0xFF1F2120),
    rail: Color(0xFF1A1C1B),
    rule: Color(0xFF383A39),
    ruleStrong: Color(0xFF4A4C4B),
    card: Color(0xFF262827),
    cardBorder: Color(0xFF383A39),
    controlBorder: Color(0xFF4A4C4B),
    inkPrimary: Color(0xFFF5F4F0),
    inkSecondary: Color(0xFFA8A6A0),
    inkTertiary: Color(0xFF8A8983),
    accent: Color(0xFF4496FC),
    accentTick: Color(0xFF4496FC),
    attention: Color(0xFFF7A42C),
    attentionTick: Color(0xFFF7A42C),
    positive: Color(0xFF6FFFCE),
    negative: Color(0xFFE93E3A),
  );

  @override
  ShipItPalette copyWith({
    Color? canvas,
    Color? rail,
    Color? rule,
    Color? ruleStrong,
    Color? card,
    Color? cardBorder,
    Color? controlBorder,
    Color? inkPrimary,
    Color? inkSecondary,
    Color? inkTertiary,
    Color? accent,
    Color? accentTick,
    Color? attention,
    Color? attentionTick,
    Color? positive,
    Color? negative,
  }) {
    return ShipItPalette(
      canvas: canvas ?? this.canvas,
      rail: rail ?? this.rail,
      rule: rule ?? this.rule,
      ruleStrong: ruleStrong ?? this.ruleStrong,
      card: card ?? this.card,
      cardBorder: cardBorder ?? this.cardBorder,
      controlBorder: controlBorder ?? this.controlBorder,
      inkPrimary: inkPrimary ?? this.inkPrimary,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkTertiary: inkTertiary ?? this.inkTertiary,
      accent: accent ?? this.accent,
      accentTick: accentTick ?? this.accentTick,
      attention: attention ?? this.attention,
      attentionTick: attentionTick ?? this.attentionTick,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
    );
  }

  @override
  ShipItPalette lerp(ThemeExtension<ShipItPalette>? other, double t) {
    if (other is! ShipItPalette) return this;
    return ShipItPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      rail: Color.lerp(rail, other.rail, t)!,
      rule: Color.lerp(rule, other.rule, t)!,
      ruleStrong: Color.lerp(ruleStrong, other.ruleStrong, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      controlBorder: Color.lerp(controlBorder, other.controlBorder, t)!,
      inkPrimary: Color.lerp(inkPrimary, other.inkPrimary, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkTertiary: Color.lerp(inkTertiary, other.inkTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentTick: Color.lerp(accentTick, other.accentTick, t)!,
      attention: Color.lerp(attention, other.attention, t)!,
      attentionTick: Color.lerp(attentionTick, other.attentionTick, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
    );
  }
}

/// Typeface families as bundled in `assets/fonts` and declared in `pubspec.yaml`.
class ShipItFonts {
  ShipItFonts._();

  /// Brand wordmark only. Variable font — instance the axis with
  /// [brandVariations] because pubspec weight declarations do not select an
  /// instance on a variable font.
  static const String brand = 'Orbitron';
  static const List<FontVariation> brandVariations = [
    FontVariation('wght', 700),
  ];

  /// Interface typeface: titles, row titles, body copy, buttons.
  static const String sans = 'IBM Plex Sans';

  /// Refs, micro labels, statuses, numerals, durations, technical detail.
  static const String mono = 'IBM Plex Mono';
}

/// Layout constants read from the Penpot board geometry (1280×900).
class ShipItMetrics {
  ShipItMetrics._();

  /// `Rail Bg` width; the 1px `Rail Divider` sits on its trailing edge.
  static const double railWidth = 200;

  /// Rail inner gutter (`Brand Logomark`/`Rail Rule` x = 20).
  static const double railGutter = 20;

  /// Nav label inset. The board places labels at x=30 with the active mark at
  /// the 20px gutter; reviewed in-product, the labels are instead aligned to
  /// the same 20px gutter as every other rail element, which puts the active
  /// mark at [railActiveMarkInset].
  static const double railNavInset = ShipItMetrics.railGutter;

  /// Left offset of the 2px active-row mark, in the rail's outer margin.
  static const double railActiveMarkInset = 8;

  /// Content gutter: `H1` x = 236, rail is 200 → 36px inside the content pane.
  static const double contentGutter = 36;

  /// `Header Rule` width — the content column (236 → 1256).
  static const double contentWidth = 1020;

  /// Metric column pitch (236 → 576 → 916).
  static const double metricPitch = 340;

  /// 2px colour ticks (`Row Tick`, `Metric Tick`, `Gate Edge`).
  static const double tickWidth = 2;

  /// `Metric Tick` height.
  static const double metricTickHeight = 10;

  /// `Row Tick` height.
  static const double rowTickHeight = 18;

  /// Table row pitch (306 → 352 → 398 → 444).
  static const double rowPitch = 46;

  /// Panel corner radius (`Gate Bg` r = 3).
  static const double radius = 3;

  /// Hairline thickness.
  static const double hairline = 1;

  // --- Mobile (`BPM ·` boards, 390x844) ---------------------------------

  /// Below this width the mobile composition is used: a top bar and a bottom
  /// navigation bar instead of the rail.
  static const double mobileBreakpoint = 840;

  /// Width of the detail screens' right-hand panel (`R Panel`).
  static const double sidePanelWidth = 392;

  /// Gap between the detail columns.
  static const double sidePanelGap = 32;

  /// Minimum width the left column needs before the side panel is worth
  /// keeping alongside it. Below this the columns stack, which is what
  /// happens between the mobile breakpoint and a comfortable desktop — a
  /// range the design does not draw.
  static const double sidePanelMinContent = 380;

  /// Mobile content gutter (`H1` x = 16).
  static const double mobileGutter = 16;

  /// `Top Bg` height; a 1px rule sits on its bottom edge.
  static const double mobileTopBarHeight = 56;

  /// `Nav Bg` height.
  static const double mobileNavBarHeight = 80;

  /// Metric column pitch on mobile (16 -> 140 -> 264).
  static const double mobileMetricPitch = 124;

  /// Compact list row pitch (592 -> 630 -> 668).
  static const double mobileRowPitch = 38;

  /// Table column offsets relative to the content column origin.
  static const double colRefInset = 12; // Row Id x=248 vs tick x=236
  static const double colWhat = 100; // 336 - 236
  static const double colStatus = 580; // 816 - 236
  static const double colElapsed = 780; // 1016 - 236
  static const double colElapsedWidth = 100;
  static const double colAction = 910; // 1146 - 236
}

/// Text styles transcribed from the Penpot text shapes. Colour is applied by
/// the call site from [ShipItPalette] so a single style serves both themes.
///
/// Every style carries `height: 1.2` because the design sets line height 1.2
/// on every text node.
class ShipItType {
  ShipItType._();

  static const double _lh = 1.2;

  /// `Wordmark` — Orbitron 13 / 700 / ls 0.4.
  static const TextStyle brand = TextStyle(
    fontFamily: ShipItFonts.brand,
    fontVariations: ShipItFonts.brandVariations,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    height: _lh,
  );

  /// `Wordmark Sub`, `Rail Section` — Mono 9 / 500 / ls 1.1, uppercase.
  static const TextStyle railMicro = TextStyle(
    fontFamily: ShipItFonts.mono,
    fontSize: 9,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.1,
    height: _lh,
  );

  /// `H1` — Sans 24 / 600 / ls -0.5.
  static const TextStyle pageTitle = TextStyle(
    fontFamily: ShipItFonts.sans,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: _lh,
  );

  /// `H1 Sub` — Sans 12 / 400.
  static const TextStyle pageSubtitle = TextStyle(
    fontFamily: ShipItFonts.sans,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: _lh,
  );

  /// `Table Title`, `Gates Title` — Sans 13 / 600.
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: ShipItFonts.sans,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: _lh,
  );

  /// `Queue Title` — Sans 12 / 600.
  static const TextStyle sectionTitleSmall = TextStyle(
    fontFamily: ShipItFonts.sans,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: _lh,
  );

  /// `LIVE`, `Metric Key`, `Col · …` — Mono 9 / 600 / ls 1.1, uppercase.
  static const TextStyle microLabel = TextStyle(
    fontFamily: ShipItFonts.mono,
    fontSize: 9,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
    height: _lh,
  );

  /// `Metric Val` — Mono 40 / 300 / ls -1.
  static const TextStyle metricValue = TextStyle(
    fontFamily: ShipItFonts.mono,
    fontSize: 40,
    fontWeight: FontWeight.w300,
    letterSpacing: -1,
    height: _lh,
  );

  /// `Metric Desc` — Sans 11 / 400.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: ShipItFonts.sans,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: _lh,
  );

  /// `Job Desc`, `Capacity Sub` — Sans 10 / 400.
  static const TextStyle bodyMicro = TextStyle(
    fontFamily: ShipItFonts.sans,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: _lh,
  );

  /// `Row Title`, `Nav · …` — Sans 13 / 400.
  static const TextStyle rowTitle = TextStyle(
    fontFamily: ShipItFonts.sans,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: _lh,
  );

  /// Active nav label — Sans 13 / 600.
  static const TextStyle navActive = TextStyle(
    fontFamily: ShipItFonts.sans,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: _lh,
  );

  /// `Gate Q` — Sans 14 / 500.
  static const TextStyle question = TextStyle(
    fontFamily: ShipItFonts.sans,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: _lh,
  );

  /// `Table Link`, `Row Open`, `Gate Btn Label` — Sans 11 / 500.
  static const TextStyle link = TextStyle(
    fontFamily: ShipItFonts.sans,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: _lh,
  );

  /// `Disclose` — Sans 10 / 500.
  static const TextStyle linkMicro = TextStyle(
    fontFamily: ShipItFonts.sans,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: _lh,
  );

  /// `Row Id`, `Nav Count` — Mono 11 / 500.
  static const TextStyle ref = TextStyle(
    fontFamily: ShipItFonts.mono,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: _lh,
  );

  /// `Gate Id` — Mono 11 / 600.
  static const TextStyle refStrong = TextStyle(
    fontFamily: ShipItFonts.mono,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: _lh,
  );

  /// `Row Age` — Mono 11 / 400.
  static const TextStyle duration = TextStyle(
    fontFamily: ShipItFonts.mono,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: _lh,
  );

  /// `Row State`, `Job State`, `Gate Expiry` — Mono 10 / 500.
  static const TextStyle status = TextStyle(
    fontFamily: ShipItFonts.mono,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: _lh,
  );

  /// Mobile metric numeral — Mono 28 / 300.
  static const TextStyle metricValueMobile = TextStyle(
    fontFamily: ShipItFonts.mono,
    fontSize: 28,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.5,
    height: _lh,
  );

  /// Mobile row title — Sans 12 / 400.
  static const TextStyle rowTitleMobile = TextStyle(
    fontFamily: ShipItFonts.sans,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: _lh,
  );

  /// Mobile nav label — Sans 10 / 400 (600 when active).
  static const TextStyle navLabelMobile = TextStyle(
    fontFamily: ShipItFonts.sans,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: _lh,
  );

  /// Filled button label on mobile — Sans 11 / 600.
  static const TextStyle buttonLabelMobile = TextStyle(
    fontFamily: ShipItFonts.sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: _lh,
  );

  /// `Live Sub`, `Gate Type`, `Footer` — Mono 10 / 400.
  static const TextStyle monoMeta = TextStyle(
    fontFamily: ShipItFonts.mono,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: _lh,
  );
}
