import 'dart:io';

import 'package:control_plane_server/src/endpoints/work_item_action_endpoints.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart'
    show RetryPolicy, triageDefectDefinition;
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart' show WorkItemTransitions;
import 'package:workflow_store/workflow_store.dart'
    show OperatorActionKind, OperatorActionRecord;

/// §6.6 — the operator-retry resolution, and the server-computed action set.
///
/// ## REVERSED 2026-10-12 — READ THIS BEFORE CHANGING ANY EXPECTATION HERE
///
/// This file previously asserted that an unset/unparseable retry limit **fails
/// closed**: `retryIsAvailable` false, `limit` null, `isResolved` false, and
/// the panel offering only `stop`. Every one of those expectations was a
/// deliberate, reviewed decision (HD-3, `5d9a1f62`) and every one of them is
/// now INVERTED by a human decision.
///
/// The new rule, in one sentence: **an unset, blank, unparseable or negative
/// `SHIPIT_OPERATOR_MAX_RETRIES` means NO COUNT BOUND** — an operator may
/// restart a work item any number of times — and it no longer means "the retry
/// action is not available".
///
/// What did NOT change, and what the tests below still hold to:
///
///  * an explicit `0` still switches operator retry off entirely, and still
///    resolves as a CONFIGURATION rather than a failure (AC-15c);
///  * an explicit positive `N` still caps the retries at N;
///  * **no input may ever resolve to a number the operator did not write** —
///    there is still no fallback constant, and `0x3`/`+3`/`9999…` must not
///    become a cap;
///  * no input may THROW out of the resolver (HIGH-1);
///  * the action set is still COMPUTED from the transition table (AC-1/N4).
///
/// The group names below are deliberately kept close to the originals so a
/// reviewer diffing this file can see exactly which expectation moved and why.
void main() {
  const envVar = operatorRetryLimitEnvVar;

  group('REVERSED 2026-10-12 — an unset retry limit means NO COUNT BOUND', () {
    test('unset resolves to UNBOUNDED — retry available, and no number', () {
      final resolution = OperatorRetryLimitResolution.fromEnvironment(
        const {},
      );

      // The reversal, stated as the three predicates the RPC consults.
      expect(resolution.retryIsAvailable, isTrue);
      expect(resolution.unbounded, isTrue);
      // …and still no invented number. "Uncounted" is not "3".
      expect(resolution.limit, isNull);
      expect(resolution.wireAttemptLimit, 0);
      // No count means no question of whether it has been spent.
      expect(resolution.isCountBounded, isFalse);
      // Resolved: the variable's MEANING is known exactly. Reporting the
      // default state as unresolved is what would make a healthy machine look
      // broken on screen.
      expect(resolution.isResolved, isTrue);
      expect(resolution.permanentlyDisabled, isFalse);
    });

    test('the diagnostic names the variable and is never blank', () {
      final resolution = OperatorRetryLimitResolution.fromEnvironment(
        const {},
      );

      expect(resolution.diagnostic, contains(envVar));
      expect(resolution.diagnostic.trim(), isNotEmpty);
    });

    test('the unset diagnostic does NOT tell an operator to configure it', () {
      // The reversal deletes the old default's central claim: that the action
      // must be ARMED before an operator can use it. Copy that says "set this
      // to 3 to arm restarting" about the DEFAULT state is precisely the lie
      // this change exists to remove, and it is the one thing a future editor
      // could reintroduce by copying the old string forward.
      final diagnostic = resolution(const {}).diagnostic.toLowerCase();

      expect(diagnostic, contains('unbounded'));
      expect(diagnostic, isNot(contains('not available')));
      expect(diagnostic, isNot(contains('refusing')));
      expect(diagnostic, isNot(contains('before an operator can')));
      // And it must say what the operator CAN still do, or be armed, rather
      // than only what is wrong.
      expect(diagnostic, contains('any number of times'));
    });

    test('blank resolves to UNBOUNDED', () {
      for (final blank in ['', '   ', '\t', '\n']) {
        final resolution = OperatorRetryLimitResolution.fromEnvironment({
          envVar: blank,
        });
        expect(
          resolution.retryIsAvailable,
          isTrue,
          reason: 'blank ${jsonish(blank)} still means no count bound',
        );
        expect(resolution.unbounded, isTrue);
        expect(resolution.limit, isNull);
        expect(resolution.diagnostic, contains(envVar));
      }
    });

    test('unparseable resolves to UNBOUNDED', () {
      for (final bad in ['three', '3.5', '3;', 'many', '', ' ']) {
        final resolution = OperatorRetryLimitResolution.fromEnvironment({
          envVar: bad,
        });
        expect(
          resolution.retryIsAvailable,
          isTrue,
          reason: '"$bad" is unreadable, which is not a cap and not a disable',
        );
        expect(resolution.limit, isNull, reason: '"$bad" invents no number');
        expect(resolution.diagnostic, contains(envVar));
      }
    });

    test('NON-DECIMAL integer syntax must NOT become a cap', () {
      // The direction of this test reversed along with the policy, and the
      // reason matters. Before 2026-10-12 the failure was that `0x3` would
      // silently ARM a credit-spending action. Now the action is armed by
      // default and this variable cannot arm it, so the surviving hazard is the
      // opposite one: a value its typist would call a mistake must not be
      // honoured AS A CAP, because an operator who typed `0x3` and got a silent
      // cap of 3 has been given a number they never wrote.
      //
      // It must therefore resolve to UNBOUNDED — same as unset — and never to
      // `limit == 3`.
      //
      // Surrounding whitespace is deliberately tolerated — an operator who
      // pads a compose file's value still configured a number — so it is NOT
      // in this list. `3 3` and `1-2` are: two operands is not an integer.
      for (final bad in ['0x3', '0b11', '+3', '3_000', '3 3', '1-2']) {
        final resolution = OperatorRetryLimitResolution.fromEnvironment({
          envVar: bad,
        });
        expect(
          resolution.limit,
          isNull,
          reason:
              '"$bad" is not an operator-written decimal integer and must not '
              'resolve to a cap the operator never chose',
        );
        expect(resolution.unbounded, isTrue, reason: '"$bad" means no count');
        expect(resolution.diagnostic, contains(envVar));
      }
    });

    test('an OUT-OF-RANGE value must not THROW — it resolves to no bound', () {
      // HIGH-1, unchanged in substance. A long run of digits passes a shape
      // check and then `int.parse` THROWS ("Positive input exceeds the limit
      // of integer"). That exception would escape `resolveRetryLimit()` into
      // BOTH `actionContext` and `retryFailedWorkItem`, so a mistyped
      // configuration would take down the READ path and hand the operator an
      // unhandled 500.
      //
      // So the property is still "no input throws". The far side changed from
      // "arms nothing" to "arms no COUNT", and this asserts the new far side
      // so a revert to the old one cannot pass by accident.
      final overflow = [
        '99999999999999999999999',
        '9' * 64,
        '1${'0' * 40}',
        // Just past the 64-bit ceiling.
        '9223372036854775808',
        '-9223372036854775809',
      ];

      for (final bad in overflow) {
        OperatorRetryLimitResolution resolution =
            const OperatorRetryLimitResolution(
              diagnostic: 'never assigned',
              unbounded: true,
            );
        // The assertion is the absence of a throw. If this throws, the test
        // FAILS with the FormatException rather than reporting a wrong value.
        expect(
          () => resolution = OperatorRetryLimitResolution.fromEnvironment({
            envVar: bad,
          }),
          returnsNormally,
          reason: '"$bad" must not throw out of the resolver',
        );
        expect(resolution.limit, isNull, reason: '"$bad" must invent no cap');
        expect(resolution.unbounded, isTrue);
        expect(resolution.isCountBounded, isFalse);
        expect(resolution.diagnostic, contains(envVar));
      }
    });

    test('every probed input resolves to a usable answer, and none to a cap '
        'it did not earn', () {
      // The reviewer probed 30 inputs and found exactly one — out-of-range
      // digits — that did not fail closed. This pins the whole family rather
      // than only the one that broke, so the next one is already covered.
      const unusable = [
        '',
        '   ',
        '\t',
        '\n',
        'three',
        '3.5',
        '3.0',
        '3e0',
        '0x3',
        '0X3',
        '0b11',
        '+3',
        '-3',
        '-0',
        '3_000',
        '3 3',
        '1-2',
        '٣', // Arabic-Indic digit three
        '१२३', // Devanagari one-two-three
        '３', // fullwidth three
        '3\u0000', // embedded NUL
        'null',
        'NaN',
        'Infinity',
        '0x',
        '3;',
        '99999999999999999999999',
      ];

      for (final bad in unusable) {
        final resolution = OperatorRetryLimitResolution.fromEnvironment({
          envVar: bad,
        });
        expect(
          resolution.limit,
          isNull,
          reason:
              '"$bad" must never resolve to a cap the operator did not '
              'write, and must never disable the action either',
        );
        expect(resolution.retryIsAvailable, isTrue);
        expect(resolution.unbounded, isTrue);
      }

      // And the ones that ARE numbers stay numbers — this sweep must not become
      // "treat everything as uncounted", which would quietly discard a
      // deliberate cap and silently re-arm an unbounded retry on a machine
      // whose operator had chosen otherwise.
      for (final good in ['3', ' 3 ', '007', '10', '99']) {
        final resolution = OperatorRetryLimitResolution.fromEnvironment({
          envVar: good,
        });
        expect(
          resolution.limit,
          isNotNull,
          reason:
              '"$good" is an operator-written integer and must resolve to '
              'a cap',
        );
        expect(resolution.unbounded, isFalse);
        expect(resolution.isCountBounded, isTrue);
      }

      // `0` is deliberately absent from BOTH lists above: it is the one value
      // that resolves to a third shape, and it has its own group below.
    });

    test('a negative value resolves to UNBOUNDED, not to a refusal', () {
      for (final negative in [-1, -3, -100]) {
        final resolution = OperatorRetryLimitResolution.fromEnvironment({
          envVar: '$negative',
        });
        expect(resolution.retryIsAvailable, isTrue);
        expect(resolution.unbounded, isTrue);
        expect(resolution.limit, isNull);
        // The diagnostic still NAMES the offending value — an ignored value
        // that leaves no trace is how a typo becomes a mystery.
        expect(resolution.diagnostic, contains('$negative'));
        expect(resolution.diagnostic, contains('negative'));
      }
    });

    test('a NEGATIVE ZERO is not the disable — `-0` means no count', () {
      // The subtle one, and it is here because it was a live bug in the first
      // draft of this change: `int.tryParse('-0')` returns `0`, so a check on
      // the parsed NUMBER alone let `-0` fall through into the branch that
      // switches operator retry off. A stray minus sign in a compose file
      // would have removed the operator's only way to restart work — the very
      // "a broken configuration silently disarms the action" failure the
      // 2026-10-12 reversal was made to delete.
      //
      // So the ONLY spelling that disables is a bare `0`.
      for (final spelling in ['-0', '-00', '-0 ', ' -0']) {
        final resolved = OperatorRetryLimitResolution.fromEnvironment({
          envVar: spelling,
        });

        expect(
          resolved.permanentlyDisabled,
          isFalse,
          reason: '"$spelling" is not a bare 0 and must not switch retry off',
        );
        expect(resolved.retryIsAvailable, isTrue);
        expect(resolved.unbounded, isTrue);
      }

      // …and the bare zero still does what it always did.
      expect(
        OperatorRetryLimitResolution.fromEnvironment({
          envVar: '0',
        }).permanentlyDisabled,
        isTrue,
      );
    });
  });

  group('AC-15c — "0" is still the ONLY setting that switches retry off', () {
    test('zero RESOLVES, as a valid configuration meaning disabled', () {
      final resolution = OperatorRetryLimitResolution.fromEnvironment({
        envVar: '0',
      });

      // RESOLVED: a configuration was read.
      expect(resolution.isResolved, isTrue);
      // …and it arms nothing, because the operator decided nothing may restart.
      expect(resolution.retryIsAvailable, isFalse);
      expect(resolution.unbounded, isFalse);
      expect(resolution.limit, isNull);
      expect(resolution.isCountBounded, isFalse);
    });

    test(
      'the zero diagnostic reads as CONFIGURATION and not as failure',
      () {
        final resolution = OperatorRetryLimitResolution.fromEnvironment({
          envVar: '0',
        });
        // The case-SENSITIVE check runs against the diagnostic as written: a
        // lowercased haystack can never contain the mixed-case variable name,
        // so asserting the name here would fail on the casing, not the content.
        expect(resolution.diagnostic, contains(envVar));
        final diagnostic = resolution.diagnostic.toLowerCase();

        // The shape `ExecutionCapacityResolution` would have produced, and the
        // one AC-15c exists to rule out.
        expect(diagnostic, isNot(contains('not resolved')));
        expect(diagnostic, isNot(contains('below the minimum')));
        expect(diagnostic, isNot(contains('refusing')));
        // What it says instead.
        expect(diagnostic, contains('disabled by configuration'));
      },
    );

    test('the zero diagnostic does NOT reuse the old default\'s language', () {
      // The reversal moved the default from "armed by nothing" to "armed with
      // no count", so the OLD zero diagnostic's closing advice — "Set this to 3
      // to arm restarting (HD-3's value)" — became inverted. An operator who
      // switched retrying OFF would have been told how to switch it back on,
      // and the "no fallback / must be configured" framing no longer describes
      // what the variable does.
      //
      // This asserts the inversion is not present, and that the replacement
      // says the two states apart explicitly.
      final diagnostic = OperatorRetryLimitResolution.fromEnvironment({
        envVar: '0',
      }).diagnostic.toLowerCase();

      expect(diagnostic, isNot(contains('to 3 to arm')));
      expect(diagnostic, isNot(contains('arm restarting')));
      expect(diagnostic, isNot(contains('h d-3')));
      // It must instead say that UNSET is a different thing from disabled —
      // otherwise an operator reading the log cannot tell "I turned this off"
      // from "nobody ever set this".
      expect(diagnostic, contains('unset'));
      expect(diagnostic, contains('uncounted'));
    });

    test(
      'zero and unset are different ANSWERS, not the same absence',
      () {
        final disabled = OperatorRetryLimitResolution.fromEnvironment({
          envVar: '0',
        });
        final unset = resolution(const {});

        // They are opposites, and that is the whole point of keeping them
        // apart: one removes the action, the other removes only the count.
        expect(disabled.retryIsAvailable, isFalse);
        expect(unset.retryIsAvailable, isTrue);
        expect(disabled.unbounded, isFalse);
        expect(unset.unbounded, isTrue);
        // Both are resolved, because both are understood.
        expect(disabled.isResolved, isTrue);
        expect(unset.isResolved, isTrue);
        expect(disabled.diagnostic, isNot(unset.diagnostic));
      },
    );
  });

  group('an explicit positive N still CAPS the retries', () {
    test('an explicit 3 resolves to 3 and says so in the startup line', () {
      final resolution = OperatorRetryLimitResolution.fromEnvironment({
        envVar: '3',
      });

      expect(resolution.isResolved, isTrue);
      expect(resolution.retryIsAvailable, isTrue);
      expect(resolution.unbounded, isFalse);
      expect(resolution.isCountBounded, isTrue);
      expect(resolution.limit!.maximumRetriesPerWorkItem, 3);
      expect(resolution.diagnostic, contains('$envVar=3'));
    });

    test('surrounding whitespace does not defeat a configured value', () {
      final resolution = OperatorRetryLimitResolution.fromEnvironment({
        envVar: '  3  ',
      });

      expect(resolution.limit!.maximumRetriesPerWorkItem, 3);
    });

    test('an explicit cap is named as a cap, and as NOT the default', () {
      // The same "don't reuse the old default's language" requirement as the
      // zero case, in the other direction: a configured 3 must not read like
      // the outcome of forgetting to configure anything, or an operator
      // comparing two stacks cannot tell which one they capped.
      final diagnostic = OperatorRetryLimitResolution.fromEnvironment({
        envVar: '3',
      }).diagnostic.toLowerCase();

      expect(diagnostic, contains('explicit cap'));
      expect(diagnostic, contains('unset'));
      expect(diagnostic, isNot(contains('not available')));
    });

    test(
      'THERE IS NO FALLBACK CONSTANT — nothing absent becomes a number',
      () {
        // Stated as a property of the whole family, not of one input, because
        // the failure mode is "absent ⇒ 3" and a single case would not catch
        // a default applied further down the chain. The reversal did NOT
        // reintroduce this: "no count bound" is its own resolved state, not a
        // number standing in for one.
        for (final environment in <Map<String, String>>[
          const {},
          {envVar: ''},
          {envVar: 'nonsense'},
          {envVar: '-2'},
        ]) {
          final resolved = OperatorRetryLimitResolution.fromEnvironment(
            environment,
          );
          expect(
            resolved.limit,
            isNull,
            reason: 'no fallback may be substituted for $environment',
          );
          expect(resolved.unbounded, isTrue);
          expect(resolved.diagnostic, isNot(contains('$envVar=3 ')));
        }
      },
    );
  });

  group('AC-1 / N4 — the action set is COMPUTED from the transition table', () {
    final endpoints = WorkItemActionEndpoints();
    final generous = OperatorRetryLimitResolution.fromEnvironment({
      envVar: '3',
    });

    test('an agent_failed item is offered exactly [retry, stop], in order', () {
      final actions = endpoints.actionsFor(
        WorkItemState.agentFailed,
        retryCount: 0,
        limit: generous,
      );

      expect(actions.map((a) => a.action), ['retry', 'stop']);
      // And each really is legal, asked of the table rather than assumed.
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.agentFailed,
          WorkItemState.designNotRequired,
        ),
        isTrue,
      );
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.agentFailed,
          WorkItemState.cancelled,
        ),
        isTrue,
      );
    });

    test('`terminated` is NEVER offered, though the edge exists', () {
      // The edge is genuinely legal — this is not an accident of the table.
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.agentFailed,
          WorkItemState.terminated,
        ),
        isTrue,
      );

      for (final retryCount in [0, 1, 2]) {
        final actions = endpoints.actionsFor(
          WorkItemState.agentFailed,
          retryCount: retryCount,
          limit: generous,
        );
        expect(actions.map((a) => a.action), isNot(contains('terminated')));
        expect(actions.map((a) => a.toState), isNot(contains('terminated')));
      }
    });

    test(
      'EVERY state is a SUBSET of what `isLegalTransition` permits — the '
      'enumeration AC-1 asks for, and the one a hardcoded list fails',
      () {
        // This was `offered == legal`, and that equality is what let the panel
        // be offered on `planned` and `draft`: the generic escape made
        // `(anything non-terminal -> cancelled)` legal, and `planned` has a
        // real pre-existing edge to `designNotRequired`, so the table said yes
        // and the panel believed it. Equality is the wrong invariant here
        // because this surface is scoped (AC-2) — a legal edge is not
        // automatically an action this screen offers.
        //
        // The invariant AC-1 and N4 actually state is one-directional: never
        // offer an action the table forbids. That is the subset below, and it
        // is the property a hardcoded list breaks.
        for (final state in WorkItemState.values) {
          final offered = endpoints
              .actionsFor(state, retryCount: 0, limit: generous)
              .map((a) => a.action)
              .toSet();

          final legal = {
            for (final kind in OperatorActionKind.values)
              if (WorkItemTransitions.isLegalTransition(
                state,
                kind.targetState,
              ))
                kind.wire,
          };

          expect(
            offered.difference(legal),
            isEmpty,
            reason:
                'from $state the endpoint offered ${offered.difference(legal)}, '
                'which the transition table does not permit. A hardcoded '
                '[retry, stop] fails here for a terminal state.',
          );
        }
      },
    );

    test(
      'and on the ONE state this surface is for, it offers the table\'s full '
      'answer — the scoping must not quietly withhold a legal action',
      () {
        // The subset assertion above would still pass if `actionsFor` returned
        // `[]` for EVERY state, so the equality is pinned where it belongs:
        // on the failed state, against the REAL TABLE — recomputed here rather
        // than written as a literal, so if the table ever stops permitting an
        // edge this fails instead of silently going stale.
        final expected = [
          for (final kind in OperatorActionKind.values)
            if (WorkItemTransitions.isLegalTransition(
              WorkItemState.agentFailed,
              kind.targetState,
            ))
              kind.wire,
        ];

        expect(expected, ['retry', 'stop']);
        expect(
          endpoints
              .actionsFor(
                WorkItemState.agentFailed,
                retryCount: 0,
                limit: generous,
              )
              .map((a) => a.action),
          expected,
          reason:
              'the panel\'s own state must still get the whole computed set',
        );

        // And each offered action names an edge the table actually permits, so
        // a target swapped in the extension is caught rather than rendered.
        for (final action in endpoints.actionsFor(
          WorkItemState.agentFailed,
          retryCount: 0,
          limit: generous,
        )) {
          expect(
            WorkItemTransitions.isLegalTransition(
              WorkItemState.agentFailed,
              WorkItemState.fromWire(action.toState),
            ),
            isTrue,
            reason: '${action.action} -> ${action.toState} is not a legal edge',
          );
        }
      },
    );

    test('a terminal state offers nothing at all', () {
      for (final terminal in [
        WorkItemState.completed,
        WorkItemState.cancelled,
        WorkItemState.terminated,
      ]) {
        expect(
          endpoints.actionsFor(terminal, retryCount: 0, limit: generous),
          isEmpty,
          reason: '$terminal is terminal; the generic escape does not apply',
        );
      }
    });

    test(
      'the offer is the table\'s answer MINUS this surface\'s scope — so a '
      'state the table permits but this screen must not act on proves the '
      'table is consulted',
      () {
        // The single test that separates "computed from the table" from "a
        // literal ['retry', stop']". `planned` is that state: the table DOES
        // permit `planned -> designNotRequired`, so a hardcoded list and a
        // table consultation AGREE there — which is exactly why the negative
        // alone was not enough.
        //
        // The discriminator is `agent_completed` combined with the enumeration:
        // the table permits the generic escape to `cancelled` from it, and a
        // hardcoded list would answer `[retry, stop]` anyway. Here it must
        // answer nothing.
        for (final state in [
          WorkItemState.planned,
          WorkItemState.agentCompleted,
          WorkItemState.draft,
        ]) {
          // Premise, asserted: the table really does permit SOMETHING from
          // here. If that ever stops being true the test stops proving
          // anything and says so rather than passing vacuously.
          expect(
            [
              for (final kind in OperatorActionKind.values)
                if (WorkItemTransitions.isLegalTransition(
                  state,
                  kind.targetState,
                ))
                  kind.wire,
            ],
            isNotEmpty,
            reason:
                '$state must have at least one legal edge for this test to '
                'discriminate a table lookup from a literal',
          );

          expect(
            endpoints.actionsFor(state, retryCount: 0, limit: generous),
            isEmpty,
            reason:
                '$state has a legal edge, so answering non-empty here can '
                'only come from a hardcoded list',
          );
        }
      },
    );

    test(
      'AC-2: EVERY state other than agent_failed offers NOTHING — not even the '
      'generic escape, and not even where the table would permit a retry',
      () {
        // The load-bearing case here is `planned`. `planned -> designNotRequired`
        // is a REAL, PRE-EXISTING edge (`work_item_transitions.dart:28-30` — the
        // brief calls it "the only precedent" for an edge into that state), and
        // the generic escape makes `(anything non-terminal -> cancelled)` legal
        // too. So asking the transition table ALONE would answer
        // `[retry, stop]` for `planned` and `[stop]` for `draft` — which would
        // replace "Nothing needs you here" on every run in flight, and hang a
        // credit-spending "Try again" on an edge this design never approved.
        //
        // So the assertion is about what this SURFACE offers, and it is stated
        // per state rather than only for the states someone thought of.
        final nonPanel = WorkItemState.values
            .where((s) => s != WorkItemState.agentFailed)
            .toList();

        // Including the two the generic escape would otherwise have captured.
        expect(nonPanel, contains(WorkItemState.planned));
        expect(nonPanel, contains(WorkItemState.draft));
        // And the nine parked `agent_completed` items, which §14.1 leaves to a
        // separate brief: this screen must not "solve" them (N9).
        expect(nonPanel, contains(WorkItemState.agentCompleted));

        for (final state in nonPanel) {
          expect(
            endpoints.actionsFor(state, retryCount: 0, limit: generous),
            isEmpty,
            reason:
                '$state is not a failed item, so this panel must not appear '
                'and must not replace the existing right-column text',
          );
        }
      },
    );

    test(
      'the RETRY action is offered from agent_failed alone — a `planned` item '
      'is never given a credit-spending button',
      () {
        for (final state in WorkItemState.values) {
          final offersRetry = endpoints
              .actionsFor(state, retryCount: 0, limit: generous)
              .any((a) => a.action == 'retry');

          expect(
            offersRetry,
            state == WorkItemState.agentFailed,
            reason:
                'from $state the retry must be offered exactly when the item '
                'is a failed one',
          );
        }
      },
    );
  });

  group(
    'AC-15 / AC-15c / AC-15d — what the bound withholds, and what it does not',
    () {
      final endpoints = WorkItemActionEndpoints();

      test('an explicit 3 still makes the third retry the last one offered', () {
        final limit = OperatorRetryLimitResolution.fromEnvironment({
          envVar: '3',
        });
        // §6.6: "When attemptNumber >= attemptLimit the server returns
        // notConfigured and the client does not render the retry button at all."
        // UNCHANGED by the reversal — an operator who configured a cap still
        // gets that cap.
        for (final (used, expectRetry) in [
          (0, true),
          (1, true),
          (2, true),
          (3, false),
          (4, false),
        ]) {
          final actions = endpoints.actionsFor(
            WorkItemState.agentFailed,
            retryCount: used,
            limit: limit,
          );
          expect(
            actions.any((a) => a.action == 'retry'),
            expectRetry,
            reason:
                'after $used retries the retry button is '
                '${expectRetry ? "still" : "no longer"} offered',
          );
        }
      });

      test('the attempt position counts the AUDIT ROWS, 1-based', () {
        final limit = OperatorRetryLimitResolution.fromEnvironment({
          envVar: '3',
        });
        final actions = endpoints.actionsFor(
          WorkItemState.agentFailed,
          retryCount: 1,
          limit: limit,
        );
        final retry = actions.firstWhere((a) => a.action == 'retry');

        // Zero prior rows ⇒ "attempt 1 of 3"; one prior row ⇒ "attempt 2 of 3".
        expect(retry.attemptNumber, 2);
        expect(retry.attemptLimit, 3);
      });

      test(
        'an UNCONFIGURED limit now withholds NOTHING — retry is always '
        'offered, however many retries this item already has',
        () {
          // The reversal, seen from the panel. Before it, the UNSET case
          // withheld retry and the zero case did the same thing for the same
          // reason; now they are opposites, and this asserts the new one.
          final uncapped = resolution(const {});

          for (final used in [0, 1, 3, 17, 250, 100000]) {
            final actions = endpoints.actionsFor(
              WorkItemState.agentFailed,
              retryCount: used,
              limit: uncapped,
            );

            expect(
              actions.map((a) => a.action),
              ['retry', 'stop'],
              reason:
                  'after $used uncounted retries the retry button must still be '
                  'offered — this is the entire point of the reversal',
            );
            // …and the position is still a truthful 1-based count of what the
            // operator has actually done, so the panel can say "this will be
            // attempt 250" rather than pretending it is the first.
            expect(
              actions.first.attemptNumber,
              used + 1,
              reason:
                  'the attempt position must not reset when the count is '
                  'uncounted',
            );
          }
        },
      );

      test(
        'a ZERO limit withholds the retry but STILL offers stop (AC-15d)',
        () {
          final actions = endpoints.actionsFor(
            WorkItemState.agentFailed,
            retryCount: 0,
            limit: OperatorRetryLimitResolution.fromEnvironment({
              envVar: '0',
            }),
          );

          expect(actions.map((a) => a.action), ['stop']);
          // `attemptLimit: 0` is the wire signal for "no count"; the client
          // must not render it as a real budget of zero retries.
          expect(actions.single.attemptLimit, 0);
          expect(actions.single.attemptNumber, isNull);
        },
      );

      test('a spent limit withholds the retry but STILL offers stop', () {
        final actions = endpoints.actionsFor(
          WorkItemState.agentFailed,
          retryCount: 3,
          limit: OperatorRetryLimitResolution.fromEnvironment({
            envVar: '3',
          }),
        );

        expect(actions.map((a) => a.action), ['stop']);
      });

      test(
        'both actions are marked confirm-required and the edge is named',
        () {
          final actions = endpoints.actionsFor(
            WorkItemState.agentFailed,
            retryCount: 0,
            limit: OperatorRetryLimitResolution.fromEnvironment({
              envVar: '3',
            }),
          );

          final retry = actions.firstWhere((a) => a.action == 'retry');
          expect(retry.toState, WorkItemState.designNotRequired.wire);
          expect(retry.destructive, isFalse);
          // Unchanged and load-bearing under the reversal: an uncounted retry
          // is still ONE deliberate, confirmed spend per press. This is the
          // property that makes unbounded a policy rather than a hole.
          expect(retry.confirmRequired, isTrue);

          final stop = actions.firstWhere((a) => a.action == 'stop');
          expect(stop.toState, WorkItemState.cancelled.wire);
          expect(stop.destructive, isTrue);
          expect(stop.confirmRequired, isTrue);
          // A stop consumes no attempt, so it must not claim one.
          expect(stop.attemptNumber, isNull);
        },
      );
    },
  );

  // ==================================================================
  // THE DISTINCTION THIS WHOLE CHANGE IS ABOUT.
  //
  // "Unlimited operator retries" and "unlimited automatic retries" are
  // opposite decisions. Only the first one was made. These two groups are what
  // stop a future change from quietly turning the second into the first.
  // ==================================================================

  group('SEPARATION — the ONLY caller of the retry is a human', () {
    // Read from disk rather than restated from memory, because the safety
    // argument for unbounded operator retries is entirely a claim about the
    // call graph. A comment asserting "there is no automation" is worth
    // nothing; a test that fails when an automation caller appears is worth
    // something.
    //
    // PRODUCTION callers only. Test files legitimately call the endpoint
    // directly — they are how the guards are exercised — and the generated
    // client necessarily names the method.
    test(
      'no production code outside the operator UI calls retryFailedWorkItem',
      () {
        // `dart test` runs with the package root as the working directory, so
        // the repository root is two levels up (`apps/server` -> `apps` -> `.`).
        const repoRoot = '../..';
        final callers = _productionCallersOfRetry(repoRoot);

        expect(
          callers,
          unorderedEquals([
            'apps/control_plane/lib/data/control_plane_repository.dart',
            'apps/control_plane/lib/features/run_detail/run_detail_bloc.dart',
          ]),
          reason:
              'retryFailedWorkItem now permits an UNBOUNDED number of '
              'credit-spending restarts. That is only safe while every caller '
              'is a human behind an authenticated session. A new caller here — '
              'an agent, a cron, a webhook, a bulk tool — turns the reversal '
              'into unbounded UNSOLICITED spend, and must be a human decision '
              'rather than a merge. Review the new path before adding it to '
              'this list.',
        );
      },
    );

    test(
      'the audit is not blind to a caller OUTSIDE a lib/ directory (M1)',
      () {
        // The mutant that proved the old filter toothless. `apps/server/bin/`
        // is a real directory holding real executable entrypoints; a caller
        // written there was skipped by the `/lib/` filter and the audit stayed
        // green.
        //
        // Rather than assert the scan's internals, this drives the SAME scan
        // over a temporary planted caller and requires it to be CAUGHT — so
        // the property is executable, and it fails loudly if someone narrows
        // the filter back to `/lib/` or excludes `bin/` again.
        const repoRoot = '../..';
        final planted = Directory('$repoRoot/apps/server/bin')
          ..createSync(recursive: true);
        final file = File('${planted.path}/zz_audit_mutant.dart');
        const body =
            '// Temporary caller planted by the audit self-test.\n'
            'Future<void> plant() => retryFailedWorkItem(workItemId: "w");\n';
        file.writeAsStringSync(body);
        addTearDown(() {
          if (file.existsSync()) file.deleteSync();
        });

        expect(
          _productionCallersOfRetry(repoRoot),
          contains('apps/server/bin/zz_audit_mutant.dart'),
          reason:
              'the caller audit MUST catch an automation caller outside lib/. '
              'Before this correction it filtered on `/lib/` and reported '
              'green while an apps/server/bin/ caller sat in the tree — the '
              'false green that made it load-bearing.',
        );
      },
    );

    test('the UI caller is reached through an explicit confirm step', () {
      // The bloc only submits on `RunDetailActionSubmitted`, and the panel
      // requires `confirmRequired` plus a non-blank reason. Asserted as a
      // source property rather than as behaviour so a refactor that inlines
      // the RPC into the page — losing the confirm strip — fails here.
      final bloc = File(
        '../control_plane/lib/features/run_detail/run_detail_bloc.dart',
      );
      expect(bloc.existsSync(), isTrue, reason: 'the operator UI must exist');

      final source = bloc.readAsStringSync();
      expect(source, contains('RunDetailActionSubmitted'));
      expect(source, contains('retryFailedWorkItem'));
    });
  });

  group(
    'SEPARATION — AUTOMATIC retries stay bounded by the job\'s maxAttempts',
    () {
      test('triage jobs are still capped at maxAttempts: 2', () {
        // The concrete number, asserted. If this ever rises, the "automatic
        // retries are still bounded" claim needs re-examining on its own
        // merits — it is not made true by the operator-side reversal.
        expect(triageDefectDefinition.maxAttempts, 2);
      });

      test('a transient failure cannot be retried past maxAttempts', () {
        // This is the REAL policy the scheduler's own tick consults
        // (`scheduler.dart:790`) and the one `baseline_dispatch.dart` mirrors
        // at line 670. Driving it directly is what makes the claim "automatic
        // retries remain bounded" evidence rather than an assertion.
        const policy = RetryPolicy();
        final at = DateTime.utc(2026);

        Job jobAt(int attempt) => Job(
          jobId: 'jb-auto',
          workItemId: 'defect-DEF-1',
          jobType: triageDefectDefinition.jobType,
          requiredRole: triageDefectDefinition.requiredRole,
          requiredCapabilities: triageDefectDefinition.requiredCapabilities,
          priority: triageDefectDefinition.priority,
          state: JobState.retryWaiting,
          dedupeKey: 'defect-DEF-1:triage_defect:a1',
          createdAt: at,
          instruction: 'triage this defect',
          attempt: attempt,
          maxAttempts: triageDefectDefinition.maxAttempts,
          version: 1,
        );

        expect(policy.canRetry(jobAt(1)), isTrue);
        // The bound: attempt 2 of 2 is spent, and nothing retries beyond it.
        expect(policy.canRetry(jobAt(2)), isFalse);
        expect(policy.canRetry(jobAt(3)), isFalse);
        expect(policy.canRetry(jobAt(9)), isFalse);
      });

      test(
        'the operator count and the automatic bound are different numbers',
        () {
          // The pair, side by side. An operator may restart a work item
          // without limit; each job THAT PRODUCES still dies after
          // `maxAttempts` automatic retries. Neither number is derived from
          // the other, and `retryFailedWorkItem` never reads either — it
          // enqueues nothing.
          final automatic = triageDefectDefinition.maxAttempts;
          final operatorUncapped = resolution(const {});

          expect(automatic, 2);
          expect(operatorUncapped.unbounded, isTrue);
          expect(operatorUncapped.wireAttemptLimit, 0);
          expect(
            operatorUncapped.isCountBounded,
            isFalse,
            reason:
                'the operator bound and the job bound are unrelated; the '
                'endpoint must not acquire one from the scheduler by accident',
          );
        },
      );
    },
  );

  group(
    'AC-13 / N12 — the idempotency key is a replay key, not authorization',
    () {
      test('it is a prefixed, client-supplied id with no authority in it', () {
        expect(
          operatorRetryIdempotencyKeyPrefix,
          'operator-retry:',
          reason: 'the prefix is a lookup aid for a replay',
        );
        // The value it wraps is the CLIENT's id, minted once per operator
        // intent. Nothing in this endpoint derives authorization from its shape.
        expect(
          'operator-retry:${OperatorActionRecord(
            actionId: 'a',
            workItemId: 'w',
            action: OperatorActionKind.retry.wire,
            fromState: 'agent_failed',
            toState: 'design_not_required',
            requestedBy: 'operator',
            reason: 'because',
            requestId: 'req-1',
            createdAt: DateTime.utc(2026),
          ).requestId}',
          'operator-retry:req-1',
        );
      });
    },
  );
}

String jsonish(String s) =>
    '"${s.replaceAll('\n', r'\n').replaceAll('\t', r'\t')}"';

/// The resolution for an environment where the operator configured NOTHING —
/// the state every stack is in by default since 2026-10-12.
///
/// A named helper rather than a repeated literal, because this exact state is
/// now the DEFAULT and the reversal's whole subject: every expectation phrased
/// in terms of it should be visibly about "no configuration", not about one
/// particular spelling of it.
OperatorRetryLimitResolution resolution(Map<String, String> environment) =>
    OperatorRetryLimitResolution.fromEnvironment(environment);

/// Strips `/* … */` blocks and `//` line comments, so a file that merely NAMES
/// `retryFailedWorkItem` in prose is not counted as a caller of it.
///
/// Needed because two server-side files reference the method in doc comments
/// only (`workflow_endpoints.dart`, `control_plane_service.dart`), and a caller
/// audit that counted those would either fail forever or — worse — be edited
/// to tolerate them, at which point it detects nothing.
///
/// The `//` handling is crude about a `//` inside a string literal, but it errs
/// in the safe direction here: stripping can only REMOVE a candidate caller,
/// never invent one, and a real call site in this repository is never preceded
/// by a bare `//` on its own line.
String _codeOnly(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      return i < 0 ? line : line.substring(0, i);
    })
    .join('\n');

/// Every non-test Dart file under the given root that names
/// `retryFailedWorkItem` in CODE (see [_codeOnly]), as paths relative to
/// [repoRoot].
///
/// ## WHY IT SCANS EVERYTHING INSTEAD OF FILTERING ON `/lib/`
///
/// The previous version of this audit skipped any path without a `/lib/`
/// segment and justified it in a comment: "a caller must sit under a `lib/`
/// directory to count at all... therefore still fails here rather than passing
/// unseen."
///
/// **That was false, and it was load-bearing.** `apps/server/bin/` exists,
/// holds six real executable entrypoints (`onboard_shipit.dart`,
/// `add_human_claims.dart`, …), and is not under `lib/` — so an automation
/// caller written there was skipped and the audit reported green while an
/// agent-driven, credit-spending caller sat in the tree. A test that cannot
/// fail is not a test, and this one gates an UNBOUNDED spend.
///
/// The filter is therefore inverted: it excludes things that are not callers
/// BY CONSTRUCTION — tests, generated transport, build output, and the endpoint
/// that declares the method — and asks nothing else of the path. Tests are
/// excluded because they legitimately call the endpoint directly (they are how
/// the guards are exercised), not because of where they sit.
///
/// Narrowing this back to `/lib/`, or adding an exclusion for `bin/` or `tool/`,
/// reintroduces the blind spot. `test/…the audit is not blind to a caller
/// OUTSIDE a lib/ directory` plants a real caller in `apps/server/bin/` and
/// fails if it is not caught, so the property is executable rather than a
/// claim in a comment.
List<String> _productionCallersOfRetry(String repoRoot) {
  final callers = <String>[];

  for (final dir in ['apps', 'packages', 'cli', 'tools']) {
    final path = Directory('$repoRoot/$dir');
    if (!path.existsSync()) continue;
    for (final entity in path.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path.replaceFirst('$repoRoot/', '');

      // Generated protocol clients are the transport, not a caller.
      if (relative.contains('.g.dart') ||
          relative.contains('/generated/') ||
          relative.contains('/protocol/')) {
        continue;
      }
      // Build output and tool caches are not source. They are gitignored and
      // regenerated, so scanning them would make the verdict depend on whether
      // someone happened to run `flutter test` first.
      if (relative.contains('/.dart_tool/') || relative.contains('/build/')) {
        continue;
      }
      // The endpoint DECLARES the method; that is the definition, not a use.
      if (relative.endsWith('endpoints/work_item_action_endpoints.dart')) {
        continue;
      }
      if (_isTestSource(relative)) continue;
      if (!_codeOnly(entity.readAsStringSync()).contains(
        'retryFailedWorkItem',
      )) {
        continue;
      }
      callers.add(relative);
    }
  }
  return callers;
}

/// True when [relative] is test source by Dart convention rather than by
/// location: any `test/`, `test_driver/` or `integration_test/` directory, or
/// any file named `*_test.dart`.
///
/// ## WHY THIS IS A CONVENTION AND NOT A PATH PREFIX
///
/// Naming the convention rather than one hard-coded directory is what makes
/// the caller audit total: a test that happens to live at a package root, or
/// under `tool/`, is still excluded, while a PRODUCTION entrypoint in `bin/`
/// or `tool/` is still counted. Both halves of that were false under the old
/// `/lib/` filter, which got the first right only by accident and the second
/// wrong.
bool _isTestSource(String relative) {
  if (relative.endsWith('_test.dart')) return true;
  final segments = relative.split('/');
  return segments.any(
    (s) => s == 'test' || s == 'test_driver' || s == 'integration_test',
  );
}
