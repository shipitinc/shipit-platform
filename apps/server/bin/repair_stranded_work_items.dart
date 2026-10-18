/// One-shot, reviewed repair for work items stranded mid-execution with a NULL
/// `qaContractId`.
///
/// Run it against the control-plane database:
///
///   SERVERPOD_DATABASE_HOST=postgres \
///   dart run bin/repair_stranded_work_items.dart --dry-run \
///     --work-item WI-feature-… --defect DEF-…
///
/// ## WHAT THIS IS, AND WHY IT IS A SCRIPT
///
/// A work item dispatched without a QA contract runs a real agent and is then
/// refused at `agentExecuting -> agentCompleted`, because
/// `GuardConditions.qaContractExists()` null-checks `context['qaContractId']`.
/// `ExecutionCoordinator._completeSuccess` is the ONLY writer of that edge and
/// it only runs at the end of a LIVE execution, so a settled execution can
/// never be replayed into a completion. The items stranded that way are
/// therefore not recoverable by any operator verb: `scheduler_endpoints.dart`
/// exposes only `listJobs`/`inspect`, and `work_item_action_endpoints.dart`
/// exposes `operatorRetry`, which REFUSES from `agentExecuting`.
///
/// So the recovery has to be code that drives the product's own paths. It is a
/// script rather than an endpoint because a permanent public verb for a
/// one-time repair is a larger and more durable surface than an auditable file
/// a human runs deliberately, and because the repair must be removable with
/// this one commit.
///
/// ## NOTHING HERE IS SQL, AND NOTHING HERE IS INVENTED
///
/// Every write goes through a product-owned code path:
///
///  * the QA contract is built by `ProductQAContractProvisioner` from the
///    PRODUCT's declared spec, persisted, and READ BACK before its id is
///    stamped — so `qaContractId` can only ever name a row that exists;
///  * the `qaContractId` itself lands through `WorkflowStore.saveWorkItem`
///    with an `expectedVersion` compare-and-swap;
///  * both state changes go through `DurableWorkflowEngine`, so
///    `workflow_engine`'s transition table stays the only authority
///    (AGENTS.md §1);
///  * the retry goes through `DurableWorkflowEngine.operatorRetry`.
///
/// The failure this repair records is READ from the durable `job` row, not
/// written from a literal. An item with no terminal failed job is REFUSED,
/// because a fabricated reason on a transition row is worse than no row.
///
/// ## TWO ENTRY POINTS, EACH USING ITS OWNING LANE'S PROVISIONER
///
/// [StrandedWorkItemRepair.repairDesignRemediation] drives
/// `DesignRemediationWorkItemProvisioner.ensurePersisted`, which reads the
/// existing `design-remediation-{defectId}` row and backfills the contract
/// through its own `_attachQAContract`. That branch is already replay-safe and
/// only acts when the column is null.
///
/// [StrandedWorkItemRepair.repairWorkItem] is the feature side, where no such
/// provisioner exists at all: `createFeatureWorkItem` provisions a contract on
/// CREATE and nothing anywhere attaches one to an EXISTING feature work item.
/// It is parameterised by work item id and works for any stranded item of any
/// category. See [StrandedWorkItemRepair.ensureQAContract] for why this lives
/// in `bin/` rather than beside `createFeatureWorkItem`.
library;

import 'dart:io';

import 'package:control_plane_server/src/generated/endpoints.dart';
import 'package:control_plane_server/src/generated/protocol.dart';
import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_defect_store.dart';
import 'package:control_plane_server/src/persistence/postgres_job_store.dart';
import 'package:control_plane_server/src/persistence/postgres_product_qa_contract_spec_store.dart';
import 'package:control_plane_server/src/persistence/postgres_qa_contract_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:control_plane_server/src/triage/lane_e_design_remediation_work_item.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart' show DefectStore;
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:scheduler/scheduler.dart';
import 'package:serverpod/serverpod.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';

/// Actor the repair records its transitions under.
///
/// `actorAllowed([ActorType.orchestrator])` is the guard on BOTH edges this
/// repair walks — `agentExecuting -> agentFailed` and `agentFailed ->
/// designNotRequired`, which `operatorRetry` takes — so an orchestrator actor is
/// required, not cosmetic. The id names the script so the row says which tool
/// moved it, which is the whole point of an auditable repair.
const WorkflowActor repairActor = WorkflowActor(
  actorId: 'repair-stranded-work-items',
  actorType: ActorType.orchestrator,
);

/// `requestedBy` recorded on the operator action row.
const String repairRequestedBy = 'repair-stranded-work-items';

/// What happened to one work item.
///
/// Reported per item and never swallowed: a repair that exits silently is
/// indistinguishable from a repair that did nothing.
class StrandedWorkItemOutcome {
  StrandedWorkItemOutcome({
    required this.workItemId,
    required this.stateBefore,
    required this.stateAfter,
    required this.wroteAnything,
    required this.notes,
    this.qaContractId,
    this.qaContractAction,
    this.failureReason,
    this.retried = false,
  });

  final String workItemId;
  final String stateBefore;
  final String stateAfter;

  /// False when the item already carried a contract and was not at
  /// `agentExecuting` — the shape a second run of this script takes.
  final bool wroteAnything;

  /// The contract id now on the row, or null when none was written.
  final String? qaContractId;

  /// `already-present`, `attached`, `would-attach`, or `refused:<reason>`.
  final String? qaContractAction;

  /// The failure reason recorded on the `agentExecuting -> agentFailed` row,
  /// derived from the durable job row. Null when no failure was recorded.
  final String? failureReason;

  final bool retried;

  final List<String> notes;

  /// One block of human-readable output. Prints what it did, per item.
  String render() {
    final buffer = StringBuffer()
      ..writeln('work item  : $workItemId')
      ..writeln('  state   : $stateBefore -> $stateAfter')
      ..writeln('  contract: ${qaContractAction ?? 'not examined'}')
      ..writeln('  qaContractId: ${qaContractId ?? 'NULL'}');
    if (failureReason != null) {
      buffer.writeln('  failure : $failureReason');
      buffer.writeln('  retried : $retried');
    }
    for (final note in notes) {
      buffer.writeln('  note    : $note');
    }
    buffer.writeln('  wrote   : $wroteAnything');
    return buffer.toString();
  }
}

/// Repairs work items stranded at `agentExecuting` with no QA contract.
///
/// See the library doc comment for why this is a script and what it refuses to
/// do. The class is separate from `main` so the behaviour it encodes is
/// reachable from a test, which is the only reason a repair can be shown to be
/// non-vacuous.
class StrandedWorkItemRepair {
  StrandedWorkItemRepair({
    required this.workflowStore,
    required this.workflowEngine,
    required this.qaContractProvisioner,
    required this.jobStore,
    required this.defectStore,
    this.dryRun = false,
    void Function(String event, Map<String, Object?> fields)? log,
  }) : _log = log ?? _defaultLog;

  final WorkflowStore workflowStore;
  final DurableWorkflowEngine workflowEngine;
  final ProductQAContractProvisioner qaContractProvisioner;
  final JobStore jobStore;
  final DefectStore defectStore;

  /// When true, every method reports what it WOULD write and writes nothing —
  /// including the QA contract, which is a row of its own and not merely a
  /// column on the work item.
  final bool dryRun;

  final void Function(String event, Map<String, Object?> fields) _log;

  static void _defaultLog(String event, Map<String, Object?> fields) {
    stdout.writeln('[repair] $event ${fields.isEmpty ? '' : fields}');
  }

  /// Attaches a QA contract to an EXISTING work item that carries none.
  ///
  /// This is the capability that does not exist anywhere in the product: lane E
  /// has a private `_attachQAContract`, and `createFeatureWorkItem` provisions a
  /// contract only on CREATE. It is written the same way lane E writes it —
  /// provision from the product's declared spec, stamp only when the column is
  /// actually null, write through the compare-and-swap path, then read back and
  /// confirm — so a replay is a read and two concurrent repairs cannot both
  /// win.
  ///
  /// ## Why this is not a method on the feature path
  ///
  /// The home this logic belongs in is `ControlPlaneService`, beside
  /// `createFeatureWorkItem`'s own `_provisionFeatureQAContract`, so that the
  /// backfill and the create-time provisioning cannot drift apart. That file is
  /// outside this correction's declared ownership, so it is reported as a
  /// finding rather than edited. What is here is deliberately built on the SAME
  /// provisioner the create path uses, so moving it is a move, not a rewrite.
  Future<(WorkItem, String)> ensureQAContract(WorkItem item) async {
    if (item.qaContractId != null) {
      return (item, 'already-present:${item.qaContractId}');
    }

    if (dryRun) {
      // `productQAContractIdForWorkItem` is a pure function of the work item
      // id, so the id this would write is computable without writing the row.
      final addressed = productQAContractIdForWorkItem(item.workItemId);
      return (item, 'would-attach:$addressed');
    }

    try {
      final contract = await qaContractProvisioner.provisionForWorkItem(
        productId: item.productId,
        workItemCategory: item.category,
        workItemId: item.workItemId,
        // Read out of the row rather than taken from the clock, so repeated
        // attempts write the same bytes and the second run is a genuine no-op.
        now: item.createdAt.toUtc(),
      );
      _log('qa_contract.provisioned', {
        'workItemId': item.workItemId,
        'productId': item.productId,
        'contractId': contract.contractId,
        'gates': contract.gates.length,
      });

      await workflowStore.saveWorkItem(
        item.copyWith(qaContractId: contract.contractId),
        expectedVersion: item.version,
      );
      final updated = await workflowStore.readWorkItem(item.workItemId);
      if (updated.qaContractId != contract.contractId) {
        throw StateError(
          'work item ${item.workItemId} did not retain the QA contract id '
          '${contract.contractId} after the CAS write',
        );
      }
      return (updated, 'attached:${contract.contractId}');
    } on ProductQAContractSpecUnavailable catch (refusal) {
      // Not an error and not swallowed: the named refusal is returned so the
      // operator sees WHY the item cannot complete, on the item's own row.
      _log('qa_contract.refused', {
        'workItemId': item.workItemId,
        'productId': item.productId,
        'refusal': refusal.refusal.name,
      });
      return (item, 'refused:${refusal.refusal.name}');
    }
  }

  /// Repairs one work item addressed directly by id.
  ///
  /// This is the feature path, and it is parameterised by the id it is handed:
  /// nothing here is shaped to any particular work item, and no id is compiled
  /// in.
  Future<StrandedWorkItemOutcome> repairWorkItem(String workItemId) async {
    final before = await workflowStore.readWorkItem(workItemId);
    final (item, contractAction) = await ensureQAContract(before);
    return _recoverStrandedExecution(before, item, contractAction);
  }

  /// Repairs the design remediation item for [defectId].
  ///
  /// Drives [DesignRemediationWorkItemProvisioner.ensurePersisted] with the
  /// real [Defect] and [TriageResult] read back from the store, so the contract
  /// is attached by the lane's OWN provisioner on its replay branch rather than
  /// by this script. [DesignRemediationWorkItemProvisioner.ensurePersisted]
  /// reads the existing `design-remediation-{defectId}` row first and only
  /// attaches when the column is null, so this is idempotent and cannot
  /// re-create the item.
  Future<StrandedWorkItemOutcome> repairDesignRemediation(
    String defectId,
  ) async {
    final workItemId = designRemediationWorkItemId(defectId);
    final before = await workflowStore.readWorkItem(workItemId);

    if (dryRun) {
      // `ensurePersisted` provisions a QA contract row and may transition, so
      // it is not called at all in a dry run. What it would do to THIS row is
      // exactly what `ensureQAContract` reports, because the lane's
      // `_attachQAContract` and that method are the same operation.
      final (_, contractAction) = await ensureQAContract(before);
      return _recoverStrandedExecution(
        before,
        before,
        'via-laneE:$contractAction',
      );
    }

    final defect = await defectStore.readDefect(defectId);
    final results = await defectStore.readTriageResultsForDefect(defectId);
    if (results.isEmpty) {
      return StrandedWorkItemOutcome(
        workItemId: workItemId,
        stateBefore: before.state.wire,
        stateAfter: before.state.wire,
        wroteAnything: false,
        qaContractId: before.qaContractId,
        qaContractAction: 'not-attempted',
        notes: [
          'defect $defectId has no persisted TriageResult, so lane E '
              'ensurePersisted cannot be replayed. The row was left untouched '
              'rather than driven with a fabricated result.',
        ],
      );
    }
    // The lane reads one result. Picking the newest is the same "settled last"
    // order the triage processor writes them in.
    final sorted = [...results]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final triageResult = sorted.last;

    final item = await DesignRemediationWorkItemProvisioner(
      workflowStore: workflowStore,
      workflowEngine: workflowEngine,
      qaContractProvisioner: qaContractProvisioner,
      log: _log,
    ).ensurePersisted(triageResult: triageResult, defect: defect);

    // `ensurePersisted` returns null for exactly one reason: the defect resolves
    // to no product at all, and it logs `design_remediation.product_unresolved`.
    // It creates nothing in that case, so there is nothing to recover and the
    // item is reported untouched rather than driven with a guess.
    if (item == null) {
      return StrandedWorkItemOutcome(
        workItemId: workItemId,
        stateBefore: before.state.wire,
        stateAfter: before.state.wire,
        wroteAnything: false,
        qaContractId: before.qaContractId,
        qaContractAction: 'not-attempted',
        notes: [
          'lane E ensurePersisted returned null: the defect resolves to no '
              'product, so it created nothing. The row was left untouched.',
        ],
      );
    }

    final action = item.qaContractId == null
        ? 'via-laneE:refused-or-absent'
        : (before.qaContractId == null
              ? 'via-laneE:attached:${item.qaContractId}'
              : 'via-laneE:already-present:${item.qaContractId}');

    return _recoverStrandedExecution(before, item, action);
  }

  /// Records the truthful failure and retries, when the item is stranded.
  ///
  /// Shared by both entry points so the recovery sequence exists once.
  Future<StrandedWorkItemOutcome> _recoverStrandedExecution(
    WorkItem before,
    WorkItem item,
    String contractAction,
  ) async {
    final notes = <String>[];
    var wroteAnything = contractAction.startsWith('attached');

    if (item.state != WorkItemState.agentExecuting) {
      notes.add(
        'item is at ${item.state.wire}, not agentExecuting: it was not '
        'stranded mid-execution, so no failure was recorded and no retry '
        'was taken.',
      );
      return StrandedWorkItemOutcome(
        workItemId: item.workItemId,
        stateBefore: before.state.wire,
        stateAfter: item.state.wire,
        wroteAnything: wroteAnything,
        qaContractId: item.qaContractId,
        qaContractAction: contractAction,
        notes: notes,
      );
    }

    // The failure is READ, never composed from a literal. An item with no
    // terminal failed job is refused rather than given an invented reason.
    final failedJob = await _terminalFailedJob(item.workItemId);
    if (failedJob == null) {
      notes.add(
        'REFUSED: no terminal job carrying a durable failure was found for '
        'this item, so no agentExecuting -> agentFailed row was written. A '
        'reason invented here would be a false record of why an execution '
        'stopped. The contract above is unaffected.',
      );
      return StrandedWorkItemOutcome(
        workItemId: item.workItemId,
        stateBefore: before.state.wire,
        stateAfter: item.state.wire,
        wroteAnything: wroteAnything,
        qaContractId: item.qaContractId,
        qaContractAction: contractAction,
        notes: notes,
      );
    }

    final failure = failedJob.failure!;
    final reason =
        'execution ${failedJob.jobId} (${failedJob.jobType.wire}) settled '
        '${failedJob.state.wire} with JobFailureKind.${failure.kind.name}'
        '${failure.reason == null ? '' : ': ${failure.reason}'}';

    if (dryRun) {
      notes.add(
        'would record agentExecuting -> agentFailed with the durable reason '
        'read from job ${failedJob.jobId}, then operatorRetry -> '
        'designNotRequired.',
      );
      return StrandedWorkItemOutcome(
        workItemId: item.workItemId,
        stateBefore: before.state.wire,
        stateAfter: item.state.wire,
        wroteAnything: false,
        qaContractId: item.qaContractId,
        qaContractAction: contractAction,
        failureReason: reason,
        notes: notes,
      );
    }

    // `agentExecuting -> agentFailed` carries `actorAllowed([orchestrator])`
    // alone; it is legal and needs no evidence, because the evidence IS this
    // job row and it is named in the persisted reason. The result is not
    // captured: the retry below re-reads the item, and holding a second copy
    // here would be a second thing to go stale.
    await workflowEngine.transition(
      workItemId: item.workItemId,
      to: WorkItemState.agentFailed,
      trigger: TransitionTrigger.agentResult,
      actor: repairActor,
      context: {
        'repair': 'stranded-work-items',
        'jobId': failedJob.jobId,
        'failureKind': failure.kind.name,
      },
      // The engine's `reason` is the field PERSISTED on the transition record.
      reason: reason,
      idempotencyKey: 'repair-stranded:${item.workItemId}:agentFailed',
    );
    _log('stranded.failure_recorded', {
      'workItemId': item.workItemId,
      'jobId': failedJob.jobId,
      'kind': failure.kind.name,
    });

    // `operatorRetry` is the sanctioned operator verb and it takes
    // `agentFailed -> designNotRequired`, an entry state of
    // `triageDefectDefinition`, so the ordinary scheduler tick re-dispatches
    // with no change to any dispatch path. The requestId is derived from the
    // durable job id, so a replay of the same operator intent finds its own
    // audit row and writes nothing.
    final retried = await workflowEngine.operatorRetry(
      workItemId: item.workItemId,
      requestedBy: repairRequestedBy,
      reason: reason,
      requestId: 'repair-stranded:${item.workItemId}:${failedJob.jobId}',
      idempotencyKey: 'repair-stranded:${item.workItemId}:operatorRetry',
    );
    _log('stranded.retried', {
      'workItemId': item.workItemId,
      'state': retried.state.wire,
    });

    notes.add(
      're-dispatch is the ordinary scheduler tick: designNotRequired is an '
      'entry state of triageDefectDefinition.',
    );

    return StrandedWorkItemOutcome(
      workItemId: item.workItemId,
      stateBefore: before.state.wire,
      stateAfter: retried.state.wire,
      wroteAnything: true,
      qaContractId: retried.qaContractId,
      qaContractAction: contractAction,
      failureReason: reason,
      retried: true,
      notes: notes,
    );
  }

  /// The terminal failed job for [workItemId], newest first, or null.
  ///
  /// "Terminal with a failure" is what the durable record asserts, so that is
  /// what is looked for: a job that is still `queued`/`running` is not a record
  /// of anything having stopped.
  Future<Job?> _terminalFailedJob(String workItemId) async {
    final jobs = await jobStore.listJobsForWorkItem(workItemId);
    final failed = jobs.where((j) => j.isTerminal && j.failure != null).toList()
      ..sort((a, b) {
        final at = a.completedAt ?? a.createdAt;
        final bt = b.completedAt ?? b.createdAt;
        return bt.compareTo(at);
      });
    return failed.isEmpty ? null : failed.first;
  }
}

String _env(String key, String fallback) {
  final value = Platform.environment[key];
  return (value == null || value.isEmpty) ? fallback : value;
}

void _usage() {
  stdout.writeln('''
Usage: dart run bin/repair_stranded_work_items.dart [options]

  --work-item <id>   repair this work item directly (the feature path).
  --defect <id>      repair design-remediation-<id> through lane E's own
                     DesignRemediationWorkItemProvisioner.
  --dry-run          report every intended change and write nothing.
  --help             print this.

Both options may be repeated, and may be combined. Connection details come from
the environment: SERVERPOD_DATABASE_HOST, _PORT, _NAME, _USER, _PASSWORD.
''');
}

/// Parsed command line. No work item id is defaulted: a repair that guessed an
/// id would be operating on a row nobody chose.
class _Args {
  _Args(this.workItemIds, this.defectIds, this.dryRun, this.help);

  factory _Args.parse(List<String> argv) {
    final workItemIds = <String>[];
    final defectIds = <String>[];
    var dryRun = false;
    var help = false;
    for (var i = 0; i < argv.length; i++) {
      final arg = argv[i];
      String next(String name) {
        if (i + 1 >= argv.length) {
          stderr.writeln('$name requires a value');
          exit(2);
        }
        return argv[++i];
      }

      switch (arg) {
        case '--work-item':
          workItemIds.add(next('--work-item'));
        case '--defect':
          defectIds.add(next('--defect'));
        case '--dry-run':
          dryRun = true;
        case '--help' || '-h':
          help = true;
        default:
          stderr.writeln('unknown argument: $arg');
          _usage();
          exit(2);
      }
    }
    return _Args(workItemIds, defectIds, dryRun, help);
  }

  final List<String> workItemIds;
  final List<String> defectIds;
  final bool dryRun;
  final bool help;
}

Future<void> main(List<String> argv) async {
  final args = _Args.parse(argv);
  if (args.help) {
    _usage();
    return;
  }
  if (args.workItemIds.isEmpty && args.defectIds.isEmpty) {
    stderr.writeln(
      'Refusing to run: no --work-item and no --defect. This repair acts only '
      'on ids a human names on the command line.',
    );
    _usage();
    exit(2);
  }

  final database = DatabaseConfig(
    host: _env('SERVERPOD_DATABASE_HOST', 'localhost'),
    port: int.parse(_env('SERVERPOD_DATABASE_PORT', '5432')),
    name: _env('SERVERPOD_DATABASE_NAME', 'shipit'),
    user: _env('SERVERPOD_DATABASE_USER', 'shipit'),
    password: _env('SERVERPOD_DATABASE_PASSWORD', 'shipit'),
  );

  stdout.writeln('Repairing stranded work items');
  stdout.writeln(
    '  database   : ${database.host}:${database.port}/${database.name}',
  );
  stdout.writeln('  dry run    : ${args.dryRun}');

  final pod = Serverpod(
    ['--mode', 'development', '--apply-migrations'],
    Protocol(),
    Endpoints(),
    configOverride: (config) => config.copyWith(
      database: database,
      redis: null,
      webServer: null,
      insightsServer: null,
    ),
  );
  await pod.start();

  try {
    final session = await Serverpod.instance.createSession(
      enableLogging: false,
    );
    final db = PersistenceDatabase(session.db);
    final workflowStore = PostgresWorkflowStore(db);
    final repair = StrandedWorkItemRepair(
      workflowStore: workflowStore,
      workflowEngine: DurableWorkflowEngine(
        store: workflowStore,
        policy: const WorkflowEngine(),
      ),
      // The same two stores `TriageProcessor` builds lane E's provisioner
      // from, so the contract this writes is the product's own.
      qaContractProvisioner: ProductQAContractProvisioner(
        contractStore: PostgresQAContractStore(db),
        specStore: PostgresProductQAContractSpecStore(db),
      ),
      jobStore: PostgresJobStore(db),
      defectStore: PostgresDefectStore(db),
      dryRun: args.dryRun,
      log: (event, fields) => stdout.writeln('[$event] ${jsonSafe(fields)}'),
    );

    var changed = 0;
    var failedItems = 0;
    final total = args.defectIds.length + args.workItemIds.length;
    for (final defectId in args.defectIds) {
      stdout.writeln('\n--- design remediation for defect $defectId ---');
      final outcome = await _guard(
        () => repair.repairDesignRemediation(defectId),
        'design remediation $defectId',
        () => failedItems++,
      );
      if (outcome == null) continue;
      stdout.writeln(outcome.render());
      if (outcome.wroteAnything) changed++;
    }
    for (final workItemId in args.workItemIds) {
      stdout.writeln('\n--- work item $workItemId ---');
      final outcome = await _guard(
        () => repair.repairWorkItem(workItemId),
        'work item $workItemId',
        () => failedItems++,
      );
      if (outcome == null) continue;
      stdout.writeln(outcome.render());
      if (outcome.wroteAnything) changed++;
    }

    stdout.writeln(
      '\n$changed of $total item(s) changed.'
      '${args.dryRun ? ' (dry run — nothing was written)' : ''}',
    );
    if (failedItems > 0) {
      // Non-zero: the operator must not read a summary line that looks like
      // success over a run where one item was refused.
      stderr.writeln('$failedItems item(s) could not be repaired; see above.');
      await pod.shutdown(exitProcess: false);
      exit(1);
    }
  } finally {
    await pod.shutdown(exitProcess: false);
  }
}

/// Runs one repair, turning a refusal into a reported outcome rather than an
/// aborted run.
///
/// A single refused item must not hide the other items' results, and an aborted
/// run reports nothing at all — which is the silence this script exists to
/// avoid. The error is printed with its own type, never collapsed into a
/// generic message.
Future<StrandedWorkItemOutcome?> _guard(
  Future<StrandedWorkItemOutcome> Function() body,
  String what,
  void Function() onFailure,
) async {
  try {
    return await body();
  } catch (error, stack) {
    onFailure();
    stderr.writeln('\nFAILED: $what');
    stderr.writeln('  ${error.runtimeType}: $error');
    stderr.writeln(
      '  Nothing further was attempted for this item. Its durable row is '
      'unchanged by this failure.',
    );
    if (error is Error) stderr.writeln('  $stack');
    return null;
  }
}

/// Renders log fields without dragging `dart:convert` into every call site.
String jsonSafe(Map<String, Object?> fields) =>
    fields.entries.map((e) => '${e.key}=${e.value}').join(' ');
