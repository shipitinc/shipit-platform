import 'dart:io';

import 'package:test/test.dart';

/// This defect was not a bug in the reconciler: the liveness probe typedef, the
/// `ExecutionLiveness` verdicts and `seedConfiguredDefault` all existed, all
/// had tests, and none of them was ever SUPPLIED. The platform ran on the
/// staleness bound alone and on a model table with zero rows.
///
/// `apps/server/test/**` is not writable by this lane, so the composition
/// root's wiring is guarded here. These are source-level assertions BY
/// NECESSITY: the failure they prevent is a wiring one and only the wiring can
/// exhibit it. The decision RULES themselves are covered by executable tests —
/// `liveSessionLivenessProbe` in `scheduler_zombie_reclaim_test.dart` and
/// `qualifyModelId` in `agent_runtime`.
///
/// They assert CALL SITES, not whole-file substrings, and each one was
/// mutation-checked: commenting out the wiring, deleting the seeding call, or
/// returning `dead` from a failed observation each makes exactly these fail.
/// A source grep that cannot fail is not a guard.
void main() {
  late String source;

  setUpAll(() {
    final marker = Directory.current;
    var dir = marker;
    while (dir.parent.path != dir.path) {
      final candidate = File('${dir.path}/apps/server/lib/server.dart');
      if (candidate.existsSync()) {
        source = candidate.readAsStringSync();
        return;
      }
      dir = dir.parent;
    }
    fail('could not locate apps/server/lib/server.dart above ${marker.path}');
  });

  /// The body of the production `Scheduler(...)` construction, so an argument
  /// commented out of it cannot satisfy a whole-file grep.
  String schedulerConstruction() {
    final start = source.indexOf('final scheduler = Scheduler(');
    expect(
      start,
      greaterThan(-1),
      reason: 'the composition must build a Scheduler',
    );
    final end = source.indexOf('\n  );', start);
    expect(
      end,
      greaterThan(start),
      reason: 'the Scheduler construction must close',
    );
    return source.substring(start, end);
  }

  group('the liveness probe is SUPPLIED, not merely declared', () {
    test('the composition root binds the real live-session oracle', () {
      expect(
        source,
        contains('liveSessionLivenessProbe('),
        reason:
            'the probe must be built by the scheduler package so its '
            'fail-direction rule is executable and tested',
      );
      expect(
        source,
        contains('coordinator.hasLiveSession(agentExecutionId)'),
        reason:
            'the oracle must be this process\'s live agent sessions; '
            'anything else re-creates the "read a status string" defect',
      );
    });

    test('the scheduler construction passes the probe through', () {
      final body = schedulerConstruction();
      expect(
        RegExp(
          r'^\s*executionLiveness: executionLiveness,',
          multiLine: true,
        ).hasMatch(body),
        isTrue,
        reason:
            'a declared-but-unused probe is exactly the defect being '
            'fixed: reconciliation falls back to the staleness bound alone',
      );
    });
  });

  group('the model policy is POPULATED at startup, not guessed at runtime', () {
    test('the scheduler construction passes the selector through', () {
      final body = schedulerConstruction();
      expect(
        RegExp(
          r'^\s*modelSelection: modelSelection,',
          multiLine: true,
        ).hasMatch(body),
        isTrue,
        reason:
            'without a selector the request carries NO model and the '
            'adapter applies its own default - the unpinned, unrecorded state',
      );
    });

    test('seeding is actually CALLED, not merely declared', () {
      // The declaration of the helper and the call to the helper are different
      // strings; this pins the call.
      expect(
        RegExp(r'await _seedModelPolicy\(modelSelection\)').hasMatch(source),
        isTrue,
        reason:
            'without this call model_policy stays empty and every role '
            'silently inherits the in-code default',
      );
      // And the helper must do the seeding, not merely log about it.
      final helperStart = source.indexOf(
        'Future<Map<String, dynamic>> _seedModelPolicy(',
      );
      expect(helperStart, greaterThan(-1));
      final helperBody = source.substring(
        helperStart,
        source.indexOf('\n}', helperStart),
      );
      expect(
        RegExp(
          r'await selection\.seedConfiguredDefault\(\)',
        ).hasMatch(helperBody),
        isTrue,
        reason: 'the seeding call itself must live inside the helper',
      );
    });

    test('seeding failure is logged and surfaced, not swallowed', () {
      expect(RegExp(r"await _seedModelPolicy\(").hasMatch(source), isTrue);
      expect(source, contains('server.modelpolicy.seed.failed'));
      expect(
        RegExp(r"'seedFailed':\s*true").hasMatch(source),
        isTrue,
        reason:
            'the composition line must be able to say seeding FAILED, so an '
            'operator can tell a durable policy from a constant in a binary',
      );
    });

    test(
      'the composition line shows which model is in force and its source',
      () {
        expect(source, contains("'modelPolicy': {"));
        expect(source, contains("'inForceModelId':"));
        expect(source, contains("'inForceSource':"));
        expect(
          RegExp(
            r"'inForceModelId': triageModelPolicy\.modelId",
          ).hasMatch(source),
          isTrue,
          reason:
              'the reported id is read back off the live selection, so the '
              'log line and the request that is built cannot disagree',
        );
      },
    );
  });
}
