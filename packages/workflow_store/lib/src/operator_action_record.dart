/// The closed set of operator actions this repository records.
///
/// Kept as an enum with explicit wire tokens so a stored row can be validated
/// back, and so a caller cannot invent a third action by typo. The values are
/// the database spelling: the table stores `action` as a plain string.
enum OperatorActionKind {
  retry('retry'),
  stop('stop');

  const OperatorActionKind(this.wire);

  final String wire;

  static OperatorActionKind fromWire(String value) => values.firstWhere(
    (kind) => kind.wire == value,
    orElse: () => throw FormatException('Unknown operator action: $value'),
  );
}

/// One durable record of a HUMAN taking a consequential action on a work item.
///
/// This exists because `work_item_transition` cannot carry the answer: it
/// records the actor the ENGINE acted as (always `orchestrator` on these
/// paths), never the person who pressed the button, and it has no column for
/// the reason. A retry spends real model credits, so "who, and why" has to be
/// durable — as a first-class column, not a string parsed back out of an
/// idempotency key.
///
/// ## APPEND-ONLY, BY CONSTRUCTION
///
/// There is no update path and no delete path, on the type, on [WorkflowStore],
/// or in any store: the only thing the contract declares is
/// `appendOperatorAction`. `requestedBy` and `reason` are non-null for the same
/// reason — a row that cannot say who acted, or why, is not an audit record.
///
/// Rows are written **inside the transaction that moves the work item**, by
/// `DurableWorkflowEngine.transition`, so an audit row and the state change
/// it authorises cannot disagree after a crash, and a refused attempt —
/// which takes the rejected path before any transaction opens — leaves
/// nothing to audit.
///
/// The ONE exception is deliberate and named: the interrupted deploy advance
/// in `advanceToDeploy`
/// (`apps/server/lib/src/endpoints/work_item_action_endpoints.dart`) appends
/// standalone when the item is already at `deploying` with no gate — its
/// transition committed under an earlier intent, so there is no transaction
/// left to ride. The row is written FIRST, before the `deployment_approval`
/// raise it authorises, so a crash in between still leaves the audit and a
/// replay of the same `requestId` converges by finishing the raise.
/// Audit-first is the rule that makes a standalone append converge; it is
/// not a licence for a second one.
class OperatorActionRecord {
  const OperatorActionRecord({
    required this.actionId,
    required this.workItemId,
    required this.action,
    required this.fromState,
    required this.toState,
    required this.requestedBy,
    required this.reason,
    required this.requestId,
    required this.createdAt,
    this.jobId,
    this.transitionId,
    this.attemptNumber,
  });

  /// Primary key. Unique across the table.
  final String actionId;

  /// The work item the operator acted on.
  final String workItemId;

  /// 'retry' | 'stop' | 'deploy' | 'reclaim' | 'reland' | 'reroute'. The
  /// first two are the closed set of [OperatorActionKind]; the other four
  /// are the endpoint's own wire tokens (`operatorDeployActionWire` /
  /// `operatorReclaimActionWire` / `operatorRelandActionWire` /
  /// `operatorRerouteActionWire` in `work_item_action_endpoints.dart`),
  /// stored here as plain strings — the column carries no enum.
  final String action;

  /// Wire state the item was in when the action was taken.
  final String fromState;

  /// Wire state the action moved it to.
  final String toState;

  /// THE HUMAN. Unlike `work_item_transition.actorId`, which names the path the
  /// engine acted by.
  final String requestedBy;

  /// The human's stated reason. Never blank.
  final String reason;

  /// Client-minted id, stable per operator intent. Unique per work item: this
  /// is the idempotency record, so a replay of the same intent collides on
  /// `operator_action_request_unique` rather than creating a second row, a
  /// second job, or a second spend.
  final String requestId;

  /// The job this action armed. Declared for the audit shape, but no current
  /// producer sets it: every construction site omits it and the engine's
  /// [copyWith] stamps only [transitionId], so a stored row today always
  /// carries null here.
  final String? jobId;

  /// The `work_item_transition` row this action authorised.
  ///
  /// Stamped by the engine from a transition id it minted BEFORE opening its
  /// transaction, which is what lets the audit row and the transition commit
  /// together and name each other.
  final String? transitionId;

  /// 1 for the first retry of this item, 2 for the second, and so on — counted
  /// from this table, never from a counter in process memory.
  final int? attemptNumber;

  final DateTime createdAt;

  OperatorActionRecord copyWith({String? transitionId, String? jobId}) {
    return OperatorActionRecord(
      actionId: actionId,
      workItemId: workItemId,
      action: action,
      fromState: fromState,
      toState: toState,
      requestedBy: requestedBy,
      reason: reason,
      requestId: requestId,
      jobId: jobId ?? this.jobId,
      transitionId: transitionId ?? this.transitionId,
      attemptNumber: attemptNumber,
      createdAt: createdAt,
    );
  }

  /// Serialised form used by the file-backed store. Kept hand-written rather
  /// than generated: `DateTime` is stored as ISO-8601 UTC exactly as
  /// `WorkItem` round-trips its own timestamps, so a restart reloads byte-equal
  /// values.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'actionId': actionId,
    'workItemId': workItemId,
    'action': action,
    'fromState': fromState,
    'toState': toState,
    'requestedBy': requestedBy,
    'reason': reason,
    'requestId': requestId,
    if (jobId != null) 'jobId': jobId,
    if (transitionId != null) 'transitionId': transitionId,
    if (attemptNumber != null) 'attemptNumber': attemptNumber,
    'createdAt': createdAt.toIso8601String(),
  };

  factory OperatorActionRecord.fromJson(Map<String, dynamic> json) =>
      OperatorActionRecord(
        actionId: json['actionId'] as String,
        workItemId: json['workItemId'] as String,
        action: json['action'] as String,
        fromState: json['fromState'] as String,
        toState: json['toState'] as String,
        requestedBy: json['requestedBy'] as String,
        reason: json['reason'] as String,
        requestId: json['requestId'] as String,
        jobId: json['jobId'] as String?,
        transitionId: json['transitionId'] as String?,
        attemptNumber: json['attemptNumber'] as int?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OperatorActionRecord &&
          other.actionId == actionId &&
          other.workItemId == workItemId &&
          other.action == action &&
          other.fromState == fromState &&
          other.toState == toState &&
          other.requestedBy == requestedBy &&
          other.reason == reason &&
          other.requestId == requestId &&
          other.jobId == jobId &&
          other.transitionId == transitionId &&
          other.attemptNumber == attemptNumber &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    actionId,
    workItemId,
    action,
    fromState,
    toState,
    requestedBy,
    reason,
    requestId,
    jobId,
    transitionId,
    attemptNumber,
    createdAt,
  );

  @override
  String toString() =>
      'OperatorActionRecord($actionId: $workItemId $action '
      '$fromState->$toState by $requestedBy, '
      'requestId=$requestId, attempt=${attemptNumber ?? '-'}, '
      'transitionId=${transitionId ?? '-'})';
}
