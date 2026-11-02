import 'dart:io';

import 'package:test/test.dart';

/// ## WHAT THIS FILE EXISTS TO PROVE
///
/// `Scheduler.agentExecutionRetirement` is OPTIONAL, and that optionality is
/// exactly the defect this file guards. `74a7d2e` added the seam so
/// `_reclaimZombie` can close the `agent_execution` row a dead drive left open
/// (F-235): without it the reclaim still drives the job to terminal and
/// retires the `worker_execution` row, but the `agent_execution` row stays
/// 'running' for ever — a stale live-execution claim that also blocks
/// re-execution of its id.
///
/// An unwired scheduler is INVISIBLE to every other gate. The parameter
/// defaults to null, so omitting it compiles, `dart analyze` is clean, and
/// every behavioural test passes: the scheduler package's own tests inject
/// their own seam or assert the null case deliberately. `run()` is the one
/// place the production wiring is decided, and it needs a live database, a
/// live `opencode` binary and a worker registry, so it cannot be entered from
/// a unit test at all.
///
/// So this file does what the last group of
/// `execution_store_wiring_test.dart` does for the coordinator's store: it
/// reads `lib/server.dart` as text and pins the BINDING — that each of the
/// five `Scheduler(` calls inside `run()` is handed `agentExecutionRetirement:`
/// built by `storeBackedAgentExecutionRetirement` over the coordinator
/// `ExecutionStore` whose lane it reclaims. The implementation stays free to
/// change; what may not change is that no mounted scheduler is left with the
/// seam null, because null is precisely the wiring gap that left stale
/// 'running' rows in `agent_execution` while every test in the repository
/// passed.
void main() {
  group('the five production schedulers all carry the F-235 retirement seam', () {
    late List<_SchedulerCall> calls;

    setUpAll(() {
      final source = File('lib/server.dart').readAsStringSync();
      calls = _schedulerCallsInRun(source);
    });

    test('run() mounts exactly the five schedulers this file pins', () {
      expect(
        calls.map((call) => call.schedulerId),
        unorderedEquals(const <String>[
          'sched-triage',
          'sched-review',
          'sched-design-revision',
          'sched-design-review',
          'sched-impl',
        ]),
        reason:
            'the assertions below are per-call, so a scheduler mounted without '
            'one — or one of these dropped — must fail loudly here rather than '
            'silently shrink the set this file claims to guard. A sixth '
            'scheduler is not forbidden; it is forbidden to mount one without '
            'the seam and without this file noticing.',
      );
    });

    test('no mounted scheduler is left with the seam at its null default', () {
      for (final call in calls) {
        expect(
          call.text,
          contains('agentExecutionRetirement:'),
          reason:
              '${call.schedulerId}: the parameter is optional, so its absence '
              'is silent — the scheduler compiles, analyzes and ticks while '
              'every zombie reclaim leaves the agent_execution row open, which '
              'is exactly the F-235 defect reaching production through wiring '
              'rather than through code',
        );
        expect(
          call.text,
          contains('executionLiveness:'),
          reason:
              '${call.schedulerId}: retirement answers "close the row" while '
              'liveness answers "is it dead"; a scheduler that lost the probe '
              'in the same edit would reclaim on the staleness bound alone, '
              'which is the pre-liveness behaviour this file also pins',
        );
      }
    });

    test(
      'each seam is built by the named factory over the coordinator whose '
      'lane it reclaims',
      () {
        // The binding, stated once: every lane retires through
        // `coordinator.store`. The implementation lane is driven by
        // `implementationCoordinator` (OD-6), but the retirement settles a row
        // in the shared `agent_execution` table and both coordinators' stores
        // are `agentExecutionStore(db)` over that one table — so the pin is
        // that the argument is the coordinator's `.store`, never a
        // hand-rolled closure, an in-memory store, or a second spelling of
        // the table.
        const expectedStore = <String, String>{
          'sched-triage': 'coordinator',
          'sched-review': 'coordinator',
          'sched-design-revision': 'coordinator',
          'sched-design-review': 'coordinator',
          'sched-impl': 'coordinator',
        };

        for (final call in calls) {
          final wiring = RegExp(
            'agentExecutionRetirement:\\s*'
            'storeBackedAgentExecutionRetirement\\(\\s*(\\w+)\\.store',
          ).firstMatch(call.text);

          expect(
            wiring,
            isNotNull,
            reason:
                '${call.schedulerId}: the seam must be built by '
                '`storeBackedAgentExecutionRetirement` over a coordinator\'s '
                'ExecutionStore. Any other expression — a hand-rolled closure, '
                'an in-memory store, a TODO — compiles here and retires '
                'nothing durable, which is the binding this assertion exists '
                'to pin rather than the type',
          );
          expect(
            wiring!.group(1),
            expectedStore[call.schedulerId],
            reason:
                '${call.schedulerId}: the zombie reclaim closes a row in the '
                'shared `agent_execution` table, and '
                '${expectedStore[call.schedulerId]}.store is the '
                'ExecutionStore over that table — the seam must be backed by '
                'that store, not by one that points somewhere else',
          );
        }
      },
    );
  });
}

/// One `Scheduler(` call inside `run()`: its `schedulerId` and the full text
/// between its parentheses, so assertions bind to THE call and not to the file.
class _SchedulerCall {
  _SchedulerCall({required this.schedulerId, required this.text});

  final String schedulerId;
  final String text;
}

/// Returns every `= Scheduler(` CALL inside `run()`'s body, parentheses
/// matched, in source order.
///
/// Scoped the same way `_coordinatorCallInRun` in
/// `execution_store_wiring_test.dart` is: the search runs inside `run()`'s
/// body only — a `Scheduler(` elsewhere is a different composition — and the
/// `= ` prefix means a comment, a declaration or `SchedulerWorkload(` can
/// never satisfy the match. The `hasLength` expectation below is what keeps
/// the guard honest: a site that stops matching shrinks the list the callers
/// assert on, and fails there rather than passing over a missing call.
List<_SchedulerCall> _schedulerCallsInRun(String source) {
  final runStart = RegExp('^void run\\(', multiLine: true).firstMatch(source);
  expect(
    runStart,
    isNotNull,
    reason: 'the composition root must still be `run`',
  );
  final runEnd = RegExp('^\\}', multiLine: true).firstMatch(
    source.substring(runStart!.end),
  );
  expect(runEnd, isNotNull, reason: '`run()` must be a top-level function');
  final body = source.substring(runStart.end, runStart.end + runEnd!.start);

  final calls = <_SchedulerCall>[];
  for (final match in RegExp('= Scheduler\\(').allMatches(body)) {
    final open = body.indexOf('(', match.start);
    var depth = 0;
    var close = -1;
    for (var i = open; i < body.length; i++) {
      if (body[i] == '(') {
        depth++;
      } else if (body[i] == ')') {
        depth--;
        if (depth == 0) {
          close = i;
          break;
        }
      }
    }
    expect(
      close,
      greaterThan(-1),
      reason: 'each Scheduler call must be delimited by balanced parentheses',
    );
    final text = body.substring(open, close + 1);

    final id = RegExp("schedulerId:\\s*'([^']+)'").firstMatch(text);
    expect(
      id,
      isNotNull,
      reason:
          'every mounted Scheduler names its schedulerId — without it the '
          'per-site assertions below cannot say WHICH lane a failure is about',
    );
    calls.add(_SchedulerCall(schedulerId: id!.group(1)!, text: text));
  }

  expect(
    calls,
    hasLength(5),
    reason:
        'the composition mounts five schedulers. More or fewer means the '
        'call-site enumeration itself drifted, and every per-site assertion '
        'above would be measuring a different composition than the one this '
        'file claims to guard',
  );
  return calls;
}
