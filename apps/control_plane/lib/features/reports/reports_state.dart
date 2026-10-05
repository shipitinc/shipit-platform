/// Which register the Reports surface is showing.
///
/// Reports is one surface with two registers, not two surfaces: the fifth
/// destination is `Reports`, and `Defects` / `Feature requests` are the tabs
/// within it. A feature request is filed against the same products, reviewed
/// by the same people, and shown in the same register grid, so splitting it
/// into its own destination would have cost a sixth nav item to say less.
enum ReportsTab {
  defects('Defects', 'defects'),
  featureRequests('Feature requests', 'features');

  const ReportsTab(this.label, this.paramValue);

  /// Tab copy, transcribed from `Tab - Defects` / `Tab - Features` on the
  /// Reports boards.
  final String label;

  /// Value carried in the `?tab=` query parameter.
  ///
  /// Stable strings rather than enum indexes, so a shared link keeps pointing
  /// at the same register if a tab is ever inserted.
  final String paramValue;

  /// The tab [paramValue] names, or the first tab when it names none.
  ///
  /// An unrecognised value resolves to the default rather than throwing: a
  /// stale link should land on the Defects register, not on a crash.
  static ReportsTab fromParam(String? value) {
    for (final tab in values) {
      if (tab.paramValue == value) return tab;
    }
    return ReportsTab.defects;
  }
}

/// Which register an intake form is filing into.
///
/// The two forms share one screen and one tab row; this is the "which tab is
/// underlined" decision, kept separate from [ReportsTab] so a form can state
/// its own kind without also choosing which register the list should show
/// afterwards.
enum IntakeKind {
  bug('Bug', 'defects'),
  feature('Feature', 'features');

  const IntakeKind(this.label, this.tabParamValue);

  /// Singular tab copy. The forms are titled for one act — report a bug, or
  /// request a feature — so the tab reads `Bug` / `Feature` here while the
  /// register tabs read `Defects` / `Feature requests`.
  final String label;

  /// The [ReportsTab.paramValue] of the register this kind files into.
  final String tabParamValue;

  ReportsTab get tab => ReportsTab.fromParam(tabParamValue);
}
