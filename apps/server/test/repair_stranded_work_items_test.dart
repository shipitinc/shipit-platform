/// Proves the stranded-work-item repair is real, generic and idempotent.
///
/// The subject is the one-shot repair script in `bin/`. It is imported here
/// rather than duplicated, because a copy is a second implementation that can
/// pass while the script the Manager actually runs fails.
///
/// ## WHY A SYNTHETIC ID IS THE POINT, NOT A DETAIL
///
/// A live work item is stranded in QA today. Every id in this file is
/// deliberately a DIFFERENT synthetic one, and
/// [works for ANY stranded feature work item, not one id] proves the repair
/// works for ids it has never seen. A test written against the live id would
/// pass against a script that special-cased it — which is the exact defect this
/// correction refused. The live ids are deliberately absent from this file
/// entirely, so that no assertion here can be satisfied by naming one.
library;

import 'dart:io';

import 'package:control_plane_server/src/triage/lane_e_design_remediation_work_item.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart' show DefectStore;
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:scheduler/scheduler.dart';
import 'package:serverpod/serverpod.dart' show ServerpodRunMode;
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';

import '../bin/repair_stranded_work_items.dart';

/// The product under test declares exactly one gate, so a contract that is
/// written for the wrong reason (a triage contract stamped onto a feature item)
/// would be distinguishable by its gates, not only by its existence.
const String kProduct = 'shipit-platform-under-repair';

/// A product that has declared NOTHING — the refusal path, which must not
/// invent a contract id.
const String kUndeclaredProduct = 'product-that-declared-nothing';

/// Deliberately NOT any live work item id — see the library comment.
const String kSyntheticFeatureItem = 'WI-feature-1789000000000001';

/// A second synthetic id, so "works for any stranded feature item" is a claim
/// about the code rather than about one string.
const String kOtherSyntheticFeatureItem = 'WI-feature-1789000000000002';

const String kSyntheticDefectId = 'DEF-1789000000000100';

/// A second synthetic work item used as the defect's `affectedWorkItemId` in the
/// unresolved-product refusal. It is seeded with a BLANK product id, which is
/// the only condition under which `resolveDesignRemediationProductId` returns
/// null and `DesignRemediationWorkItemProvisioner.ensurePersisted` returns null.
const String kBlankProductAnchorItem = 'WI-feature-1789000000000003';

final DateTime kNow = DateTime.utc(2026, 10, 17, 11, 45, 0);

void main() {
  group('stranded work item repair', () {
    test(
      'attaches a REAL QA contract to a stranded feature work item, from the '
      "product's declared spec",
      () async {
        final host = _Host();
        await host.strandFeature(kSyntheticFeatureItem);

        final outcome = await host.repair.repairWorkItem(
          kSyntheticFeatureItem,
        );

        expect(outcome.qaContractAction, startsWith('attached:'));

        final item = await host.workflowStore.readWorkItem(
          kSyntheticFeatureItem,
        );
        expect(item.qaContractId, isNotNull);

        // The stamped id is the one the PRODUCT's provisioner addressed, derived
        // from the work item id — not a string this test or the script chose.
        expect(
          item.qaContractId,
          productQAContractIdForWorkItem(kSyntheticFeatureItem),
        );

        // And it is a real, readable, separately-owned row: the work item's
        // guard only null-checks, so a fabricated id would satisfy it and
        // satisfy nothing else.
        final contract = await host.contracts.readQAContract(
          item.qaContractId!,
        );
        expect(contract, isNotNull, reason: 'the contract row must exist');
        expect(contract!.contractId, item.qaContractId);
        expect(
          contract.metadata?[qaContractWorkItemIdMetadataKey],
          kSyntheticFeatureItem,
        );
        expect(contract.workItemCategory, WorkItemCategory.feature);

        // The gates are the PRODUCT's declared gates, verbatim.
        final declared = await host.specStore.readQAContractSpec(kProduct);
        expect(
          contract.gates.map((g) => g.gateId).toList(),
          declared!.gates.map((g) => g.gateId).toList(),
        );
      },
    );

    test(
      'works for ANY stranded feature work item, not one id',
      () async {
        // Two ids, one repair, one code path. If anything in the repair were
        // shaped to a particular id, this is where it shows.
        final host = _Host();
        await host.strandFeature(kSyntheticFeatureItem);
        await host.strandFeature(kOtherSyntheticFeatureItem);

        for (final id in [kSyntheticFeatureItem, kOtherSyntheticFeatureItem]) {
          await host.repair.repairWorkItem(id);
          final item = await host.workflowStore.readWorkItem(id);
          expect(item.qaContractId, productQAContractIdForWorkItem(id));
          expect(
            await host.contracts.readQAContract(item.qaContractId!),
            isNotNull,
            reason: '$id must be governed by a real contract row',
          );
        }
      },
    );

    test('is idempotent: a second run writes nothing at all', () async {
      final host = _Host();
      await host.strandFeature(kSyntheticFeatureItem);

      await host.repair.repairWorkItem(kSyntheticFeatureItem);

      final afterFirst = await host.workflowStore.readWorkItem(
        kSyntheticFeatureItem,
      );
      final writesAfterFirst = host.contracts.writeCounts.values.fold<int>(
        0,
        (a, b) => a + b,
      );
      final transitionsAfterFirst = await host.workflowStore
          .readTransitionHistory(kSyntheticFeatureItem);
      final actionsAfterFirst = await host.workflowStore
          .readOperatorActionsForWorkItem(kSyntheticFeatureItem);

      final second = await host.repair.repairWorkItem(kSyntheticFeatureItem);

      final afterSecond = await host.workflowStore.readWorkItem(
        kSyntheticFeatureItem,
      );

      // No version bump means no CAS write happened.
      expect(afterSecond.version, afterFirst.version);
      expect(afterSecond.state, afterFirst.state);
      expect(afterSecond.qaContractId, afterFirst.qaContractId);
      expect(
        host.contracts.writeCounts.values.fold<int>(0, (a, b) => a + b),
        writesAfterFirst,
        reason: 'the second run must not re-write the contract row',
      );
      expect(
        await host.workflowStore.readTransitionHistory(kSyntheticFeatureItem),
        transitionsAfterFirst,
        reason: 'the second run must not record another transition',
      );
      expect(
        await host.workflowStore.readOperatorActionsForWorkItem(
          kSyntheticFeatureItem,
        ),
        actionsAfterFirst,
        reason: 'the second run must not record another operator action',
      );
      expect(second.wroteAnything, isFalse);
      expect(second.qaContractAction, startsWith('already-present'));
    });

    test(
      'records the DURABLE permanent failure, then operatorRetry re-dispatches',
      () async {
        final host = _Host();
        await host.strandFeature(kSyntheticFeatureItem);
        await host.failJobPermanently(kSyntheticFeatureItem);

        final outcome = await host.repair.repairWorkItem(
          kSyntheticFeatureItem,
        );

        expect(outcome.retried, isTrue);
        expect(outcome.stateBefore, WorkItemState.agentExecuting.wire);
        expect(outcome.stateAfter, WorkItemState.designNotRequired.wire);

        // AC-4: the transition row exists, and its PERSISTED reason names the
        // real failure kind read off the job row rather than a literal.
        final history = await host.workflowStore.readTransitionHistory(
          kSyntheticFeatureItem,
        );
        final failureRow = history.firstWhere(
          (r) =>
              r.fromState == WorkItemState.agentExecuting &&
              r.toState == WorkItemState.agentFailed,
        );
        expect(failureRow.reason, contains('JobFailureKind.permanent'));
        expect(failureRow.reason, contains(host.permanentJobId));
        expect(failureRow.reason, contains('platform verification failed'));

        // And the retry is the sanctioned operator verb, with an audit row.
        final actions = await host.workflowStore.readOperatorActionsForWorkItem(
          kSyntheticFeatureItem,
        );
        expect(actions, hasLength(1));
        expect(actions.single.action, 'retry');
        expect(actions.single.requestedBy, repairRequestedBy);

        // Re-dispatch is the ordinary scheduler tick, because the state the
        // retry lands on is a real entry state of the triage job definition.
        expect(outcome.stateAfter, WorkItemState.designNotRequired.wire);
        expect(
          triageDefectDefinition.entryStates.contains(
            WorkItemState.designNotRequired,
          ),
          isTrue,
          reason:
              'operatorRetry only re-dispatches if the scheduler can pick '
              'the item up; this asserts the assumption rather than trusting it',
        );

        // The contract survives the two transitions.
        final item = await host.workflowStore.readWorkItem(
          kSyntheticFeatureItem,
        );
        expect(item.qaContractId, isNotNull);
      },
    );

    test(
      'REFUSES to record a failure it cannot source, rather than inventing one',
      () async {
        // Truthfulness: no terminal failed job exists for this item, so there is
        // no durable record of anything having stopped. A reason written here
        // would be fiction on a transition row.
        final host = _Host();
        await host.strandFeature(kSyntheticFeatureItem);

        final outcome = await host.repair.repairWorkItem(
          kSyntheticFeatureItem,
        );

        expect(outcome.retried, isFalse);
        expect(outcome.stateAfter, WorkItemState.agentExecuting.wire);
        expect(
          outcome.notes.join(' '),
          contains('REFUSED'),
          reason: 'the refusal must be reported, not silent',
        );
        final history = await host.workflowStore.readTransitionHistory(
          kSyntheticFeatureItem,
        );
        expect(
          history.where((r) => r.toState == WorkItemState.agentFailed),
          isEmpty,
        );
      },
    );

    test('a declared-nothing product is refused BY NAME, not faked', () async {
      final host = _Host();
      await host.strandFeature(
        kSyntheticFeatureItem,
        productId: kUndeclaredProduct,
      );

      final outcome = await host.repair.repairWorkItem(
        kSyntheticFeatureItem,
      );

      expect(outcome.qaContractAction, 'refused:notDeclared');
      expect(outcome.qaContractId, isNull);
      final item = await host.workflowStore.readWorkItem(
        kSyntheticFeatureItem,
      );
      expect(item.qaContractId, isNull, reason: 'no contract may be invented');
      expect(host.contracts.rowCount, 0);
    });

    test('--dry-run reports intended changes and writes NOTHING', () async {
      final host = _Host(dryRun: true);
      await host.strandFeature(kSyntheticFeatureItem);
      await host.failJobPermanently(kSyntheticFeatureItem);

      final outcome = await host.repair.repairWorkItem(
        kSyntheticFeatureItem,
      );

      // It reports what it WOULD do, naming the exact contract id.
      expect(outcome.qaContractAction, startsWith('would-attach:'));
      expect(
        outcome.qaContractAction,
        contains(productQAContractIdForWorkItem(kSyntheticFeatureItem)),
      );
      expect(outcome.failureReason, contains('JobFailureKind.permanent'));
      expect(outcome.notes.join(' '), contains('would record'));

      // And nothing was written: no contract row, no column, no transition, no
      // operator action.
      expect(host.contracts.rowCount, 0);
      final item = await host.workflowStore.readWorkItem(
        kSyntheticFeatureItem,
      );
      expect(item.qaContractId, isNull);
      expect(item.state, WorkItemState.agentExecuting);
      expect(item.version, 1);
      expect(
        await host.workflowStore.readTransitionHistory(kSyntheticFeatureItem),
        isEmpty,
      );
      expect(
        await host.workflowStore.readOperatorActionsForWorkItem(
          kSyntheticFeatureItem,
        ),
        isEmpty,
      );
    });
  });

  group('a SECOND stranded execution is recordable (F-92)', () {
    /// The live shape: one failure already recorded and retried, the item
    /// re-dispatched, and stranded a second time with NO new failure row yet.
    ///
    /// This is the item the repair was run against, minus the live ids — nothing
    /// here names a real work item, defect or job, so no assertion below can be
    /// satisfied by hard-coding one.
    Future<_Host> redispatchedAfterOneRecordedFailure() async {
      final host = _Host();
      await host.strandFeature(kSyntheticFeatureItem);
      await host.failJobPermanently(kSyntheticFeatureItem);
      await host.repair.repairWorkItem(kSyntheticFeatureItem);
      await host.redispatch(kSyntheticFeatureItem);
      return host;
    }

    test(
      'two DISTINCT terminal failures produce two transitions, each naming '
      'its OWN job id and JobFailureKind',
      () async {
        // Keyed per work item, the second failure can never be recorded: the
        // first run's row already holds that key. Keyed per failure, it can.
        final host = _Host();
        await host.strandFeature(kSyntheticFeatureItem);
        await host.failJobPermanently(kSyntheticFeatureItem);

        final first = await host.repair.repairWorkItem(
          kSyntheticFeatureItem,
        );
        expect(first.failureRecorded, isTrue);
        expect(first.retried, isTrue);

        // A genuinely different execution: its own job row, its own
        // JobFailureKind, its own reason, a later completion.
        await host.redispatch(kSyntheticFeatureItem);
        await host.failJobPermanently(
          kSyntheticFeatureItem,
          jobId: 'job-transient-2',
          kind: JobFailureKind.transient,
          reason: 'worker lost its lease',
          completedAfter: const Duration(minutes: 9),
        );

        final second = await host.repair.repairWorkItem(
          kSyntheticFeatureItem,
        );
        expect(second.failureRecorded, isTrue);
        expect(second.retried, isTrue);
        expect(second.stateAfter, WorkItemState.designNotRequired.wire);

        // TWO rows, not one — and each carries the job it was actually read
        // from, so a row cannot borrow the other failure's kind.
        final failureRows =
            (await host.workflowStore.readTransitionHistory(
                  kSyntheticFeatureItem,
                ))
                .where(
                  (r) =>
                      r.fromState == WorkItemState.agentExecuting &&
                      r.toState == WorkItemState.agentFailed,
                )
                .toList();
        expect(
          failureRows,
          hasLength(2),
          reason:
              'a second stranded execution is a second real event and needs its '
              'own agentExecuting -> agentFailed row',
        );
        expect(failureRows[0].reason, contains('job-permanent-1'));
        expect(failureRows[0].reason, contains('JobFailureKind.permanent'));
        expect(failureRows[1].reason, contains('job-transient-2'));
        expect(failureRows[1].reason, contains('JobFailureKind.transient'));
        expect(
          failureRows[1].reason,
          isNot(contains('JobFailureKind.permanent')),
          reason:
              'the second row must carry the SECOND job kind, read off its own '
              'durable row, never the first failure kind',
        );

        // The operator ledger grew with it: one retry per failure.
        final actions = await host.workflowStore.readOperatorActionsForWorkItem(
          kSyntheticFeatureItem,
        );
        expect(actions, hasLength(2));
      },
    );

    test(
      'replaying the SAME failure identity changes nothing, byte-level',
      () async {
        // Idempotency keyed on the FAILURE, not the work item: the same job
        // recorded once must not be recorded twice, however often the repair
        // runs.
        final host = await redispatchedAfterOneRecordedFailure();
        final before = await host.workflowStore.readWorkItem(
          kSyntheticFeatureItem,
        );
        expect(before.state, WorkItemState.agentExecuting);

        final historyBefore = await host.workflowStore.readTransitionHistory(
          kSyntheticFeatureItem,
        );
        final actionsBefore = await host.workflowStore
            .readOperatorActionsForWorkItem(kSyntheticFeatureItem);

        final replay = await host.repair.repairWorkItem(
          kSyntheticFeatureItem,
        );
        expect(replay.wroteAnything, isFalse);

        // Nothing was written. A version that did not move is the evidence that
        // no compare-and-swap write happened; identical row LISTS are the
        // evidence that no transition or operator action was appended.
        final after = await host.workflowStore.readWorkItem(
          kSyntheticFeatureItem,
        );
        expect(after.version, before.version);
        expect(after.state, before.state);
        expect(
          await host.workflowStore.readTransitionHistory(kSyntheticFeatureItem),
          historyBefore,
          reason: 'the same failure identity must not record a second row',
        );
        expect(
          await host.workflowStore.readOperatorActionsForWorkItem(
            kSyntheticFeatureItem,
          ),
          actionsBefore,
          reason: 'and must not append a second operator action',
        );

        // A third run must be equally inert.
        await host.repair.repairWorkItem(kSyntheticFeatureItem);
        expect(
          (await host.workflowStore.readWorkItem(
            kSyntheticFeatureItem,
          )).version,
          before.version,
        );
        expect(
          await host.workflowStore.readTransitionHistory(kSyntheticFeatureItem),
          historyBefore,
        );
      },
    );

    test(
      'an ALREADY-RECORDED failure is reported truthfully, instead of '
      'claiming a retry it did not perform',
      () async {
        // The exact shape the Manager hit: a failure row this repair wrote last
        // time is still there, the item was re-dispatched and stranded again,
        // and `operatorRetry` will not move an item sitting at `agentExecuting`.
        final host = await redispatchedAfterOneRecordedFailure();

        // Everything logged so far belongs to the FIRST, genuine repair. Start
        // the replay from a clean marker so the assertions below can only be
        // satisfied by the run under test.
        expect(host.logged('stranded.retried'), isTrue, reason: 'setup');
        host.clearLog();

        final replay = await host.repair.repairWorkItem(
          kSyntheticFeatureItem,
        );

        expect(
          replay.failureRecorded,
          isFalse,
          reason: 'no new agentExecuting -> agentFailed row was written',
        );
        expect(
          replay.retried,
          isFalse,
          reason:
              'this is the false claim under correction: the item did not move, '
              'so nothing was retried',
        );
        expect(replay.retryOutcome, StrandedRetryOutcome.declined);
        expect(
          replay.stateAfter,
          WorkItemState.agentExecuting.wire,
          reason: 'the item is still stranded, and the report must show it',
        );
        expect(
          replay.wroteAnything,
          isFalse,
          reason:
              'N of M item(s) changed counts this field, so a repair that '
              'changed nothing must not report a change',
        );

        // And the rendered output says so in words, not only in a boolean.
        expect(replay.render(), contains('NOT RETRIED'));

        // The LOG carries the same claim, one layer down. It used to print
        // `[stranded.retried]` unconditionally, so a run that moved nothing
        // still asserted it had retried — and a log line is read as a fact
        // rather than as a report, which makes it the more dangerous of the two.
        expect(host.logged('stranded.retry_declined'), isTrue);
        expect(
          host.logged('stranded.retried'),
          isFalse,
          reason: 'nothing was retried, so nothing may say it was',
        );
        expect(
          host.logged('stranded.failure_already_recorded'),
          isTrue,
          reason:
              'and the failure line must not claim a write that did not happen',
        );
        expect(host.logged('stranded.failure_recorded'), isFalse);
      },
    );

    test('the exit status reports an item that was not retried', () async {
      final host = await redispatchedAfterOneRecordedFailure();

      final declined = await host.repair.repairWorkItem(
        kSyntheticFeatureItem,
      );

      expect(
        strandedWorkItemExitCode([declined]),
        isNotNull,
        reason:
            'an item left stranded must not exit 0: the operator reads the '
            'status, not only the prose',
      );
      expect(strandedWorkItemExitCode([declined]), isNot(0));
      expect(declinedRetries([declined]).map((o) => o.workItemId), [
        kSyntheticFeatureItem,
      ]);

      // A repair that DID its work is silent, and an empty run is silent — so
      // this cannot degenerate into always non-zero.
      final worked = _Host();
      await worked.strandFeature(kSyntheticFeatureItem);
      await worked.failJobPermanently(kSyntheticFeatureItem);
      final applied = await worked.repair.repairWorkItem(
        kSyntheticFeatureItem,
      );
      expect(applied.retried, isTrue);
      expect(strandedWorkItemExitCode([applied]), isNull);

      expect(strandedWorkItemExitCode(const []), isNull);
      expect(declinedRetries(const []), isEmpty);
    });

    test('a dry run never claims a retry it did not attempt', () async {
      final host = _Host(dryRun: true);
      await host.strandFeature(kSyntheticFeatureItem);
      await host.failJobPermanently(kSyntheticFeatureItem);

      final outcome = await host.repair.repairWorkItem(
        kSyntheticFeatureItem,
      );

      expect(outcome.retried, isFalse);
      expect(outcome.retryOutcome, isNull, reason: 'no retry was attempted');
      expect(outcome.failureRecorded, isFalse);
      expect(outcome.wroteAnything, isFalse);
      expect(
        strandedWorkItemExitCode([outcome]),
        isNull,
        reason: 'a dry run that did nothing has nothing to report as failed',
      );
    });
  });

  group('design remediation is repaired through lane E\'s own provisioner', () {
    test(
      'drives DesignRemediationWorkItemProvisioner and recovers the item',
      () async {
        final host = _Host();
        final workItemId = designRemediationWorkItemId(kSyntheticDefectId);
        await host.strandFeature(workItemId);
        await host.seedDesignDefect(kSyntheticDefectId);
        await host.failJobPermanently(workItemId);

        final outcome = await host.repair.repairDesignRemediation(
          kSyntheticDefectId,
        );

        // The contract was attached by lane E's replay branch, not by the
        // script's own attach — the action name says which.
        expect(outcome.qaContractAction, startsWith('via-laneE:attached:'));

        // …and the action name is corroborated by something the script cannot
        // fabricate. See 'only the design path runs lane E' below for why this
        // is asserted on the log rather than on the string.
        expect(host.logged('design_remediation.replayed'), isTrue);

        final item = await host.workflowStore.readWorkItem(workItemId);
        expect(item.qaContractId, productQAContractIdForWorkItem(workItemId));
        expect(
          await host.contracts.readQAContract(item.qaContractId!),
          isNotNull,
        );

        // Lane E's `_advanceToPlanned` only acts on `draft`, so the stranded
        // item must NOT have been walked backwards.
        expect(outcome.stateAfter, WorkItemState.designNotRequired.wire);

        final history = await host.workflowStore.readTransitionHistory(
          workItemId,
        );
        expect(
          history.any(
            (r) =>
                r.fromState == WorkItemState.agentExecuting &&
                r.toState == WorkItemState.agentFailed,
          ),
          isTrue,
        );
      },
    );

    test(
      'a contract LANE E attached counts as a change, even with no retry to '
      'take',
      () async {
        // The process summary "N of M item(s) changed" counts `wroteAnything`.
        // Lane E's actions carry a `via-laneE:` prefix because the LANE wrote
        // the row rather than this script, and that prefix names WHO wrote it
        // — it must not change WHETHER anything was written. Read as a prefix
        // rather than as a verb, `via-laneE:attached:` is a contract this run
        // just attached, which the summary would report as no change at all.
        final host = _Host();
        final workItemId = designRemediationWorkItemId(kSyntheticDefectId);
        // Seeded at `planned`, so lane E's `_advanceToPlanned` has nothing to
        // do and the item is NOT stranded: the contract is attached, and there
        // is no stranded execution for the recovery path to recover. That
        // isolates the contract write from every other write in this file.
        await host.strandFeature(workItemId, state: WorkItemState.planned);
        await host.seedDesignDefect(kSyntheticDefectId);

        final outcome = await host.repair.repairDesignRemediation(
          kSyntheticDefectId,
        );

        expect(outcome.qaContractAction, startsWith('via-laneE:attached:'));
        expect(
          host.logged('design_remediation.qa_contract.backfilled'),
          isTrue,
        );
        expect(
          outcome.wroteAnything,
          isTrue,
          reason: 'lane E attached a contract in this run, so it DID change',
        );
        // …and the fields that must NOT be inflated by that one write.
        expect(outcome.retried, isFalse);
        expect(outcome.failureRecorded, isFalse);
        expect(outcome.retryOutcome, isNull);
      },
    );

    test('is idempotent for lane E too', () async {
      final host = _Host();
      final workItemId = designRemediationWorkItemId(kSyntheticDefectId);
      await host.strandFeature(workItemId);
      await host.seedDesignDefect(kSyntheticDefectId);
      await host.failJobPermanently(workItemId);

      await host.repair.repairDesignRemediation(kSyntheticDefectId);
      final afterFirst = await host.workflowStore.readWorkItem(workItemId);
      final writesAfterFirst = host.contracts.writeCounts.values.fold<int>(
        0,
        (a, b) => a + b,
      );

      final second = await host.repair.repairDesignRemediation(
        kSyntheticDefectId,
      );

      final afterSecond = await host.workflowStore.readWorkItem(workItemId);
      expect(afterSecond.version, afterFirst.version);
      expect(afterSecond.state, afterFirst.state);
      expect(
        host.contracts.writeCounts.values.fold<int>(0, (a, b) => a + b),
        writesAfterFirst,
      );
      expect(second.wroteAnything, isFalse);
    });

    // ---------------------------------------------------------------------
    // The design path above asserts `qaContractAction`, which is a STRING THIS
    // SCRIPT COMPUTES. A repair that ignored lane E entirely and attached the
    // contract by its own hand — producing the same row, the same contract id
    // and the same `via-laneE:` prefix — satisfies every one of those
    // assertions. `ensureQAContract` and lane E's `_attachQAContract` really
    // are the same operation, so nothing about the resulting state
    // distinguishes them.
    //
    // What DOES distinguish them is that only lane E logs. These four names are
    // emitted from exactly one file in the repository
    // (`lane_e_design_remediation_work_item.dart`); nothing in `bin/` emits
    // them. Asserting on them makes "driven through lane E's provisioner" an
    // observable fact rather than a label.
    // ---------------------------------------------------------------------
    test(
      'ONLY the design path runs lane E, proven by lane E\'s own log',
      () async {
        // The design path: lane E's "the row already exists" branch ran, and its
        // `_attachQAContract` backfilled the column.
        final design = _Host();
        final remediationId = designRemediationWorkItemId(kSyntheticDefectId);
        await design.strandFeature(remediationId);
        await design.seedDesignDefect(kSyntheticDefectId);
        await design.failJobPermanently(remediationId);

        await design.repair.repairDesignRemediation(kSyntheticDefectId);

        expect(
          design.logged('design_remediation.replayed'),
          isTrue,
          reason:
              'lane_e_design_remediation_work_item.dart:254 logs this from '
              '`ensurePersisted` only. A repair that called `ensureQAContract` '
              'instead cannot emit it, whatever it names the action.',
        );
        expect(
          design.logged('design_remediation.qa_contract.backfilled'),
          isTrue,
          reason:
              'lane_e_design_remediation_work_item.dart:424, inside '
              '`_attachQAContract`.',
        );

        // The generic `--work-item` path must emit NEITHER. This half is what
        // gives the assertion above its meaning: "lane E ran here" is only a
        // claim if "lane E did not run there".
        final generic = _Host();
        await generic.strandFeature(kSyntheticFeatureItem);
        await generic.failJobPermanently(kSyntheticFeatureItem);

        await generic.repair.repairWorkItem(kSyntheticFeatureItem);

        expect(generic.logged('design_remediation.replayed'), isFalse);
        expect(
          generic.logged('design_remediation.qa_contract.backfilled'),
          isFalse,
        );

        // …and the generic run really did accomplish the same repair, so the
        // negative assertions above are not passing merely because nothing
        // happened. The same contract id is reached by two different routes.
        expect(generic.logged('qa_contract.provisioned'), isTrue);
        final repaired = await generic.workflowStore.readWorkItem(
          kSyntheticFeatureItem,
        );
        expect(
          repaired.qaContractId,
          productQAContractIdForWorkItem(kSyntheticFeatureItem),
        );
        expect(
          designRemediationWorkItemId(kSyntheticDefectId),
          isNot(kSyntheticFeatureItem),
          reason: 'the two paths must not be the same id',
        );
      },
    );

    test('REFUSES a defect with no persisted TriageResult', () async {
      // The row exists but nothing was ever triaged for it, so there is no
      // result to replay lane E from. Driving `ensurePersisted` with an
      // invented one would put fiction into the item's own provenance.
      final host = _Host();
      final workItemId = designRemediationWorkItemId(kSyntheticDefectId);
      await host.strandFeature(workItemId);
      await host.seedDesignDefect(kSyntheticDefectId, triageResult: false);
      await host.failJobPermanently(workItemId);

      final outcome = await host.repair.repairDesignRemediation(
        kSyntheticDefectId,
      );

      // The refusal is NAMED, not silent.
      expect(outcome.qaContractAction, 'not-attempted');
      expect(
        outcome.notes.join(' '),
        contains('no persisted TriageResult'),
        reason: 'the refusal must say why the row was left alone',
      );
      expect(outcome.wroteAnything, isFalse);
      expect(outcome.retried, isFalse);

      // Nothing was touched. The stranded item must come out of a refused
      // repair exactly as it went in — a refusal that still attached a contract
      // would be a partial repair nobody asked for.
      expect(host.contracts.rowCount, 0);
      final item = await host.workflowStore.readWorkItem(workItemId);
      expect(item.qaContractId, isNull);
      expect(item.version, 1, reason: 'no CAS write means no version bump');
      expect(item.state, WorkItemState.agentExecuting);
      expect(
        await host.workflowStore.readTransitionHistory(workItemId),
        isEmpty,
      );
      expect(
        await host.workflowStore.readOperatorActionsForWorkItem(workItemId),
        isEmpty,
      );

      // Lane E was never reached — there was nothing to replay it from.
      expect(host.logged('design_remediation.replayed'), isFalse);
    });

    test('REFUSES when the defect resolves to no product at all', () async {
      // `ensurePersisted` returns null for exactly one reason, and the row it
      // would otherwise backfill must survive that refusal untouched.
      final host = _Host();
      final workItemId = designRemediationWorkItemId(kSyntheticDefectId);
      await host.strandFeature(workItemId);
      // The defect points at an EXISTING work item whose product id is blank:
      // `work_item."productId"` is `text NOT NULL`, so a blank string is
      // storable and must be treated as a failure to resolve.
      await host.strandFeature(kBlankProductAnchorItem, productId: '   ');
      await host.seedDesignDefect(
        kSyntheticDefectId,
        affectedWorkItemId: kBlankProductAnchorItem,
      );
      await host.failJobPermanently(workItemId);

      final outcome = await host.repair.repairDesignRemediation(
        kSyntheticDefectId,
      );

      expect(outcome.qaContractAction, 'not-attempted');
      expect(
        outcome.notes.join(' '),
        contains('ensurePersisted returned null'),
        reason: 'the refusal must say the lane declined to create anything',
      );
      expect(outcome.wroteAnything, isFalse);
      expect(outcome.retried, isFalse);

      // Lane E really was driven here, and really was the thing that refused.
      // So this branch is reached by CALLING the provisioner, not by the
      // script's own reasoning — which is what makes it worth a test at all.
      expect(
        host.logged('design_remediation.product_unresolved'),
        isTrue,
        reason: 'lane_e_design_remediation_work_item.dart:242',
      );

      // And it created nothing.
      expect(host.contracts.rowCount, 0);
      final item = await host.workflowStore.readWorkItem(workItemId);
      expect(item.qaContractId, isNull);
      expect(item.version, 1);
      expect(item.state, WorkItemState.agentExecuting);
      expect(
        await host.workflowStore.readTransitionHistory(workItemId),
        isEmpty,
      );
      expect(
        await host.workflowStore.readOperatorActionsForWorkItem(workItemId),
        isEmpty,
      );
    });
  });

  group('the process cannot mutate the database by booting', () {
    test('passes Serverpod no migration flag, and pins the run mode', () {
      final argv = repairServerpodArgv();

      // The single most consequential line in the file. With this absent,
      // `migrateToLatest` (`serverpod.dart:862-879`) never runs, so no
      // pending migration is applied to the QA schema — not even in a dry run.
      expect(
        argv,
        isNot(contains('--apply-migrations')),
        reason: 'a --dry-run rehearsal must not migrate a live database',
      );
      expect(
        argv,
        isNot(contains('--apply-repair-migration')),
        reason: 'the repair-migration flag writes too',
      );

      // Pinned, not inherited: `_calculateRunMode` falls back to
      // SERVERPOD_RUN_MODE (`serverpod.dart:940-965`), so leaving the mode out
      // would let an unrelated environment variable shape this run.
      expect(argv, containsAllInOrder(<String>['--mode', repairRunMode]));

      // Not `development`, which is the only mode whose integrity mismatch is
      // fatal (`serverpod.dart:893-896`). Per decision `6d2bfffe` a
      // chain-migrated QA database can never satisfy that comparison, so in
      // `development` this tool would exit 1 before printing anything.
      expect(repairRunMode, isNot(ServerpodRunMode.development));
    });

    test('never calls Serverpod.start(), so no boot step can write', () {
      // A GUARD, and it is a source inspection rather than a behavioural
      // assertion because the property is unobservable without a live
      // database: everything `Serverpod.start()` does that can write
      // (`migrateToLatest`, `_loadRuntimeSettings`' RuntimeSettings INSERT,
      // the servers, the maintenance tasks) happens before any code in this
      // file runs, so no unit test can observe it happening or not happening.
      //
      // What it does protect is real and falsifiable: putting `await
      // pod.start()` back — for instance to "also run the analyzer
      // preflight" — fails this test here, rather than on the irreplaceable
      // QA database. The substrings are formatting-independent.
      //
      // The pool the session needs is opened by the CONSTRUCTOR on purpose
      // (`serverpod.dart:553-559`), which is why skipping `start()` is sound.
      final code = _withoutComments(_repairScriptSource());

      expect(
        code.contains('start()'),
        isFalse,
        reason:
            '`Serverpod.start()` must never be called: `_loadRuntimeSettings` '
            'INSERTs a RuntimeSettings row on any boot where none exists '
            '(serverpod.dart:728, :900-930), and `--apply-migrations` would '
            'apply pending migrations to the live schema',
      );
      expect(
        code.contains('--apply-migrations'),
        isFalse,
        reason: 'the flag must not reach Serverpod in any form',
      );
    });
  });
}

/// [source] with its `//` comments removed.
///
/// The guard has to inspect CODE, and this file's documentation discusses
/// `Serverpod.start()` and `--apply-migrations` at length precisely BECAUSE
/// they are what it must never call — so a substring search over unstripped
/// text matches the file's own explanation of the rule it enforces, which is
/// how the first version of this guard failed.
///
/// String literals are tracked so that a `//` inside one is not mistaken for a
/// comment. The file contains no block comments, so they are not handled.
String _withoutComments(String source) {
  final buffer = StringBuffer();
  for (final line in source.split('\n')) {
    var inString = false;
    var quote = '';
    var cut = line.length;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (inString) {
        if (ch == quote) inString = false;
        continue;
      }
      if (ch == "'" || ch == '"') {
        inString = true;
        quote = ch;
        continue;
      }
      if (ch == '/' && i + 1 < line.length && line[i + 1] == '/') {
        cut = i;
        break;
      }
    }
    buffer.writeln(line.substring(0, cut));
  }
  return buffer.toString();
}

/// The repair script's own source text.
///
/// Resolved against both plausible working directories so the guard holds
/// whether the suite is run from `apps/server` or from the repository root.
String _repairScriptSource() {
  const candidates = [
    'bin/repair_stranded_work_items.dart',
    'apps/server/bin/repair_stranded_work_items.dart',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError(
    'cannot locate bin/repair_stranded_work_items.dart from '
    '${Directory.current.path}; looked in $candidates',
  );
}

/// Everything the repair needs, wired the way `main` wires it, plus the seams
/// a test needs to set up a stranded row.
class _Host {
  _Host({bool dryRun = false, Set<String> declared = const {kProduct}})
    : workflowStore = InMemoryWorkflowStore(),
      contracts = _CountingQAContractStore(),
      jobStore = InMemoryJobStore() {
    for (final productId in declared) {
      specStore._rows[productId] = _declaration(productId);
    }
    engine = DurableWorkflowEngine(
      store: workflowStore,
      policy: const WorkflowEngine(),
    );
    repair = StrandedWorkItemRepair(
      workflowStore: workflowStore,
      workflowEngine: engine,
      qaContractProvisioner: ProductQAContractProvisioner(
        contractStore: contracts,
        specStore: specStore,
      ),
      jobStore: jobStore,
      defectStore: _hostDefectStore,
      dryRun: dryRun,
      // CAPTURED, not discarded.
      //
      // `StrandedWorkItemOutcome.qaContractAction` is a string this script
      // computes, so an assertion on it is equally satisfied by a repair that
      // never drove lane E at all and attached the contract by its own hand.
      // These events are what make the call observable: the four
      // `design_remediation.*` names are logged from exactly one file in the
      // repository (`lane_e_design_remediation_work_item.dart`), so observing
      // one proves the lane's own code ran.
      log: (event, fields) => logEvents.add(event),
    );
  }

  final InMemoryWorkflowStore workflowStore;
  final _CountingQAContractStore contracts;
  final _SpecStore specStore = _SpecStore();
  final InMemoryJobStore jobStore;

  /// The same engine [repair] drives, exposed so a test can walk the work item
  /// forward through the REAL transition table instead of stamping a state.
  late final DurableWorkflowEngine engine;

  late final StrandedWorkItemRepair repair;

  /// Every event handed to the repair's `log`, in order.
  final List<String> logEvents = [];

  /// True when [event] was logged by this host.
  bool logged(String event) => logEvents.contains(event);

  /// Drops everything logged so far.
  ///
  /// A single `_Host` runs the whole scenario — first repair, re-dispatch,
  /// replay — so "this host logged `stranded.retried`" is true of the FIRST,
  /// genuine retry as well as of the replay. Assertions about what ONE run
  /// reported have to start from a marker, or they pass for the wrong run.
  void clearLog() => logEvents.clear();

  String? permanentJobId;

  /// Writes a row in exactly the shape the live database has: `agentExecuting`,
  /// `qaContractId` NULL. The repair's work starts from there, so the setup
  /// only has to be faithful at the START; every transition after it is real
  /// graph travel through [DurableWorkflowEngine].
  Future<void> strandFeature(
    String workItemId, {
    String productId = kProduct,
    WorkItemState state = WorkItemState.agentExecuting,
  }) async {
    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: workItemId,
        productId: productId,
        category: WorkItemCategory.feature,
        title: 'Stranded feature request',
        description:
            'A feature request that was dispatched without a QA '
            'contract and refused at completion.',
        state: state,
        featureRef: workItemId,
        createdAt: kNow,
        updatedAt: kNow,
      ),
    );
  }

  /// The durable failure the repair must READ rather than compose: one terminal
  /// job carrying a `permanent` [JobFailure] with a real reason.
  ///
  /// [jobId], [kind] and [completedAfter] exist so a test can create a SECOND,
  /// DISTINCT failure on the same work item — the shape F-92 is about, where
  /// one `agentExecuting -> agentFailed` row already exists and the repair still
  /// has to record the next execution's failure. A second failure that reused
  /// the first one's id would not be a second failure at all, so it is not
  /// defaulted.
  Future<void> failJobPermanently(
    String workItemId, {
    String reason = 'platform verification failed',
    String jobId = 'job-permanent-1',
    JobFailureKind kind = JobFailureKind.permanent,
    Duration completedAfter = const Duration(minutes: 3),
  }) async {
    permanentJobId = jobId;
    await jobStore.saveJob(
      Job(
        jobId: permanentJobId!,
        workItemId: workItemId,
        jobType: JobType.triageDefect,
        requiredRole: AgentRole.triageDefect,
        requiredCapabilities: const {},
        priority: JobPriority.normal,
        state: JobState.failed,
        dedupeKey: '$workItemId:triage:$jobId',
        createdAt: kNow,
        completedAt: kNow.add(completedAfter),
        instruction: 'Triage the defect.',
        attempt: 1,
        maxAttempts: 3,
        version: 1,
        failure: JobFailure(
          code: JobFailureCode.executionFailed,
          kind: kind,
          reason: reason,
        ),
      ),
    );
  }

  /// The ordinary scheduler re-dispatch, walked through the real transition
  /// table.
  ///
  /// The repair's whole purpose is to land the item back on `designNotRequired`
  /// so the scheduler picks it up again. Reproducing that pick-up is what makes
  /// a SECOND stranded execution reachable in a test, and doing it through
  /// [engine] rather than by stamping `agentExecuting` onto the row is what
  /// keeps the second failure a real one: the guards
  /// (`actorAllowed`, `agentAvailable`) are satisfied by the context the
  /// dispatch actually supplies, not by a test asserting a state into existence.
  Future<WorkItem> redispatch(String workItemId) => engine.transition(
    workItemId: workItemId,
    to: WorkItemState.agentExecuting,
    trigger: TransitionTrigger.systemEvent,
    actor: repairActor,
    context: {'agentAvailable': true, 'capabilitiesMatch': true},
    reason: 'scheduler re-dispatch of the retried item',
  );

  /// A defect plus the settled triage result lane E replays from. The defect
  /// names the remediation item as the affected work item, which is how its
  /// product resolves — `affectedWorkItemId -> work_item.productId`.
  ///
  /// [affectedWorkItemId] is overridable so a test can point the defect at a
  /// different row; [triageResult] is nullable so the no-`TriageResult` refusal
  /// can be set up.
  Future<void> seedDesignDefect(
    String defectId, {
    String? affectedWorkItemId,
    bool triageResult = true,
  }) async {
    final remediationId = designRemediationWorkItemId(defectId);
    _hostDefectStore.defects[defectId] = Defect(
      defectId: defectId,
      title: 'Report layout clips the action row',
      description: 'The action row is cut off at narrow widths.',
      severity: 'medium',
      status: DefectStatus.remediationPlanned,
      classification: DefectClassification.designDefect,
      reporter: 'someone@example.test',
      affectedWorkItemId: affectedWorkItemId ?? remediationId,
      createdAt: kNow,
      updatedAt: kNow,
      version: 1,
    );
    if (!triageResult) return;
    _hostDefectStore.results[defectId] = [
      TriageResult(
        resultId: 'tr-$defectId-1',
        defectId: defectId,
        summary: 'Layout defect in the report action row.',
        recommendedStatus: DefectStatus.remediationPlanned,
        recommendedClassification: DefectClassification.designDefect,
        recommendedNextAction: 'Open design remediation for the report layout.',
        confidence: 0.82,
        suspectedCategory: 'ui-layout',
        suspectedComponents: const ['ReportScreen'],
        reproductionSupported: true,
        evidenceUsed: const ['EVD-1'],
        clarificationRequired: const [],
        createdAt: kNow,
        version: 1,
      ),
    ];
  }

  /// The single [DefectStore] the repair is wired to. Seeded through
  /// [_Host.seedDesignDefect].
  final _FakeDefectStore _hostDefectStore = _FakeDefectStore();
}

/// A [DefectStore] with only the two reads on the repair path implemented.
///
/// The rest throw rather than returning a plausible empty answer, so a future
/// addition to the repair that reaches for another method fails loudly instead
/// of quietly classifying nothing.
class _FakeDefectStore implements DefectStore {
  final Map<String, Defect> defects = {};
  final Map<String, List<TriageResult>> results = {};

  @override
  Future<Defect> readDefect(String defectId) async {
    final defect = defects[defectId];
    if (defect == null) throw StateError('no defect $defectId');
    return defect;
  }

  @override
  Future<List<TriageResult>> readTriageResultsForDefect(
    String defectId,
  ) async => results[defectId] ?? const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'DefectStore.${invocation.memberName} is not on the repair path',
  );
}

/// A [ProductQAContractSpecStore] over a plain map, holding ONLY the products a
/// test declared — so "this product declared nothing" is genuinely absent
/// rather than an empty-but-present declaration.
class _SpecStore implements ProductQAContractSpecStore {
  final Map<String, ProductQAContractDeclaration> _rows = {};

  @override
  Future<void> saveQAContractSpec(
    ProductQAContractDeclaration declaration,
  ) async {
    _rows[declaration.productId] = declaration;
  }

  @override
  Future<ProductQAContractDeclaration?> readQAContractSpec(
    String productId,
  ) async => _rows[productId];
}

ProductQAContractDeclaration _declaration(String productId) =>
    ProductQAContractDeclaration(
      productId: productId,
      gates: const [
        QAGateSpec(
          gateId: 'intake-structured-result-admitted',
          type: 'triage-classification-structure',
          required: true,
          config: {
            'sourceColumn': 'agent_result.structuredResultJson',
            'requiredFields': [
              'classification',
              'status',
              'confidence',
              'suspectedCategory',
            ],
          },
        ),
      ],
      manifestVersion: '1.0.0',
      createdAt: kNow,
      updatedAt: kNow,
    );

/// A [QAContractStore] keyed the way PostgreSQL is — a second write REPLACES a
/// row — and it COUNTS writes, because "the second run wrote nothing" is an
/// assertion about this counter and nothing else can establish it.
class _CountingQAContractStore implements QAContractStore {
  final Map<String, QAContract> _rows = <String, QAContract>{};
  final Map<String, int> writeCounts = <String, int>{};

  int get rowCount => _rows.length;

  @override
  Future<void> saveQAContract(QAContract contract) async {
    writeCounts.update(contract.contractId, (c) => c + 1, ifAbsent: () => 1);
    _rows[contract.contractId] = contract;
  }

  @override
  Future<QAContract> provisionQAContract(QAContract contract) async {
    await saveQAContract(contract);
    final stored = await readQAContract(contract.contractId);
    if (stored == null) throw StateError('unreadable after write');
    return stored;
  }

  @override
  Future<QAContract?> readQAContract(String contractId) async =>
      _rows[contractId];

  @override
  Future<bool> hasQAContract(String contractId) async =>
      _rows.containsKey(contractId);

  @override
  Future<List<QAContract>> listQAContractsForWorkItem(
    String workItemId,
  ) async => _rows.values
      .where((c) => c.metadata?[qaContractWorkItemIdMetadataKey] == workItemId)
      .toList();

  @override
  Future<List<QAContract>> listQAContractsByCategory(
    WorkItemCategory category,
  ) async => _rows.values.where((c) => c.workItemCategory == category).toList();
}
