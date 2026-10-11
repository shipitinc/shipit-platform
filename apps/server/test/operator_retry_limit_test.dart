import 'package:control_plane_server/src/endpoints/work_item_action_endpoints.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart' show WorkItemTransitions;
import 'package:workflow_store/workflow_store.dart'
    show OperatorActionKind, OperatorActionRecord;

/// §6.6 — the fail-closed retry bound, and the server-computed action set.
///
/// ## WHY THE RESOLUTION IS TESTED IN ITS OWN FILE
///
/// It is the safety invariant of the whole surface: an operator action that
/// spends real model credits must never be armed by a missing configuration.
/// It is also the one piece of §6.6 an implementer is most likely to get
/// subtly wrong — by reusing `ExecutionCapacityResolution`, which resolves
/// `0` to UNRESOLVED with a failure-styled diagnostic. AC-15c is the criterion
/// that catches exactly that, so it is asserted here directly rather than left
/// to the panel tests to notice.
void main() {
  const envVar = operatorRetryLimitEnvVar;

  group('§6.6 — an unset retry limit fails closed', () {
    test('unset resolves to UNRESOLVED, never to a number', () {
      final resolution = OperatorRetryLimitResolution.fromEnvironment(
        const {},
      );

      expect(resolution.isResolved, isFalse);
      expect(resolution.retryIsAvailable, isFalse);
      expect(resolution.limit, isNull);
    });

    test('the diagnostic names the variable and is never blank', () {
      final resolution = OperatorRetryLimitResolution.fromEnvironment(
        const {},
      );

      expect(resolution.diagnostic, contains(envVar));
      expect(resolution.diagnostic.trim(), isNotEmpty);
    });

    test('blank resolves to UNRESOLVED', () {
      for (final blank in ['', '   ', '\t', '\n']) {
        final resolution = OperatorRetryLimitResolution.fromEnvironment({
          envVar: blank,
        });
        expect(
          resolution.retryIsAvailable,
          isFalse,
          reason: 'blank ${jsonish(blank)} must not arm a spend',
        );
        expect(resolution.diagnostic, contains(envVar));
      }
    });

    test('unparseable resolves to UNRESOLVED', () {
      for (final bad in ['three', '3.5', '3;', 'many', '', ' ']) {
        final resolution = OperatorRetryLimitResolution.fromEnvironment({
          envVar: bad,
        });
        expect(
          resolution.retryIsAvailable,
          isFalse,
          reason: '"$bad" must not arm a spend',
        );
      }
    });

    test('NON-DECIMAL integer syntax must not arm a spend', () {
      // The one that actually bit: `int.tryParse` reads `0x3` as 3 and `+3` as
      // 3, so a value its typist would call a mistake would have silently
      // ARMED the one action in this repository that spends real credits. The
      // resolution is strict decimal, so both refuse instead.
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
              '"$bad" is not an operator-written decimal integer and must '
              'not resolve to a number that arms a spend',
        );
        expect(resolution.diagnostic, contains(envVar));
      }
    });

    test('a negative value resolves to UNRESOLVED', () {
      for (final negative in [-1, -3, -100]) {
        final resolution = OperatorRetryLimitResolution.fromEnvironment({
          envVar: '$negative',
        });
        expect(resolution.retryIsAvailable, isFalse);
        expect(resolution.diagnostic, contains('$negative'));
      }
    });
  });

  group('§6.6 / AC-15c — "0" is a CONFIGURATION, not a failure', () {
    test('zero RESOLVES, as a valid configuration meaning disabled', () {
      final resolution = OperatorRetryLimitResolution.fromEnvironment({
        envVar: '0',
      });

      // RESOLVED: a configuration was read.
      expect(resolution.isResolved, isTrue);
      // …but it arms nothing, because the operator decided nothing may restart.
      expect(resolution.retryIsAvailable, isFalse);
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

    test(
      'zero and unset are different ANSWERS, not the same absence',
      () {
        final disabled = OperatorRetryLimitResolution.fromEnvironment({
          envVar: '0',
        });
        final unset = OperatorRetryLimitResolution.fromEnvironment(const {});

        // Both refuse the retry, but only one of them is a working
        // configuration. Collapsing them would tell an operator their machine
        // is misconfigured when they deliberately switched retrying off.
        expect(disabled.isResolved, isTrue);
        expect(unset.isResolved, isFalse);
        expect(disabled.diagnostic, isNot(unset.diagnostic));
      },
    );
  });

  group('§6.6 / AC-15b — only an explicit value arms the retry', () {
    test('an explicit 3 resolves to 3 and says so in the startup line', () {
      final resolution = OperatorRetryLimitResolution.fromEnvironment({
        envVar: '3',
      });

      expect(resolution.isResolved, isTrue);
      expect(resolution.retryIsAvailable, isTrue);
      expect(resolution.limit!.maximumRetriesPerWorkItem, 3);
      expect(resolution.diagnostic, contains('$envVar=3'));
    });

    test('surrounding whitespace does not defeat a configured value', () {
      final resolution = OperatorRetryLimitResolution.fromEnvironment({
        envVar: '  3  ',
      });

      expect(resolution.limit!.maximumRetriesPerWorkItem, 3);
    });

    test(
      'THERE IS NO FALLBACK CONSTANT — unset never becomes 3, or any number',
      () {
        // Stated as a property of the whole family, not of one input, because
        // the failure mode is "absent ⇒ 3" and a single case would not catch
        // a default applied further down the chain.
        for (final environment in <Map<String, String>>[
          const {},
          {envVar: ''},
          {envVar: 'nonsense'},
          {envVar: '-2'},
        ]) {
          final resolution = OperatorRetryLimitResolution.fromEnvironment(
            environment,
          );
          expect(
            resolution.limit,
            isNull,
            reason: 'no fallback may be substituted for $environment',
          );
          expect(resolution.diagnostic, isNot(contains('=3 ')));
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

      test('the third retry is the last one offered', () {
        final limit = OperatorRetryLimitResolution.fromEnvironment({
          envVar: '3',
        });
        // §6.6: "When attemptNumber >= attemptLimit the server returns
        // notConfigured and the client does not render the retry button at all."
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
        'an UNSET limit withholds the retry but STILL offers stop (AC-15d)',
        () {
          final actions = endpoints.actionsFor(
            WorkItemState.agentFailed,
            retryCount: 0,
            limit: OperatorRetryLimitResolution.fromEnvironment(const {}),
          );

          expect(actions.map((a) => a.action), ['stop']);
          expect(
            actions.single.destructive,
            isTrue,
            reason:
                'the only exit left must still be the reversible-worded one',
          );
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
          // `attemptLimit: 0` is the wire signal for "not configured"; the
          // client must not render it as a real budget of zero retries.
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
