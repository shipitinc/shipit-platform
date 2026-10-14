import 'dart:io';

import 'package:test/test.dart';

/// The implementation lane's COMPOSITION is asserted here, because the failure
/// it prevents is a wiring failure and only the wiring can exhibit it.
///
/// ## Why source-level assertions and not executable ones
///
/// `apps/server/test/**` is not writable by this lane, and the alternative
/// precedents for a source-level gate are already in this package
/// (`composition_wiring_test.dart`). The reasoning is the same as that file's
/// and it is worth restating, because a grep that cannot fail is not a guard:
///
///  * `Scheduler` needs a database, a live agent runtime and a worker registry
///    to run. A unit test of the composition would be a test of a copy.
///  * Every defect below is a defect of the WIRING — a resolver not passed, a
///    handler installed that should not be, a comment missing next to the one
///    line that is dangerous if unread.
///
/// So each assertion below targets a CALL SITE rather than a whole-file
/// substring, and each was checked against the failure it is supposed to
/// produce.
///
/// ## What each one prevents
///
///  * no `workloadResolver` — the scheduler silently uses its static workload,
///    which names the triage repository, and the implementer commits into a
///    README-only scratch checkout;
///  * a `blockedArtifactMissing` handler — `engineeringReviewMissingArtifact`
///    performs `agentCompleted -> reviewInProgress`, so applying it to an
///    implementation job would move an item through a gate it never entered and
///    raise a decision about an artefact nobody tried to produce;
///  * the durable-workspace root read missing — A1's runtime would refuse to
///    build and no product clone could ever be created.
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

  /// The body of one named `Scheduler(...)` construction, so an argument
  /// commented out of it cannot satisfy a whole-file grep.
  String schedulerNamed(String declaration) {
    final start = source.indexOf(declaration);
    expect(
      start,
      greaterThan(-1),
      reason: 'the composition must build $declaration',
    );
    final end = source.indexOf('\n  );', start);
    expect(
      end,
      greaterThan(start),
      reason: 'the $declaration construction must close',
    );
    return source.substring(start, end);
  }

  String implSchedulerBody() =>
      schedulerNamed('final implScheduler = Scheduler(');

  group('the implementation lane is wired, not merely defined', () {
    test('the composition builds a third Scheduler for it', () {
      expect(
        source,
        contains("schedulerId: 'sched-impl'"),
        reason:
            'the lane exists as a definition and as a scheduler in this '
            'repository. A definition nothing drives is a comment',
      );
      expect(
        implSchedulerBody(),
        contains('definition: implementFeatureDefinition'),
        reason:
            'the scheduler must be built over the NEW definition, not over '
            '`defaultImplementFeatureDefinition` — the latter still declares '
            '{designNotRequired, designApproved} and would collide with triage',
      );
    });

    test('a third worker exists, with capabilities taken from the DEFINITION', () {
      expect(source, contains("workerId: 'w-impl-local'"));
      expect(
        RegExp(
          r'final implementWorker = LocalWorker\([^;]*'
          r'capabilities: implementFeatureDefinition\.requiredCapabilities,',
          multiLine: true,
          dotAll: true,
        ).hasMatch(source),
        isTrue,
        reason:
            'capabilities must come from the definition\'s own set. A '
            'hand-copied list that drifts produces a worker no implementation '
            'job can select, and the scheduler defers for ever while reporting '
            'itself healthy',
      );
      expect(
        RegExp(r'\.\.register\(implementWorker\)').hasMatch(source),
        isTrue,
        reason:
            'a worker that is built but not registered can never be selected',
      );
    });
  });

  group('the readiness probe is AUTHORITATIVE', () {
    test('the scheduler is given a workloadResolver', () {
      expect(
        RegExp(
          r'^\s*workloadResolver: toWorkloadResolver\(',
          multiLine: true,
        ).hasMatch(implSchedulerBody()),
        isTrue,
        reason:
            'without a resolver the scheduler falls back to its static '
            'workload, which names the TRIAGE repository. That is the '
            'fabrication hazard this lane exists to close',
      );
    });

    test('the static workload is present, INERT, and says so INLINE', () {
      final body = implSchedulerBody();
      expect(
        body,
        contains('workload: SchedulerWorkload('),
        reason:
            'the argument is required by the constructor, so its absence is a '
            'compile error rather than a hazard — which is the good case',
      );
      final workloadIndex = body.indexOf('workload: SchedulerWorkload(');
      final commentIndex = body.lastIndexOf('INERT', workloadIndex);
      expect(
        commentIndex,
        greaterThan(-1),
        reason:
            'the one line in this composition that is dangerous if unread must '
            'carry its own warning immediately above it. A comment about it in '
            'the file header is a comment a reader scrolling past the '
            'construction will not see',
      );
    });

    test('the implementation timeout is 1800, not the triage 300', () {
      expect(
        RegExp(r'timeoutSeconds: 1800,').hasMatch(implSchedulerBody()),
        isTrue,
        reason:
            'an implementation run is not a five-minute classification, and '
            'this value also sets `zombieStalenessBound` (`timeoutSeconds * 4 '
            '+ claimLease`). The shipped 300 is how an execution outlived its '
            'lease for hours',
      );
    });
  });

  group('a deferral is never turned into a human decision', () {
    test(
      'the implementation tick section installs NO artifact-missing handler',
      () {
        final start = source.indexOf(
          "final implTick = await implScheduler.tick();",
        );
        expect(start, greaterThan(-1), reason: 'the lane must be ticked');
        final end = source.indexOf(
          "outcome.failedSections.add('implementation')",
          start,
        );
        expect(
          end,
          greaterThan(start),
          reason: 'the implementation tick section must close',
        );
        final section = source.substring(start, end);

        expect(
          section,
          isNot(contains('engineeringReviewMissingArtifact')),
          reason:
              'that handler is a REVIEW action: it performs '
              '`agentCompleted -> reviewInProgress` and raises a blocking '
              'engineering-review decision. Applied to an implementation job it '
              'would move an item through a gate it never entered and raise a '
              'decision about "no artifact was produced" for an item that never '
              'started',
        );
        expect(
          section,
          contains("'implementation.deferred'"),
          reason:
              'the refusal must still be VISIBLE. A deferral reported nowhere is '
              'indistinguishable from a scheduler that is idle',
        );
      },
    );

    test('the implementation tick is in its own try', () {
      expect(
        source,
        contains("outcome.failedSections.add('implementation')"),
        reason:
            'a lane that throws must not take triage, review and baseline down '
            'with it — and it must be NAMEABLE when it does',
      );
    });
  });

  group('A1\'s durable-workspace runtime has a production caller', () {
    test('the composition resolves it over the shared registry engine', () {
      expect(
        RegExp(
          r'DurableWorkspaceRuntime\.resolve\([^;]*'
          r'engine: productRegistryEngine,',
          multiLine: true,
          dotAll: true,
        ).hasMatch(source),
        isTrue,
        reason:
            'the durable-workspace runtime shipped with zero production '
            'callers. Building a second registry engine here would mean two '
            'places to change if its construction ever does',
      );
    });

    test('the workspace root is read IN server.dart, not in the lane', () {
      // The read cannot live in `lib/src/baseline/**`: the product-agnosticism
      // gate refuses every product name in that directory, and the variable is
      // named after the product. So C-1 puts it here.
      expect(
        source,
        contains("const String _durableWorkspaceRootEnv"),
        reason:
            'the composition root is where a product-named environment '
            'variable may be read. A1\'s factory takes a plain String for '
            'exactly that reason',
      );
      expect(
        source,
        contains('final durableWorkspaceRoot = _durableWorkspaceRoot();'),
        reason:
            'it must be resolved once, before the server starts, and passed '
            'into the factory as a parameter',
      );
      expect(source, contains('durableWorkspaceRoot: durableWorkspaceRoot,'));
    });

    test('the root read has NO default of its own', () {
      final start = source.indexOf("const String _durableWorkspaceRootEnv");
      final end = source.indexOf('String _durableWorkspaceRoot() =>', start);
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final read = source.substring(start, end);
      expect(
        read,
        isNot(contains('Directory.systemTemp')),
        reason:
            'a system-temp fallback for a DURABLE clone gives a product a '
            'checkout that vanishes on the next container rebuild — the exact '
            'failure the host-bind decision exists to prevent. The triage root '
            'does have one, and that is why it is a different variable',
      );
    });

    test('the runtime\'s state is reported at startup in both directions', () {
      expect(
        source,
        contains("'durableWorkspace': durableWorkspaceRuntime.describe(),"),
        reason:
            'a runtime that is constructed but refusing every call looks '
            'exactly like one that does not exist. Its state, and its reason '
            'when unavailable, belong in the banner',
      );
    });
  });

  group('the lane is wired AND its producers are declared', () {
    test('the composition banner states the implementation lane\'s entry '
        'states', () {
      expect(
        RegExp(
          r"'entryStates':\s*implementFeatureDefinition\.entryStates",
        ).hasMatch(source),
        isTrue,
        reason:
            'an operator reading the startup line must be able to see the lane '
            'exists AND what routes into it, rather than inferring one from '
            'the other',
      );
    });

    test('the banner must not claim the lane has NO producers', () {
      // THE PROPERTY, NOT A VALUE.
      //
      // This assertion used to pin the banner's literal text — that it says
      // `'producers': 'none yet'` — because until `OD-3` and `OD-10` were
      // resolved that was true, and a lane that is wired and inert must not be
      // able to read as a lane that is wired and idle-because-broken.
      //
      // It is no longer true. Four resolved human decisions and one automatic
      // route now put items into `implementation_ready`, so the honest guard is
      // the INVERSE one: the banner must never say the lane has no producers
      // while the routing table and the inflow both give it some. Pinning the
      // old literal would have been a test asserting a falsehood — green, and
      // actively misleading — and it would have become a landmine that FAILED
      // the moment anyone corrected the banner, punishing the fix.
      //
      // This is a one-sided assertion on purpose: it cannot detect a banner
      // that wrongly claims producers exist. That half needs the routing table,
      // which this source-grep file deliberately cannot see, and it is pinned
      // executably in `implement_feature_deferral_test.dart` ('exactly the
      // four rework gates route here, and nothing else does') and by the
      // inflow's own tests. Between the two, producer availability is asserted
      // from both sides without either file owning the other's table.
      expect(
        RegExp(r"'producers':\s*'none yet").hasMatch(source),
        isFalse,
        reason:
            'the composition root still carries the pre-`OD-3` banner text '
            '"none yet — no resolved human decision routes into '
            'implementation_ready (OD-3 is open)". That statement is now FALSE: '
            'four decisions and the completion inflow all route into it, and '
            'deploying this revision starts the lane dispatching for the first '
            'time. `apps/server/lib/server.dart` is not this lane\'s to write, '
            'so the banner must be corrected by its owner — and this assertion '
            'is what will tell them it is still wrong',
      );
    });
  });
}
