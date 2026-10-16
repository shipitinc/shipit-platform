import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/database.dart';
import 'package:workflow_store/workflow_store.dart';

import 'persistence_database.dart';

import 'util/db_row_util.dart';

/// Receives one event per JSON column that did not hold the shape it is
/// declared to hold.
///
/// Signature matches the repository's existing operator-log convention
/// (`[$event] $fields`) so a line from the persistence layer is greppable
/// beside the lines `server.dart` and `StructuredLogger` already emit.
typedef JsonArrayDefectReporter =
    void Function(String event, Map<String, Object?> fields);

/// PostgreSQL implementation of [WorkflowStore].
///
/// Primary work item fields are persisted as real columns; only nested
/// structures (artifact references, metadata, decision context, options,
/// signature, guard evaluations) are stored as JSON documents.
class PostgresWorkflowStore implements WorkflowStore {
  PostgresWorkflowStore(
    this._db, {
    JsonArrayDefectReporter? reportJsonArrayDefect,
  }) : _reportJsonArrayDefect = reportJsonArrayDefect ?? _stdoutJsonArrayDefect;

  final PersistenceDatabase _db;
  final JsonArrayDefectReporter _reportJsonArrayDefect;

  /// How much of an offending column is quoted back in the operator log.
  ///
  /// The repair metadata that lands in `guardEvaluationsJson` is a few hundred
  /// bytes; the cap exists so that a pathological column cannot turn one log
  /// line into a megabyte. The truncation is marked in the line itself, so a
  /// reader can tell a shortened value from a short one.
  static const int _maxQuotedColumnChars = 2000;

  /// The default defect sink: stdout.
  ///
  /// Not [StructuredLogger], because this store has no `Session` — it is
  /// constructed from a `Database` alone at every composition site — and a sink
  /// that needs a session this class cannot reach would mean no sink at all.
  ///
  /// STDOUT, and not stderr, because stdout is where every other
  /// composition-level operator line goes: `server.dart`'s `_log` writes
  /// `[$event] $data` with `stdout.writeln`, and this sink exists to be
  /// greppable beside those lines. stderr would be the more defensive-looking
  /// choice and the wrong one: a supervisor or log shipper configured to
  /// collect stdout only would drop every one of these reports silently, and
  /// the whole point of this sink is that the degradation is never silent. A
  /// process that dies is already logged; this is not that, it is a per-read
  /// fault report that must reach the same stream an operator already reads.
  static void _stdoutJsonArrayDefect(
    String event,
    Map<String, Object?> fields,
  ) {
    stdout.writeln('[$event] $fields');
  }

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(WorkflowStore store) body,
  ) {
    return _db.inTransaction<T>(() => body(this));
  }

  @override
  Future<WorkItem> readWorkItem(String workItemId) async {
    final result = await _db.query(
      '''SELECT * FROM "work_item" WHERE "workItemId" = @workItemId''',
      parameters: QueryParameters.named({'workItemId': workItemId}),
    );
    if (result.isEmpty) {
      throw WorkItemNotFoundException(workItemId);
    }
    return _workItemFromRow(result[0]);
  }

  @override
  Future<List<WorkItem>> readAllWorkItems() async {
    final result = await _db.query('SELECT * FROM "work_item"');
    return result.map(_workItemFromRow).toList();
  }

  @override
  Future<void> saveWorkItem(WorkItem item, {int? expectedVersion}) async {
    const bareInsert = '''INSERT INTO "work_item" (
           "workItemId", "productId", "category", "title", "description",
           "state", "designContractId", "agentSessionId", "qaContractId",
           "featureRef", "requirementRef", "blockingHumanDecisionId",
           "blockingReason", "artifactRefsJson", "metadataJson",
           "createdAt", "updatedAt", "completedAt", "terminatedAt", "version"
         ) VALUES (
           @workItemId, @productId, @category, @title, @description,
           @state, @designContractId, @agentSessionId, @qaContractId,
           @featureRef, @requirementRef, @blockingHumanDecisionId,
           @blockingReason, @artifactRefsJson, @metadataJson,
           @createdAt, @updatedAt, @completedAt, @terminatedAt, @version
         )''';

    if (expectedVersion != null) {
      final affected = await _db.execute(
        '''UPDATE "work_item" SET
             "productId" = @productId,
             "category" = @category,
             "title" = @title,
             "description" = @description,
             "state" = @state,
             "designContractId" = @designContractId,
             "agentSessionId" = @agentSessionId,
             "qaContractId" = @qaContractId,
             "featureRef" = @featureRef,
             "requirementRef" = @requirementRef,
             "blockingHumanDecisionId" = @blockingHumanDecisionId,
             "blockingReason" = @blockingReason,
             "artifactRefsJson" = @artifactRefsJson,
             "metadataJson" = @metadataJson,
             "createdAt" = @createdAt,
             "updatedAt" = @updatedAt,
             "completedAt" = @completedAt,
             "terminatedAt" = @terminatedAt,
             "version" = @version
           WHERE "workItemId" = @workItemId AND "version" = @expected''',
        parameters: QueryParameters.named({
          ..._workItemToParams(item),
          'version': item.version,
          'expected': expectedVersion,
        }),
      );
      if (affected == 1) {
        return;
      }

      final rows = await _db.query(
        'SELECT "version" FROM "work_item" WHERE "workItemId" = @workItemId',
        parameters: QueryParameters.named({'workItemId': item.workItemId}),
      );
      final actual = rows.isEmpty ? 0 : rows[0].toColumnMap()['version'] as int;
      if (rows.isEmpty && expectedVersion == 0) {
        final inserted = await _db.execute(
          '$bareInsert ON CONFLICT ("workItemId") DO NOTHING',
          parameters: QueryParameters.named(_workItemToParams(item)),
        );
        if (inserted == 1) {
          return;
        }
        final current = await _db.query(
          'SELECT "version" FROM "work_item" WHERE "workItemId" = @workItemId',
          parameters: QueryParameters.named({'workItemId': item.workItemId}),
        );
        throw ConcurrentModificationException(
          entityId: item.workItemId,
          expectedVersion: 0,
          actualVersion: current.isEmpty
              ? 0
              : (current[0].toColumnMap()['version'] as int),
        );
      }
      throw ConcurrentModificationException(
        entityId: item.workItemId,
        expectedVersion: expectedVersion,
        actualVersion: actual,
      );
    }

    await _db.execute(
      '''$bareInsert ON CONFLICT ("workItemId") DO UPDATE SET
             "productId" = EXCLUDED."productId",
             "category" = EXCLUDED."category",
             "title" = EXCLUDED."title",
             "description" = EXCLUDED."description",
             "state" = EXCLUDED."state",
             "designContractId" = EXCLUDED."designContractId",
             "agentSessionId" = EXCLUDED."agentSessionId",
             "qaContractId" = EXCLUDED."qaContractId",
             "featureRef" = EXCLUDED."featureRef",
             "requirementRef" = EXCLUDED."requirementRef",
             "blockingHumanDecisionId" = EXCLUDED."blockingHumanDecisionId",
             "blockingReason" = EXCLUDED."blockingReason",
             "artifactRefsJson" = EXCLUDED."artifactRefsJson",
             "metadataJson" = EXCLUDED."metadataJson",
             "createdAt" = EXCLUDED."createdAt",
             "updatedAt" = EXCLUDED."updatedAt",
             "completedAt" = EXCLUDED."completedAt",
             "terminatedAt" = EXCLUDED."terminatedAt",
             "version" = EXCLUDED."version"''',
      parameters: QueryParameters.named(_workItemToParams(item)),
    );
  }

  @override
  Future<HumanDecision> readHumanDecision(String decisionId) async {
    final result = await _db.query(
      '''SELECT * FROM "human_decision" WHERE "decisionId" = @decisionId''',
      parameters: QueryParameters.named({'decisionId': decisionId}),
    );
    if (result.isEmpty) {
      throw HumanDecisionNotFoundException(decisionId);
    }
    return _humanDecisionFromRow(result[0]);
  }

  @override
  Future<List<HumanDecision>> readHumanDecisionsForWorkItem(
    String workItemId,
  ) async {
    final result = await _db.query(
      '''SELECT * FROM "human_decision"
         WHERE "workItemId" = @workItemId
         ORDER BY "updatedAt" ASC''',
      parameters: QueryParameters.named({'workItemId': workItemId}),
    );
    return result.map(_humanDecisionFromRow).toList();
  }

  @override
  Future<void> saveHumanDecision(HumanDecision decision) async {
    await _db.execute(
      '''INSERT INTO "human_decision" (
             "decisionId", "workItemId", "decisionType", "status", "question",
             "contextJson", "optionsJson", "recommendation", "blocking",
             "requestedAt", "expiration", "decider", "choice", "rationale",
             "timestamp", "signatureJson", "resolvedOptionId", "metadataJson",
             "updatedAt"
           ) VALUES (
             @decisionId, @workItemId, @decisionType, @status, @question,
             @contextJson, @optionsJson, @recommendation, @blocking,
             @requestedAt, @expiration, @decider, @choice, @rationale,
             @timestamp, @signatureJson, @resolvedOptionId, @metadataJson,
             @updatedAt
           )
           ON CONFLICT ("decisionId") DO UPDATE SET
             "workItemId" = EXCLUDED."workItemId",
             "decisionType" = EXCLUDED."decisionType",
             "status" = EXCLUDED."status",
             "question" = EXCLUDED."question",
             "contextJson" = EXCLUDED."contextJson",
             "optionsJson" = EXCLUDED."optionsJson",
             "recommendation" = EXCLUDED."recommendation",
             "blocking" = EXCLUDED."blocking",
             "requestedAt" = EXCLUDED."requestedAt",
             "expiration" = EXCLUDED."expiration",
             "decider" = EXCLUDED."decider",
             "choice" = EXCLUDED."choice",
             "rationale" = EXCLUDED."rationale",
             "timestamp" = EXCLUDED."timestamp",
             "signatureJson" = EXCLUDED."signatureJson",
             "resolvedOptionId" = EXCLUDED."resolvedOptionId",
             "metadataJson" = EXCLUDED."metadataJson",
             "updatedAt" = EXCLUDED."updatedAt"''',
      parameters: QueryParameters.named(_humanDecisionToParams(decision)),
    );
  }

  @override
  Future<List<WorkflowTransitionRecord>> readTransitionHistory(
    String workItemId,
  ) async {
    final result = await _db.query(
      '''SELECT * FROM "work_item_transition"
         WHERE "workItemId" = @workItemId
         ORDER BY "occurredAt" ASC''',
      parameters: QueryParameters.named({'workItemId': workItemId}),
    );
    return result.map(_transitionFromRow).toList();
  }

  @override
  Future<WorkflowTransitionRecord?> findTransitionByIdempotencyKey(
    String workItemId,
    String idempotencyKey,
  ) async {
    final result = await _db.query(
      '''SELECT * FROM "work_item_transition"
         WHERE "workItemId" = @workItemId AND "idempotencyKey" = @idempotencyKey''',
      parameters: QueryParameters.named({
        'workItemId': workItemId,
        'idempotencyKey': idempotencyKey,
      }),
    );
    if (result.isEmpty) return null;
    return _transitionFromRow(result[0]);
  }

  @override
  Future<void> appendTransitionRecord(WorkflowTransitionRecord record) async {
    await _db.execute(
      '''INSERT INTO "work_item_transition" (
             "transitionId", "workItemId", "fromState", "toState", "trigger",
             "actorType", "actorId", "decisionId", "outcome", "reason",
             "guardEvaluationsJson", "idempotencyKey", "occurredAt"
           ) VALUES (
             @transitionId, @workItemId, @fromState, @toState, @trigger,
             @actorType, @actorId, @decisionId, @outcome, @reason,
             @guardEvaluationsJson, @idempotencyKey, @occurredAt
           )''',
      parameters: QueryParameters.named(_transitionToParams(record)),
    );
  }

  /// Appends one operator action. INSERT only — there is no ON CONFLICT clause
  /// and no UPDATE, deliberately: this ledger is append-only, and a replay of
  /// one operator intent must COLLIDE on `operator_action_request_unique`
  /// rather than rewrite the row that already records what happened.
  @override
  Future<void> appendOperatorAction(OperatorActionRecord record) async {
    await _db.execute(
      '''INSERT INTO "operator_action" (
             "actionId", "workItemId", "action", "fromState", "toState",
             "requestedBy", "reason", "requestId", "jobId", "transitionId",
             "attemptNumber", "createdAt"
           ) VALUES (
             @actionId, @workItemId, @action, @fromState, @toState,
             @requestedBy, @reason, @requestId, @jobId, @transitionId,
             @attemptNumber, @createdAt
           )''',
      parameters: QueryParameters.named(_operatorActionToParams(record)),
    );
  }

  /// OLDEST FIRST, with `"actionId"` as a tiebreaker.
  ///
  /// The interface promises "OLDEST FIRST" and `createdAt` alone does not
  /// deliver it: two actions recorded in the same instant have no defined
  /// order between them in SQL, so a store that relied on the bare timestamp
  /// could return the same list in a different order on a different run.
  /// `actionId` is UNIQUE, so the pair is a total order and the promise holds.
  /// (`actionId` is not chronological — it embeds a timestamp plus a random
  /// suffix — but it only has to be deterministic among rows whose timestamps
  /// are equal, and it is.)
  ///
  /// `requestId` is unique per work item, so the replay lookup cannot face two
  /// candidates; the retry count is order-independent.
  @override
  Future<List<OperatorActionRecord>> readOperatorActionsForWorkItem(
    String workItemId,
  ) async {
    final result = await _db.query(
      '''SELECT * FROM "operator_action"
         WHERE "workItemId" = @workItemId
         ORDER BY "createdAt" ASC, "actionId" ASC''',
      parameters: QueryParameters.named({'workItemId': workItemId}),
    );
    return result.map(_operatorActionFromRow).toList();
  }

  WorkItem _workItemFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    final metadata =
        decodeJsonMap(m['metadataJson'] as String?) ?? <String, dynamic>{};
    return WorkItem.fromJson({
      'workItemId': m['workItemId'],
      'productId': m['productId'],
      'category': m['category'],
      'title': m['title'],
      'description': m['description'],
      'state': m['state'],
      'designContractId': m['designContractId'],
      'agentSessionId': m['agentSessionId'],
      'qaContractId': m['qaContractId'],
      'featureRef': m['featureRef'],
      'requirementRef': m['requirementRef'],
      'blockingHumanDecisionId': m['blockingHumanDecisionId'],
      'blockingReason': m['blockingReason'],
      'artifactRefs': decodeJsonArray(m['artifactRefsJson'] as String?),
      'metadata': metadata,
      'createdAt': decodeUtc(m['createdAt'])?.toIso8601String(),
      'updatedAt': decodeUtc(m['updatedAt'])?.toIso8601String(),
      'completedAt': decodeUtc(m['completedAt'])?.toIso8601String(),
      'terminatedAt': decodeUtc(m['terminatedAt'])?.toIso8601String(),
      'version': m['version'],
    });
  }

  HumanDecision _humanDecisionFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return HumanDecision.fromJson({
      'decisionId': m['decisionId'],
      'workItemId': m['workItemId'],
      'decisionType': m['decisionType'],
      'status': m['status'],
      'question': m['question'],
      'context': decodeJsonMap(m['contextJson'] as String?),
      'options': decodeJsonArray(m['optionsJson'] as String?),
      'recommendation': m['recommendation'],
      'blocking': m['blocking'],
      'requestedAt': decodeUtc(m['requestedAt'])?.toIso8601String(),
      'expiration': decodeUtc(m['expiration'])?.toIso8601String(),
      'decider': m['decider'],
      'choice': m['choice'],
      'rationale': m['rationale'],
      'timestamp': decodeUtc(m['timestamp'])?.toIso8601String(),
      'signature': decodeJsonMap(m['signatureJson'] as String?),
      'resolvedOptionId': m['resolvedOptionId'],
      'metadata': decodeJsonMap(m['metadataJson'] as String?),
      'updatedAt': decodeUtc(m['updatedAt'])?.toIso8601String(),
    });
  }

  WorkflowTransitionRecord _transitionFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return WorkflowTransitionRecord.fromJson({
      'transitionId': m['transitionId'],
      'workItemId': m['workItemId'],
      'fromState': m['fromState'],
      'toState': m['toState'],
      'trigger': m['trigger'],
      'actorType': m['actorType'],
      'actorId': m['actorId'],
      'decisionId': m['decisionId'],
      'outcome': m['outcome'],
      'reason': m['reason'],
      'guardEvaluations': _guardEvaluationsFromRow(m),
      'idempotencyKey': m['idempotencyKey'],
      'occurredAt': decodeUtc(m['occurredAt'])?.toIso8601String(),
    });
  }

  /// Reads `guardEvaluationsJson`, which one stored row can hold malformed
  /// WITHOUT ITS FAULT BEING ANYBODY ELSE'S.
  ///
  /// ## WHY THIS IS NOT `decodeJsonArray`
  ///
  /// `guardEvaluationsJson` is declared to hold an array of guard evaluations,
  /// and `decodeJsonArray` casts to `List<dynamic>`. Five rows written by
  /// migration `20261014210000000` hold a JSON OBJECT there instead — repair
  /// metadata, not guard evaluations — and the cast threw a `TypeError`. The
  /// throw propagated out of `readTransitionHistory`, past
  /// `ControlPlaneService.readTransitionHistory`, and out of BOTH
  /// `workflowEndpoints.inspect` and `defectEndpoints.inspect` as HTTP 500.
  ///
  /// The blast radius is the whole table, not the bad row. The reader is
  /// `SELECT * … WHERE "workItemId" = $1`, so ONE malformed row takes down the
  /// detail screen of its work item AND its defect — which is a different
  /// defect's screen, from a different table's row.
  ///
  /// ## WHY WRAPPING IT IN AN ARRAY IS NOT THE FIX
  ///
  /// It is tempting to "make the row conform" at read time by wrapping the
  /// object in a one-element list, because then the cast succeeds. It does not:
  /// `TransitionGuardEvaluation.fromJson` reads `guardName` with `as String`,
  /// and the repair metadata has no `guardName`. The cast failure would simply
  /// move one line down, from `decodeJsonArray` into
  /// `workflow_transition_record.g.dart`. The shape is wrong at the level of
  /// the ELEMENTS, not the container, and this column's fault cannot be papered
  /// over by a container.
  ///
  /// ## WHAT IT DOES INSTEAD
  ///
  /// A malformed column degrades to ABSENT and is reported. Absent is the
  /// honest answer — this row has no guard evaluations that can be read — and it
  /// is the answer `WorkflowTransitionRecord` already maps to `const []`. The
  /// fault is surfaced as `workflow.transition.guard_evaluations_malformed`,
  /// naming the row, the JSON type that was found and the offending text, so
  /// the degradation is visible rather than silent.
  ///
  /// The bytes are NOT lost, and nothing here rewrites them. The object in that
  /// column is the RESTORE PAYLOAD of `20261014210000000` — the fields its own
  /// `down` puts back verbatim — so a repair that replaced it, deleted it or
  /// reshaped it would destroy the evidence of a human's voided approval. This
  /// reader only READS the column and reports; the stored value is left exactly
  /// as `20261014210000000` wrote it, which is also why the report quotes the
  /// offending text rather than summarising it.
  ///
  /// ## A REPAIR MIGRATION FOR THIS COLUMN WAS PROPOSED AND WITHDRAWN
  ///
  /// Wrapping each non-array value in a one-element array was written, reviewed
  /// and removed: it satisfies the `as List<dynamic>` cast above, so it makes
  /// this report — the only thing standing between a malformed row and a silent
  /// wrong answer — unreachable, and the element it wraps still fails
  /// `guardName` one layer in, inside the generated record constructor at
  /// `packages/platform_contracts/lib/src/types/workflow_transition_record.g.dart`.
  /// The failure would have moved one layer down, not gone away. The negative
  /// fact is an assertion rather than a comment:
  /// `test/transition_row_malformed_guard_test.dart`, group "why the reader
  /// degrades to ABSENT rather than wrapping in an array". Why the wrap was
  /// tempting, and what it cost, is recorded in
  /// `docs/engineering/learning/a-container-that-conforms-is-not-a-payload-that-does.md`.
  List<dynamic>? _guardEvaluationsFromRow(Map<String, dynamic> m) {
    final read = readJsonArrayColumn(m['guardEvaluationsJson'] as String?);
    if (!read.isDefective) return read.value;
    final raw = read.raw ?? '';
    final quoted = raw.length > _maxQuotedColumnChars
        ? '${raw.substring(0, _maxQuotedColumnChars)}…[truncated, '
              '${raw.length} chars total]'
        : raw;
    _reportJsonArrayDefect(
      'workflow.transition.guard_evaluations_malformed',
      <String, Object?>{
        'transitionId': m['transitionId'],
        'workItemId': m['workItemId'],
        'column': 'guardEvaluationsJson',
        'declaredType': 'array',
        'defect': read.defect?.name,
        'observedChars': raw.length,
        'observed': quoted,
        'effect': 'guardEvaluations read as absent; row returned',
        'sourcePayload':
            'restore payload of migration 20261014210000000; '
            'left exactly as stored',
      },
    );
    return null;
  }

  Map<String, Object?> _workItemToParams(WorkItem item) {
    final json = item.toJson();
    return {
      'workItemId': json['workItemId'],
      'productId': json['productId'],
      'category': json['category'],
      'title': json['title'],
      'description': json['description'],
      'state': json['state'],
      'designContractId': json['designContractId'],
      'agentSessionId': json['agentSessionId'],
      'qaContractId': json['qaContractId'],
      'featureRef': json['featureRef'],
      'requirementRef': json['requirementRef'],
      'blockingHumanDecisionId': json['blockingHumanDecisionId'],
      'blockingReason': json['blockingReason'],
      'artifactRefsJson': item.artifactRefs == null
          ? null
          : PersistenceDatabase.encodeJson(
              item.artifactRefs!.map((a) => a.toJson()).toList(),
            ),
      'metadataJson': PersistenceDatabase.encodeJson(item.metadata),
      'createdAt': PersistenceDatabase.toUtc(item.createdAt),
      'updatedAt': PersistenceDatabase.toUtc(item.updatedAt),
      'completedAt': PersistenceDatabase.toUtc(item.completedAt),
      'terminatedAt': PersistenceDatabase.toUtc(item.terminatedAt),
      'version': item.version,
    };
  }

  Map<String, Object?> _humanDecisionToParams(HumanDecision decision) {
    final json = decision.toJson();
    return {
      'decisionId': json['decisionId'],
      'workItemId': json['workItemId'],
      'decisionType': json['decisionType'],
      'status': json['status'],
      'question': json['question'],
      'contextJson': PersistenceDatabase.encodeJson(json['context']),
      'optionsJson': PersistenceDatabase.encodeJson(json['options']),
      'recommendation': json['recommendation'],
      'blocking': json['blocking'],
      'requestedAt': decodeUtc(json['requestedAt']),
      'expiration': decodeUtc(json['expiration']),
      'decider': json['decider'],
      'choice': json['choice'],
      'rationale': json['rationale'],
      'timestamp': decodeUtc(json['timestamp']),
      'signatureJson': PersistenceDatabase.encodeJson(json['signature']),
      'resolvedOptionId': json['resolvedOptionId'],
      'metadataJson': PersistenceDatabase.encodeJson(json['metadata']),
      'updatedAt': PersistenceDatabase.toUtc(decision.updatedAt),
    };
  }

  OperatorActionRecord _operatorActionFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return OperatorActionRecord(
      actionId: m['actionId'] as String,
      workItemId: m['workItemId'] as String,
      action: m['action'] as String,
      fromState: m['fromState'] as String,
      toState: m['toState'] as String,
      requestedBy: m['requestedBy'] as String,
      reason: m['reason'] as String,
      requestId: m['requestId'] as String,
      jobId: m['jobId'] as String?,
      transitionId: m['transitionId'] as String?,
      attemptNumber: m['attemptNumber'] as int?,
      createdAt: decodeUtc(m['createdAt']) ?? DateTime.now().toUtc(),
    );
  }

  Map<String, Object?> _operatorActionToParams(OperatorActionRecord record) {
    return {
      'actionId': record.actionId,
      'workItemId': record.workItemId,
      'action': record.action,
      'fromState': record.fromState,
      'toState': record.toState,
      'requestedBy': record.requestedBy,
      'reason': record.reason,
      'requestId': record.requestId,
      'jobId': record.jobId,
      'transitionId': record.transitionId,
      'attemptNumber': record.attemptNumber,
      'createdAt': PersistenceDatabase.toUtc(record.createdAt),
    };
  }

  Map<String, Object?> _transitionToParams(WorkflowTransitionRecord record) {
    final json = record.toJson();
    return {
      'transitionId': json['transitionId'],
      'workItemId': json['workItemId'],
      'fromState': json['fromState'],
      'toState': json['toState'],
      'trigger': json['trigger'],
      'actorType': json['actorType'],
      'actorId': json['actorId'],
      'decisionId': json['decisionId'],
      'outcome': json['outcome'],
      'reason': json['reason'],
      'guardEvaluationsJson': PersistenceDatabase.encodeJson(
        json['guardEvaluations'],
      ),
      'idempotencyKey': json['idempotencyKey'],
      'occurredAt': PersistenceDatabase.toUtc(record.occurredAt),
    };
  }
}
