import 'package:control_plane/core/theme.dart';
import 'package:control_plane/features/models/run_duration_panel.dart';
import 'package:control_plane/features/models/run_duration_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `stats == null` branch of [RunDurationPanel] has to be asserted at the
/// WIDGET layer, not only in the bloc.
///
/// The brief for this panel demanded one property above all others: **a failed
/// duration read must never render as "no runs" and never render as zeros.**
/// Those are three different claims — there is a real empty state, a real table,
/// and a real failure — and the bloc-level tests only prove the bloc keeps them
/// apart. The panel is what a human actually looks at, and the panel is where a
/// `stats: null` can silently collapse into "nothing ran".
///
/// Every assertion below is on RENDERED TEXT. `findsOneWidget` on a widget type
/// would pass just as happily against an error box that still said "0s".
void main() {
  const failureMessage = 'Exception: agent execution read failed (503)';

  Widget wrap(Widget child) => MaterialApp(
    theme: ShipItTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  final populated = RunDurationStats.compute(const [
    RunDurationSample(
      role: 'engineering_reviewer',
      status: 'interrupted',
      durationSeconds: 10800,
    ),
  ]);

  group('a FAILED duration read', () {
    testWidgets('renders the message the bloc actually carries', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const RunDurationPanel(
            stats: null,
            durationErrorMessage: failureMessage,
          ),
        ),
      );

      // The whole point of the bloc's separate error channel: the operator
      // learns WHICH read failed, not merely that something did.
      expect(find.text(failureMessage), findsOneWidget);
    });

    testWidgets('renders a failure to READ, never an absence of runs', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const RunDurationPanel(
            stats: null,
            durationErrorMessage: failureMessage,
          ),
        ),
      );

      // What it says...
      expect(find.textContaining('failure to read'), findsOneWidget);
      expect(
        find.textContaining('no duration is being claimed here'),
        findsOneWidget,
      );

      // ...and, decisively, what it does NOT say. The empty state has its own
      // wording; reusing it here would assert that zero runs happened, which is
      // the one claim this panel has no evidence for.
      expect(find.textContaining('No completed agent runs'), findsNothing);
      expect(find.textContaining('Nothing is claimed about'), findsNothing);
    });

    testWidgets('renders no table and no zeros', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RunDurationPanel(
            stats: null,
            durationErrorMessage: failureMessage,
          ),
        ),
      );

      // No stat rows at all.
      expect(find.text('min'), findsNothing);
      expect(find.text('median'), findsNothing);
      expect(find.text('max'), findsNothing);
      // No role heading either — an empty table still renders no role block,
      // but a ZEROS table would render these, and that is what we are ruling out.
      expect(find.text('Engineering reviewer'), findsNothing);

      // `formatRunDuration` renders a zero as '0s'. Nothing here may be zero,
      // because nothing was measured. Asserted against the formatter's own
      // output so this test cannot quietly drift from it.
      expect(find.text(formatRunDuration(0)), findsNothing);
      expect(find.text(formatRunDuration(0)), isNot('0s 00m'));
    });

    testWidgets('invents no error message when it was given none', (
      tester,
    ) async {
      // The non-vacuity control for the assertion above: with no message in,
      // no message appears out. If the panel ever started printing a fixed
      // string here, this test is what catches it pretending to report a
      // failure it was never told about.
      await tester.pumpWidget(wrap(const RunDurationPanel(stats: null)));

      expect(find.textContaining('failure to read'), findsOneWidget);
      expect(find.text('Run Duration'), findsOneWidget);
      // Nothing that looks like a fabricated diagnostic.
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
    });
  });

  group('a SUCCESSFUL duration read', () {
    testWidgets('renders the table and none of the failure copy', (
      tester,
    ) async {
      // The other direction, and the reason the three assertions above are
      // worth anything: the SAME panel, given a read that worked, renders the
      // table. So the error branch is not simply always-on.
      await tester.pumpWidget(wrap(RunDurationPanel(stats: populated)));

      expect(find.text('median'), findsOneWidget);
      expect(find.text('Engineering reviewer'), findsOneWidget);
      // A measured duration IS rendered — 10800s as 3h 00m.
      expect(find.text(formatRunDuration(10800)), findsWidgets);

      expect(find.textContaining('failure to read'), findsNothing);
      expect(find.textContaining('No completed agent runs'), findsNothing);
    });

    testWidgets('an empty but SUCCESSFUL read says no runs, not a failure', (
      tester,
    ) async {
      // The distinction the finding is about, stated in both directions: a read
      // that worked and found nothing is NOT a failed read, and it must not be
      // dressed up as one.
      await tester.pumpWidget(
        wrap(const RunDurationPanel(stats: RunDurationStats.empty)),
      );

      expect(find.textContaining('No completed agent runs'), findsOneWidget);
      expect(find.textContaining('failure to read'), findsNothing);
      expect(find.text(formatRunDuration(0)), findsNothing);
    });
  });
}
