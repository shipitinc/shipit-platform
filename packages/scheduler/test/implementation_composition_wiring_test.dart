import 'dart:io';

import 'package:scheduler/scheduler.dart';
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
/// Whitespace the banner extractor tolerates between adjacent string
/// literals. Anything else ends the value.
bool _isSpace(String c) => c == ' ' || c == '\n' || c == '\t' || c == '\r';

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

  /// The VALUE of the composition banner's `producers` entry, reassembled from
  /// the adjacent string literals Dart concatenates it from.
  ///
  /// Reassembling the value rather than grepping for one literal substring is
  /// the point: the banner exists to tell an operator the difference between a
  /// lane that is idle because nothing routes into it and one that is idle
  /// because it is broken, so the assertion has to be about what the banner
  /// SAYS, not about how it happens to be wrapped across lines. A substring
  /// grep would let the claim drift one line at a time.
  String producersBanner() {
    const key = "'producers':";
    final keys = RegExp(key).allMatches(source).toList();
    expect(
      keys.length,
      1,
      reason:
          'the composition root must declare exactly one `producers` entry — '
          'two would make the banner ambiguous and this extraction arbitrary',
    );

    var i = keys.single.start + key.length;
    final buffer = StringBuffer();
    // Adjacent literals concatenate, so the value is every literal that
    // follows with nothing but whitespace between them; the first character
    // that is neither ends it.
    for (;;) {
      while (i < source.length && _isSpace(source[i])) {
        i++;
      }
      if (i >= source.length || source[i] != "'") break;
      i++; // opening quote
      while (i < source.length) {
        if (source[i] == r'\' && i + 1 < source.length) {
          buffer.write(source.substring(i, i + 2));
          i += 2;
          continue;
        }
        if (source[i] == "'") {
          i++;
          break;
        }
        buffer.write(source[i]);
        i++;
      }
    }

    final value = buffer.toString();
    expect(
      value,
      isNotEmpty,
      reason: "the banner's producers entry must actually say something",
    );
    return value;
  }

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
            '{designNotRequired, designApproved} and would collide with triage '
            'on designNotRequired',
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

    // THE PROPERTY, NOT A VALUE — the same correction the banner assertion
    // below makes, and for the same reason.
    //
    // This used to pin the literal `timeoutSeconds: 1800`, which asserted the
    // VALUE rather than what the value was standing in for.
    // `AgentExecutionBudgets` now owns that number (`implement-feature` is 4
    // hours, from the operator-stated "routinely exceeds 30m"), so the literal
    // is gone from the composition — correctly. A guard that must be edited
    // every time a budget is re-derived is a guard that gets deleted at the
    // first re-derivation, and it reds for the least interesting possible
    // reason: the number moved, not the wiring.
    //
    // What it was actually preventing still holds, and is what is asserted
    // instead: a budget must never be a SECOND TYPED-IN NUMBER, and the reclaim
    // window must not silently inherit the Scheduler's default formula. Both
    // failure modes are invisible in a running process — the lane reports
    // itself healthy either way — which is why they can only be caught here.
    test('the implementation budget is NAMED, and so is its reclaim window', () {
      final body = implSchedulerBody();

      expect(
        RegExp(
          r'timeoutSeconds:\s*AgentExecutionBudgets\.implementationSeconds',
        ).hasMatch(body),
        isTrue,
        reason:
            'the scheduler must read its budget off the table that documents '
            'where the number came from. Two copies of a budget cannot both be '
            're-derived when the operator-stated range behind it is revised, '
            'and the copy with no comment is the one that survives',
      );
      expect(
        RegExp(r'timeoutSeconds:\s*\d').hasMatch(body),
        isFalse,
        reason:
            'a bare integer is precisely the defect this replaced. It sits in '
            'the INERT static workload, so it changes no run by itself — but it '
            'is the number a reader copies to learn what an implementation run '
            'is allowed to take, and a stale answer there is worse than none',
      );
      expect(
        RegExp(
          r'zombieStalenessAfter:\s*AgentExecutionBudgets\.zombieStalenessFor\(',
        ).hasMatch(body),
        isTrue,
        reason:
            'omitting this leaves `Scheduler.zombieStalenessBound` at its '
            'default of `timeoutSeconds * 4 + claimLease`. That formula was '
            'written for five-minute budgets; at a 4-hour implementation budget '
            'it becomes a 16.7-hour window in which a dead execution keeps its '
            'claim and its capacity slot. That is the same failure the old 300 '
            'produced — an execution outliving its lease for hours — one order '
            'of magnitude larger',
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

    test('the banner states what routes into the lane, and drops the stale '
        'OD-3 claim', () {
      // THE PROPERTY, NOT A VALUE.
      //
      // This assertion used to pin the banner's literal text — that it says
      // `'producers': 'none yet'` — because until `OD-3` and `OD-10` were
      // resolved that was true, and a lane that is wired and inert must not be
      // able to read as a lane that is wired and idle-because-broken.
      //
      // It is no longer true. Four resolved human decisions and one automatic
      // route now put items into `implementation_ready`, so pinning the old
      // literal would have been a test asserting a falsehood — green, and
      // actively misleading. For one correction cycle this file instead asserted
      // only the INVERSE (the banner must not say `none yet`), which is safe but
      // blind: it cannot tell a correct banner from a vague one, and a vague
      // banner destroys the exact distinction the field exists to preserve.
      //
      // So the banner is now pinned to what the lane ACTUALLY DECLARES. The
      // inflow half is read from `implementFeatureDefinition.completionInflowFrom`
      // rather than transcribed, so it drifts in both directions: drop the inflow
      // from the banner and this reds, and drop it from the definition and this
      // reds with it, which is the only way the two can stay honest about each
      // other. The four decision pairs live in `workflow_engine`, whose routing
      // table this source-grep file deliberately does not own — they are pinned
      // executably there, in `implement_feature_deferral_test.dart` ('exactly
      // the four rework gates route here, and nothing else does'). Between the
      // two files, producer availability is asserted from both sides without
      // either owning the other's table.
      final banner = producersBanner();

      final inflow = implementFeatureDefinition.completionInflowFrom;
      expect(
        inflow,
        isNotNull,
        reason:
            'this definition declares the `OD-10` completion inflow; without it '
            'there is no automatic producer and the banner would be describing '
            'a lane that cannot receive one',
      );
      expect(
        inflow,
        isNotEmpty,
        reason: 'an empty `completionInflowFrom` declares no inflow at all',
      );

      for (final from in inflow!) {
        expect(
          banner,
          contains(from.wire),
          reason:
              'the banner does not name `$from`, the state from which the '
              'completion inflow of this lane routes. An operator reading it '
              'cannot tell that items arrive here on completion, which is the '
              'whole distinction the field exists to draw. Declared: '
              '${inflow.map((s) => s.wire).toList()}',
        );
      }

      expect(
        banner,
        isNot(contains('(OD-3 is open)')),
        reason:
            '`OD-3` is RESOLVED and `OD-10` delivered the inflow. A banner '
            'that still says the decision is open tells an operator this lane '
            'is deliberately unreachable, which is now false in the exact way '
            'that matters: items DO route here and the lane WILL dispatch. '
            'banner was: $banner',
      );

      expect(
        banner,
        isNot(contains('none yet')),
        reason:
            'the banner still claims the lane has no producers, for the same '
            'reason as above. banner was: $banner',
      );
    });

    test('the COMMENT above the banner does not assert the lane is inert', () {
      // The banner's VALUE is extracted above, so it was guarded — and the
      // comment thirteen lines above it was not. It still said that no
      // `HumanDecisionRouting` entry targets `implementation_ready` "because
      // which rework pairs move there is an open decision (OD-3)", directly
      // above the corrected string that names all four resolved ones. A false
      // persisted claim about shipping code is worse than a missing one: a
      // reader who finds it has to decide which of two adjacent statements to
      // believe.
      //
      // Nothing can guard prose in general. What can be guarded is prose that
      // makes a CLAIM ABOUT THE CURRENT STATE, and this is the prose that does.
      final anchor = source.indexOf("'implementation': {");
      expect(anchor, greaterThan(-1), reason: 'the banner entry must exist');

      // The comment block immediately above it: everything from the end of the
      // previous statement to the anchor.
      final previousStatement = source.lastIndexOf('},', anchor);
      expect(previousStatement, greaterThan(-1));
      final comment = source.substring(previousStatement, anchor);

      expect(
        comment,
        isNot(contains('(OD-3 is open)')),
        reason:
            '`OD-3` is resolved and `OD-10` delivered the inflow. This comment '
            'is not about the decision being open — it is about what the banner '
            'must let an operator distinguish. comment was: $comment',
      );
      for (final stale in const [
        'no `HumanDecisionRouting`\n    // entry targets',
        'nothing reaches it yet',
        'is an open decision',
      ]) {
        expect(
          comment,
          isNot(contains(stale)),
          reason:
              'the lane is wired and REACHABLE. A comment claiming otherwise '
              'sits directly above the string that says so. comment was: '
              '$comment',
        );
      }
      expect(
        comment,
        contains('REACHABLE'),
        reason:
            'the distinction this banner has to preserve is "nothing routed '
            'into it" against "idle because it is broken". Naming it here — '
            'not only in the value below — is what keeps the next reader from '
            're-adding the claim that was just removed.',
      );
    });

    test('the implementation section ticks BEFORE the review section', () {
      // `sched-impl` ROUTES items out of `agentCompleted`; `sched-review`
      // DISPATCHES from it and its fail-closed handler MOVES them. Ticking
      // review first let the handler park a no-artifact item before the inflow
      // ever saw it, and the item never reached `implementationReady` — with
      // both ticks reporting success. See
      // `apps/server/test/implementation_inflow_tick_order_test.dart`, which
      // proves the outcome is now the same in either order; this pins the
      // order the composition actually uses.
      final impl = source.indexOf('await implScheduler.tick();');
      final review = source.indexOf('await reviewScheduler.tick();');
      expect(impl, greaterThan(-1), reason: 'the lane must be ticked');
      expect(review, greaterThan(-1), reason: 'review must be ticked');
      expect(
        impl,
        lessThan(review),
        reason:
            'disjointness has to be structural, not accidental. Handled by '
            'engineeringReviewMissingArtifact standing down as well, so this '
            'ordering is the braces rather than the only defence — but a '
            'reorder that silently flips it restores the window.',
      );
    });
  });
}
