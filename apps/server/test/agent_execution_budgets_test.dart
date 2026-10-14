import 'dart:io';

import 'package:control_plane_server/server.dart';
import 'package:test/test.dart';

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
    test('engineering review gets 3 hours, from the stated 15-30 minutes', () {
      expect(
        AgentExecutionBudgets.engineeringReviewSeconds,
        3 * 60 * 60,
        reason:
            'operator-stated: a review here, through opencode, takes 15-30 '
            'minutes. 3h is 6x the stated maximum, so variance and a larger '
            'diff do not reach the ceiling.',
      );
    });

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
    test('every entry in the table is introduced by a PROVISIONAL marker', () {
      // Each role's block names the role in caps and carries its own
      // PROVISIONAL marker, so a fourth role added later cannot skip it.
      final table = serverSource.substring(
        serverSource.indexOf('static const Map<String, Duration> byRole'),
        serverSource.indexOf('static int get triageSeconds'),
      );
      for (final role in AgentExecutionBudgets.byRole.keys) {
        expect(
          table.contains("'$role':"),
          isTrue,
          reason: 'the table must actually declare $role',
        );
      }
      final roleBlocks = RegExp(
        r'// ([A-Z][A-Z ]+—.*?PROVISIONAL\.)',
        multiLine: true,
      ).allMatches(table).map((m) => m.group(1)!).toList();
      expect(
        roleBlocks.length,
        AgentExecutionBudgets.byRole.length,
        reason:
            'each role\'s comment must lead with its name and end the header '
            'line with PROVISIONAL. The worst outcome of this change is the '
            'next person reading a budget and assuming somebody measured it — '
            'which is exactly how 300 got there. Found: $roleBlocks',
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
      // `_dispatchOne` awaits the whole agent execution, so one tick blocks for
      // the length of the longest run it dispatched and `TickSingleFlight`
      // DROPS every overlapping trigger. That was true at 300s and is worse at
      // 3h; it is not introduced here and it is not fixed here, so it has to
      // be written down where the tick is built rather than discovered by an
      // operator wondering why the console went quiet.
      expect(
        serverSource,
        contains('BUDGET-BLOCKED TICK'),
        reason:
            'the composition must say plainly that raising a budget also '
            'lengthens how long the single-flight tick is unavailable.',
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
