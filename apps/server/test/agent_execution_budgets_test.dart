import 'dart:io';

import 'package:control_plane_server/server.dart';
import 'package:test/test.dart';

/// The range the operator stated for a review run, in minutes.
///
/// Named once HERE so the assertions below and the failure messages that quote
/// them cannot disagree. The same range is also written in prose in the
/// `byRole` header in `server.dart`, and that copy is NOT machine-checked
/// against this one: if the operator ever restates the range, both have to
/// move, and this test is the signal that the budget stopped matching the
/// claim — not that the prose went stale.
const int _statedReviewMinMinutes = 15;
const int _statedReviewMaxMinutes = 30;

/// The agent-execution budgets are guarded as LITERALS, on purpose.
///
/// ## Why this file exists at all
///
/// The engineering-review budget used to be a typed-in `300` in
/// `engineering_review_gate.dart` with no justification anywhere in the
/// repository — no comment, no ticket, no measurement. It was also below the
/// operator's stated floor for the role (a review takes 15–30 minutes here), so
/// it was not a tight ceiling; it was a value that killed every review.
///
/// The failure mode this guards is not "someone picks a different number". It
/// is "someone picks a different number and it reads like a finding" — because
/// there is nothing on the page to say whether the current value was measured
/// or guessed. So the guard is not only the value: it is the PROVENANCE, and it
/// is asserted at the source level because provenance is not observable at
/// runtime.
void main() {
  late String serverSource;
  late String reviewGateSource;

  setUpAll(() {
    final marker = Directory.current;
    var dir = marker;
    while (dir.parent.path != dir.path) {
      final server = File('${dir.path}/apps/server/lib/server.dart');
      if (server.existsSync()) {
        serverSource = server.readAsStringSync();
        reviewGateSource = File(
          '${dir.path}/apps/server/lib/src/review/engineering_review_gate.dart',
        ).readAsStringSync();
        return;
      }
      dir = dir.parent;
    }
    fail('could not locate apps/server/lib/server.dart above ${marker.path}');
  });

  group('the values are what this lane claims they are', () {
    test(
      'engineering review gets 1 hour, 2x the stated 15-30 minute maximum',
      () {
        expect(
          AgentExecutionBudgets.engineeringReviewSeconds,
          1 * 60 * 60,
          reason:
              'operator-stated: a review here, through opencode, takes '
              '$_statedReviewMinMinutes-$_statedReviewMaxMinutes minutes. 1h is '
              '2x the stated maximum, so variance and a larger diff do not reach '
              'the ceiling. It replaced 3h after a review burned that whole '
              'budget to produce nothing, and the next one returned in 2 minutes '
              'with a verdict.',
        );
        // `expect(x, 1 * 60 * 60)` on its own says nothing about WHY 1h, and
        // this file's own thesis is that a number reads like a finding whether
        // or not anything measured it. So the value is pinned as a literal AND
        // restated as the relationship it is supposed to bear to the operator's
        // stated range, computed from the TABLE against the named constants at
        // the top of this file.
        //
        // Stated plainly, because it is easy to oversell: once the literal
        // above holds, these two assertions are the SAME constraint written
        // differently and add no discriminating power. What they buy is the
        // shape of the edit — when the budget moves, what has to move with it
        // is the CLAIM ("2x the stated maximum"), not just a number nobody can
        // interpret. It is not decoration either: change `_statedReviewMaxMinutes`
        // and this fails on the relationship while 3600 is still the budget.
        final budgetMinutes =
            AgentExecutionBudgets.byRole['engineering-review']!.inMinutes;
        expect(
          budgetMinutes,
          greaterThan(_statedReviewMaxMinutes),
          reason:
              'a ceiling at or below the stated maximum kills runs that were '
              'never slow. That is the 300s defect in its general form, and it '
              'is the invariant — not any particular number.',
        );
        expect(
          budgetMinutes - _statedReviewMaxMinutes,
          _statedReviewMaxMinutes,
          reason:
              'the headroom over the stated maximum is pinned deliberately: 2x '
              'absorbs ordinary variance and a larger diff, and pinning the '
              'FACTOR means the next widening of this budget has to move this '
              'test rather than slide past it. The 6x that preceded it satisfies '
              '"at least 2x" and buys nothing this deployment can point to; 1x '
              'is not headroom at all.',
        );
      },
    );

    test(
      'implementation gets 4 hours, from the stated "routinely exceeds 30m"',
      () {
        expect(
          AgentExecutionBudgets.implementationSeconds,
          4 * 60 * 60,
          reason:
              'operator-stated: an implementation run ROUTINELY EXCEEDS the '
              '1800s it used to carry, and a ceiling of a few hours per agent '
              'run is the right order of magnitude.',
        );
      },
    );

    test('triage gets 30 minutes, and is named as the weakest value', () {
      expect(
        AgentExecutionBudgets.triageSeconds,
        30 * 60,
        reason:
            'no operator-stated range exists for triage. 30m is the operator\'s '
            'stated LOWER bound for the slowest role they named, adopted as a '
            'common floor. The comment in the table says this is the weakest '
            'number here, and this test is the thing that keeps it true.',
      );
    });

    test('the three budgets are distinct, so no role inherits another by '
        'accident', () {
      final values = AgentExecutionBudgets.byRole.values
          .map((d) => d.inSeconds)
          .toSet();
      expect(
        values.length,
        AgentExecutionBudgets.byRole.length,
        reason:
            'two roles sharing a budget is fine only if it was decided. '
            'Today it is not, and two lanes running under one accidental '
            'number is indistinguishable from one lane being mis-set.',
      );
    });
  });

  group('the values are PROVISIONAL, and say so at the call site', () {
    test('every entry in the table is introduced by ITS OWN PROVISIONAL marker', () {
      // BIND each role to its own header. Do NOT count markers.
      //
      // This test used to count the matching `PROVISIONAL.` lines and compare
      // the count to the number of roles. That count is satisfiable by ANY
      // comment: deleting triage's real header and writing `// TODO —
      // PROVISIONAL.` in its place leaves the count at 3, so the test passed on
      // a table in which triage's budget carried no provenance at all. That is
      // the exact failure mode commit 362d047 exists to eliminate — a comment
      // satisfying a source grep — reproduced in the sibling guard in this very
      // file, on the branch whose thesis is "a number whose provenance cannot be
      // stated is worse than no number".
      //
      // The negative assertions elsewhere in this file are immune to that attack
      // (`timeoutSeconds:\s*\d+` must find nothing, and a comment cannot make
      // something be found by a "must not match"). THIS one is positive, so it
      // has to carry the role inside the pattern.
      final table = serverSource.substring(
        serverSource.indexOf('static const Map<String, Duration> byRole'),
        serverSource.indexOf('static int get triageSeconds'),
      );
      final ownHeaders = <String, String>{};
      for (final role in AgentExecutionBudgets.byRole.keys) {
        final keyAt = table.indexOf("'$role':");
        expect(
          keyAt,
          greaterThan(-1),
          reason: 'the table must actually declare $role',
        );
        // The NEAREST header above this role's own entry is the one that
        // introduces it; anything above that belongs to an earlier role. This is
        // what makes the binding positional rather than merely global.
        final headers = _provisionalHeader.allMatches(
          table.substring(0, keyAt),
        );
        expect(
          headers,
          isNotEmpty,
          reason:
              '$role has no `// <ROLE NAME> — … PROVISIONAL.` header above its '
              'own entry. A budget with no marker is precisely what this file '
              'exists to forbid.',
        );
        final own = headers.last.group(1)!;
        expect(
          _namesRole(own, role),
          isTrue,
          reason:
              "the header introducing $role must name $role, and it read: "
              '"$own". A marker that names some OTHER role — or names nothing — '
              'satisfies a count while telling a reader of $role nothing.',
        );
        ownHeaders[role] = own;
      }
      // One marker per role, and no marker doing two roles' work.
      expect(
        ownHeaders.values.toSet().length,
        ownHeaders.length,
        reason:
            'each role needs its OWN header: $ownHeaders. One header shared by '
            'two roles is the same defect as a count, one level down.',
      );
      // Kept as a SECONDARY invariant only, and it is worth being explicit that
      // it cannot be the guard: after the attack above, this count is still 3
      // and still passes. It is here so that a fourth role added without a
      // header, or a header orphaned from every role, is still noticed.
      expect(
        _provisionalHeader.allMatches(table).length,
        AgentExecutionBudgets.byRole.length,
        reason:
            'each role\'s comment must lead with its name and end the header '
            'line with PROVISIONAL. The worst outcome of this change is the '
            'next person reading a budget and assuming somebody measured it — '
            'which is exactly how 300 got there.',
      );
      expect(
        RegExp(r'OPERATOR-STATED').allMatches(table).length,
        greaterThanOrEqualTo(2),
        reason:
            'review and implementation both come from a stated range and must '
            'say which one. Triage does NOT come from a stated range, and its '
            'comment says so rather than implying one.',
      );
      expect(
        table,
        contains('NO OPERATOR-STATED RANGE EXISTS'),
        reason:
            'triage is the one value with no operator statement behind it. '
            'Silently presenting it like the other two is how a guess becomes '
            'a finding.',
      );
    });

    test(
      'the startup banner prints the budgets AND says they are provisional',
      () {
        final described = AgentExecutionBudgets.describe();
        expect(
          described['provisional'],
          contains('NO DURATION DATA EXISTED'),
          reason:
              'the runtime banner is where an operator will actually look. A '
              'provisional number nothing prints is a number nobody re-derives.',
        );
        expect(
          described['byRoleSeconds'],
          AgentExecutionBudgets.byRole.map(
            (k, v) => MapEntry(k, v.inSeconds),
          ),
        );
      },
    );

    test('the banner reads the staleness bound back off the live scheduler', () {
      // A banner that prints the TABLE's staleness bound rather than the
      // scheduler's could describe a window the dispatching object does not
      // have. The wiring test below is what keeps them equal; this asserts the
      // banner is fed from the scheduler at all.
      expect(
        serverSource,
        contains("'stalenessBoundInForce': {"),
        reason: 'the bound in force must be read off the live schedulers',
      );
      expect(serverSource, contains('scheduler.zombieStalenessBound'));
      expect(serverSource, contains('reviewScheduler.zombieStalenessBound'));
      expect(serverSource, contains('implScheduler.zombieStalenessBound'));
    });
  });

  group('there is exactly ONE place these are set', () {
    test('no integer literal is passed as timeoutSeconds in the composition', () {
      // Every `timeoutSeconds:` argument in server.dart must name the table.
      // A bare number here is a second budget that nobody will re-derive when
      // this one changes.
      final literals = RegExp(
        r'timeoutSeconds:\s*(\d+)',
        multiLine: true,
      ).allMatches(serverSource).toList();
      expect(
        literals,
        isEmpty,
        reason:
            'found ${literals.map((m) => m.group(0)).join(', ')}. Budgets come '
            'from AgentExecutionBudgets, which is where the provenance lives.',
      );
    });

    test('the review gate holds no budget of its own', () {
      expect(
        RegExp(r'timeoutSeconds:\s*\d+').hasMatch(reviewGateSource),
        isFalse,
        reason:
            'the `300` that lived here is the defect this change exists to '
            'fix. The resolver now REQUIRES the caller to name the budget, so '
            'there is nowhere in this file for a second copy to hide.',
      );
      expect(
        reviewGateSource,
        contains('required int timeoutSeconds'),
        reason:
            'required, not optional-with-a-default: an optional parameter '
            'would put a default value back in this file, which is the shape '
            'the defect had.',
      );
      expect(reviewGateSource, contains('INJECTED, not declared here'));
    });

    test('the probe, the review resolver and the inert static workloads all '
        'read the same table', () {
      expect(
        RegExp(
          r'AgentExecutionBudgets\.(implementationSeconds|'
          r'engineeringReviewSeconds|triageSeconds)',
        ).allMatches(serverSource).length,
        greaterThanOrEqualTo(5),
        reason:
            'three call sites must name a table value: the readiness probe '
            '(which actually runs an implementer), the review resolver, and '
            'the inert static workloads. Falling short means one of them '
            'grew its own literal.',
      );
    });
  });

  group('the staleness bound is decoupled from the budget', () {
    test('zombieStalenessFor is budget + allowance, never budget * 4', () {
      expect(
        AgentExecutionBudgets.zombieStalenessFor(const Duration(minutes: 30)),
        const Duration(minutes: 90),
      );
      expect(
        AgentExecutionBudgets.zombieStalenessFor(const Duration(hours: 3)),
        const Duration(hours: 4),
      );
      expect(
        AgentExecutionBudgets.zombieStalenessFor(const Duration(hours: 4)),
        const Duration(hours: 5),
      );
    });

    test('the Scheduler default formula would have been catastrophic here', () {
      // `Scheduler.zombieStalenessBound` defaults to
      // `timeoutSeconds * 4 + claimLease`, with a 10-minute default lease.
      const claimLeaseSeconds = 10 * 60;
      Duration schedulerDefault(Duration agentBudget) =>
          Duration(seconds: agentBudget.inSeconds * 4) +
          const Duration(seconds: claimLeaseSeconds);

      for (final entry in AgentExecutionBudgets.byRole.entries) {
        final ours = AgentExecutionBudgets.zombieStalenessFor(entry.value);
        final theirs = schedulerDefault(entry.value);
        expect(
          ours.inSeconds,
          lessThan(theirs.inSeconds),
          reason:
              '${entry.key}: at ${entry.value.inMinutes}m the default formula '
              'gives ${theirs.inHours.toStringAsFixed(1)}h and would hold a '
              'dead execution\'s claim and capacity slot for that long. The '
              'sum gives ${ours.inHours.toStringAsFixed(1)}h.',
        );
        // And the bound must still EXCEED the budget, or a legitimately long
        // run is reclaimed for being slow.
        expect(
          ours.inSeconds,
          greaterThan(entry.value.inSeconds),
          reason:
              '${entry.key}: the bound has to exceed the agent budget, which '
              'is the entire reason it cannot be decoupled from it entirely.',
        );
      }
    });

    test('every scheduler in the composition is given an explicit bound', () {
      for (final id in [
        "final scheduler = Scheduler(",
        "final reviewScheduler = Scheduler(",
        "final implScheduler = Scheduler(",
      ]) {
        final start = serverSource.indexOf(id);
        expect(start, greaterThan(-1), reason: 'composition must build $id');
        final end = serverSource.indexOf('\n  );', start);
        expect(end, greaterThan(start));
        final body = serverSource.substring(start, end);
        expect(
          body,
          contains('zombieStalenessAfter:'),
          reason:
              'the scheduler built at "$id" has no explicit '
              'zombieStalenessAfter, so it silently inherits '
              'timeoutSeconds * 4 + claimLease.',
        );
      }
    });

    test('the cost of decoupling is stated where the number is chosen', () {
      expect(
        serverSource,
        contains('THE COST, STATED PLAINLY'),
        reason:
            'raising a budget necessarily raises this window. If that cost is '
            'not written next to the number, the next reader assumes the '
            'window did not move.',
      );
    });
  });

  group('the tick that runs three schedulers is aware of what a budget means', () {
    test('the blocking-tick coupling is documented where the tick is built', () {
      // `Scheduler.tick()` dispatches in a `for (;;)` loop, awaiting
      // `_dispatchOne` — and so the whole agent execution — SERIALLY for every
      // eligible job, with no per-tick cap. `TickSingleFlight` DROPS every
      // overlapping trigger for the whole of that window, so the window is
      // N × budget, not one budget. That was true at 300s and grows with every
      // budget raised since; it is not introduced here and it is not fixed
      // here, so it has to be written down where the tick is built rather than
      // discovered by an operator wondering why the console went quiet.
      expect(
        serverSource,
        contains('BUDGET-BLOCKED TICK'),
        reason:
            'the composition must say plainly that raising a budget also '
            'lengthens how long the single-flight tick is unavailable.',
      );
      // The first version of that comment bounded the stall at "the longest run
      // it dispatched", which understated it by the backlog size. These two
      // assertions exist because the mis-statement was invisible: the comment
      // was present, it was confident, and it was wrong by a factor of N. The
      // figure is only useful to an operator if it names the multiplier.
      expect(
        RegExp(
          r'N\s*[×x]\s*budget',
          caseSensitive: false,
        ).hasMatch(serverSource),
        isTrue,
        reason:
            'the composition must state the stall as N × budget, where N is the '
            'number of eligible jobs that tick dispatched serially. Bounding it '
            'at one run understates it by the backlog.',
      );
      expect(
        serverSource,
        contains('UNBOUNDED IN THE BACKLOG'),
        reason:
            'N is bounded only by the backlog, so the stall has no ceiling in '
            'the budgets themselves. Saying so is what stops the next reader '
            'from treating the budget as the upper bound on the outage.',
      );
    });
  });

  group('the scheduler default is unchanged, only not used', () {
    test('the ×4 formula is still the Scheduler default, and an explicit '
        'bound still overrides it', () {
      final schedulerSource = _schedulerPackageSource();
      expect(
        schedulerSource,
        contains(
          'Duration(seconds: _workload.timeoutSeconds * 4) + claimLease',
        ),
        reason:
            'if the Scheduler default changes, this lane\'s "we decoupled from '
            'the multiplier" claim has to be re-examined against the new one.',
      );
      // And the escape hatch this lane relies on still exists BY NAME, so a
      // rename cannot leave this composition silently back on the multiplier.
      expect(
        schedulerSource,
        contains('Duration? zombieStalenessAfter'),
        reason:
            '`zombieStalenessAfter` is the parameter every scheduler here is '
            'given. If it is renamed or removed, these call sites stop '
            'compiling — which is the correct outcome.',
      );
    });
  });
}

/// A role header line inside [AgentExecutionBudgets.byRole]: an UPPERCASE name,
/// an em dash, and a line that ends `PROVISIONAL.`.
///
/// Anchored to the whole line deliberately. A looser shape — "somewhere on this
/// line the word PROVISIONAL appears" — is exactly the shape a stray comment
/// satisfies, which is what the test above used and why it had to be replaced.
final RegExp _provisionalHeader = RegExp(
  r'^\s*//\s*([A-Z][A-Z0-9 /&]*\s*[—–-][^\n]*PROVISIONAL\.)\s*$',
  multiLine: true,
);

/// Whether [header] is a marker that actually names [role].
///
/// The key and its header are written in different words — `triage-defect` is
/// introduced by `DEFECT TRIAGE` — so the binding is "this header mentions this
/// role", not "this header repeats this key". A marker naming nothing, or
/// naming a different role, does not describe the budget it sits above.
bool _namesRole(String header, String role) => role
    .split(RegExp(r'[^A-Za-z0-9]+'))
    .where((token) => token.length >= 4)
    .any((token) => header.toUpperCase().contains(token.toUpperCase()));

/// `packages/scheduler/lib/src/scheduler.dart`, located by walking up, exactly
/// as the source-level assertions in this repository already do.
String _schedulerPackageSource() {
  var dir = Directory.current;
  while (dir.parent.path != dir.path) {
    final f = File('${dir.path}/packages/scheduler/lib/src/scheduler.dart');
    if (f.existsSync()) return f.readAsStringSync();
    dir = dir.parent;
  }
  throw StateError(
    'could not locate packages/scheduler/lib/src/scheduler.dart above '
    '${Directory.current.path}',
  );
}
