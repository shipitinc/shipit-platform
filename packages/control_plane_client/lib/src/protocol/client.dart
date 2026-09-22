/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'dart:async' as _i2;
import 'package:control_plane_client/src/protocol/overview.dart' as _i3;
import 'package:control_plane_client/src/protocol/work_item_view.dart' as _i4;
import 'package:control_plane_client/src/protocol/decision_view.dart' as _i5;
import 'package:control_plane_client/src/protocol/product_view.dart' as _i6;
import 'package:control_plane_client/src/protocol/product_summary_view.dart'
    as _i7;
import 'package:control_plane_client/src/protocol/product_detail_view.dart'
    as _i8;
import 'package:control_plane_client/src/protocol/product_context_view.dart'
    as _i9;
import 'package:control_plane_client/src/protocol/standing_policy_view.dart'
    as _i10;
import 'package:control_plane_client/src/protocol/clarification_view.dart'
    as _i11;
import 'package:control_plane_client/src/protocol/job_summary_view.dart'
    as _i12;
import 'package:control_plane_client/src/protocol/work_item_detail_view.dart'
    as _i13;
import 'package:control_plane_client/src/protocol/resolve_decision_view.dart'
    as _i14;
import 'protocol.dart' as _i15;

/// Read endpoints for execution_coordinator durable state (agent executions,
/// events, results, verifications).
/// {@category Endpoint}
class EndpointExecutionEndpoints extends _i1.EndpointRef {
  EndpointExecutionEndpoints(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'executionEndpoints';

  /// Lists agent executions, optionally filtered by work item. Reads only.
  _i2.Future<Map<String, dynamic>> list({String? workItemId}) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'executionEndpoints',
        'list',
        {'workItemId': workItemId},
      );

  /// Returns one execution, its events, result and verifications. Reads only.
  _i2.Future<Map<String, dynamic>> inspect({required String executionId}) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'executionEndpoints',
        'inspect',
        {'executionId': executionId},
      );
}

/// Endpoints for the Home dashboard overview.
/// {@category Endpoint}
class EndpointHomeEndpoints extends _i1.EndpointRef {
  EndpointHomeEndpoints(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'homeEndpoints';

  /// Returns summary counts plus the supporting detail the Overview screen
  /// renders: the finished pass/fail split, a server-stamped freshness marker,
  /// and the queue/capacity strip.
  ///
  /// Everything here is derived from durable records only — no estimates. The
  /// screen states "Every number on this page comes straight from the system's
  /// own records", so a value that cannot be read is reported as zero/absent
  /// rather than inferred.
  _i2.Future<_i3.Overview> overview() =>
      caller.callServerEndpoint<_i3.Overview>(
        'homeEndpoints',
        'overview',
        {},
      );

  /// Lists work items with optional filters.
  _i2.Future<List<_i4.WorkItemView>> listWorkItems({
    String? state,
    int? limit,
  }) => caller.callServerEndpoint<List<_i4.WorkItemView>>(
    'homeEndpoints',
    'listWorkItems',
    {
      'state': state,
      'limit': limit,
    },
  );

  /// Lists decisions that already carry a durable outcome, newest first.
  ///
  /// Once a decision is resolved its work item is no longer blocked, so it
  /// drops out of [pendingDecisions] entirely. The operator surface still has
  /// to show what was decided ("Already decided"), which needs its own read.
  /// [offset] skips the newest N, so the caller can page as it scrolls. The
  /// ordering is stable (resolution time, newest first) which is what makes
  /// offset paging safe to use here.
  _i2.Future<List<_i5.DecisionView>> recentDecisions({
    int? limit,
    int? offset,
  }) => caller.callServerEndpoint<List<_i5.DecisionView>>(
    'homeEndpoints',
    'recentDecisions',
    {
      'limit': limit,
      'offset': offset,
    },
  );

  /// Lists pending blocking human decisions.
  _i2.Future<List<_i5.DecisionView>> pendingDecisions({int? limit}) =>
      caller.callServerEndpoint<List<_i5.DecisionView>>(
        'homeEndpoints',
        'pendingDecisions',
        {'limit': limit},
      );
}

/// Endpoints for the durable Product registry and onboarding (S-1).
///
/// Every product-scoped read takes an explicit `productId`: there is no
/// implicit "current Product" on the server, so a client can never be handed
/// another Product's context by omitting a parameter (checkpoint 006 §2/§13).
///
/// The two write endpoints delegate to the durable engine — an endpoint never
/// sets state directly. `acceptBaseline` is the human baseline gate and binds
/// acceptance to the exact revision + contentHash the caller names.
/// {@category Endpoint}
class EndpointProductRegistryEndpoints extends _i1.EndpointRef {
  EndpointProductRegistryEndpoints(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'productRegistryEndpoints';

  /// Lists every registered Product (global registry read).
  _i2.Future<List<_i6.ProductView>> listProducts() =>
      caller.callServerEndpoint<List<_i6.ProductView>>(
        'productRegistryEndpoints',
        'listProducts',
        {},
      );

  /// One row per product for the Products list, with the baseline,
  /// clarification and credential-reachability counts already resolved.
  _i2.Future<List<_i7.ProductSummaryView>> listProductSummaries() =>
      caller.callServerEndpoint<List<_i7.ProductSummaryView>>(
        'productRegistryEndpoints',
        'listProductSummaries',
        {},
      );

  /// Everything the Product Detail screen reads, in one call.
  _i2.Future<_i8.ProductDetailView> productDetail({
    required String productId,
  }) => caller.callServerEndpoint<_i8.ProductDetailView>(
    'productRegistryEndpoints',
    'productDetail',
    {'productId': productId},
  );

  /// Loads the bounded `ProductContext(productId)`: exactly that Product and
  /// everything scoped to it. A scope mismatch is a fault, not a filter.
  _i2.Future<_i9.ProductContextView> productContext({
    required String productId,
  }) => caller.callServerEndpoint<_i9.ProductContextView>(
    'productRegistryEndpoints',
    'productContext',
    {'productId': productId},
  );

  /// Creates a durable baseline-approval decision bound to the exact current
  /// revision + contentHash. Returns the decision for the client to present to
  /// the human approver.
  _i2.Future<_i5.DecisionView> requestBaselineApproval({
    required String productId,
    required String baselineId,
    String? decisionId,
  }) => caller.callServerEndpoint<_i5.DecisionView>(
    'productRegistryEndpoints',
    'requestBaselineApproval',
    {
      'productId': productId,
      'baselineId': baselineId,
      'decisionId': decisionId,
    },
  );

  /// Raises the durable gate for a product lifecycle action.
  ///
  /// `action` is one of pause | resume | offboard | reinstate. The engine
  /// refuses up front if the transition could never be resolved, so a gate is
  /// never created that nobody can action.
  _i2.Future<_i5.DecisionView> requestLifecycleDecision({
    required String productId,
    required String action,
    required bool drainInFlight,
  }) => caller.callServerEndpoint<_i5.DecisionView>(
    'productRegistryEndpoints',
    'requestLifecycleDecision',
    {
      'productId': productId,
      'action': action,
      'drainInFlight': drainInFlight,
    },
  );

  /// Resolves a lifecycle gate. On approve the engine performs the
  /// transition, and refuses if a required guard was never established —
  /// offboarding with work still in flight, for example.
  _i2.Future<_i5.DecisionView> resolveLifecycleDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
    required bool noWorkInFlight,
  }) => caller.callServerEndpoint<_i5.DecisionView>(
    'productRegistryEndpoints',
    'resolveLifecycleDecision',
    {
      'decisionId': decisionId,
      'choice': choice,
      'decider': decider,
      'rationale': rationale,
      'signature': signature,
      'publicKey': publicKey,
      'algorithm': algorithm,
      'signedAt': signedAt,
      'noWorkInFlight': noWorkInFlight,
    },
  );

  /// Raises the gate that would create a standing policy (ADR 0019).
  ///
  /// `actions` may only contain push | merge. Production promotion, baseline
  /// approval and offboarding are non-delegable and are not expressible.
  _i2.Future<_i5.DecisionView> requestPolicyAuthorisation({
    required String productId,
    required List<String> actions,
  }) => caller.callServerEndpoint<_i5.DecisionView>(
    'productRegistryEndpoints',
    'requestPolicyAuthorisation',
    {
      'productId': productId,
      'actions': actions,
    },
  );

  /// Resolves a policy gate. On approve a [StandingPolicy] is created citing
  /// this decision; any policy already live over the same scope is superseded.
  _i2.Future<_i10.StandingPolicyView?> resolvePolicyAuthorisation({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
  }) => caller.callServerEndpoint<_i10.StandingPolicyView?>(
    'productRegistryEndpoints',
    'resolvePolicyAuthorisation',
    {
      'decisionId': decisionId,
      'choice': choice,
      'decider': decider,
      'rationale': rationale,
      'signature': signature,
      'publicKey': publicKey,
      'algorithm': algorithm,
      'signedAt': signedAt,
    },
  );

  /// Withdraws a standing policy. Revocation is itself recorded.
  _i2.Future<_i10.StandingPolicyView> revokeStandingPolicy({
    required String productId,
    required String policyId,
    required String revokedBy,
  }) => caller.callServerEndpoint<_i10.StandingPolicyView>(
    'productRegistryEndpoints',
    'revokeStandingPolicy',
    {
      'productId': productId,
      'policyId': policyId,
      'revokedBy': revokedBy,
    },
  );

  /// Resolves a baseline-approval decision. On approve, accepts the bound
  /// baseline; other choices record the resolution without acceptance.
  _i2.Future<_i5.DecisionView> resolveBaselineApproval({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
  }) => caller.callServerEndpoint<_i5.DecisionView>(
    'productRegistryEndpoints',
    'resolveBaselineApproval',
    {
      'decisionId': decisionId,
      'choice': choice,
      'decider': decider,
      'rationale': rationale,
      'signature': signature,
      'publicKey': publicKey,
      'algorithm': algorithm,
      'signedAt': signedAt,
    },
  );

  /// Reads the durable approval decision governing a baseline's exact current
  /// candidate, or 404 when none has been requested.
  _i2.Future<_i5.DecisionView> baselineApproval({
    required String productId,
    required String baselineId,
  }) => caller.callServerEndpoint<_i5.DecisionView>(
    'productRegistryEndpoints',
    'baselineApproval',
    {
      'productId': productId,
      'baselineId': baselineId,
    },
  );

  /// Answers a durable clarification, resuming the same onboarding lineage.
  _i2.Future<_i11.ClarificationView> answerClarification({
    required String clarificationId,
    required String answer,
    required String answeredBy,
  }) => caller.callServerEndpoint<_i11.ClarificationView>(
    'productRegistryEndpoints',
    'answerClarification',
    {
      'clarificationId': clarificationId,
      'answer': answer,
      'answeredBy': answeredBy,
    },
  );
}

/// Read endpoints for scheduler durable state (jobs + their lifecycle events).
/// {@category Endpoint}
class EndpointSchedulerEndpoints extends _i1.EndpointRef {
  EndpointSchedulerEndpoints(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'schedulerEndpoints';

  /// Lists all jobs, newest first. Reads only.
  _i2.Future<Map<String, dynamic>> listJobs({String? workItemId}) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'schedulerEndpoints',
        'listJobs',
        {'workItemId': workItemId},
      );

  /// Returns one job, its claim, and its full event history. Reads only.
  _i2.Future<Map<String, dynamic>> inspect({required String jobId}) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'schedulerEndpoints',
        'inspect',
        {'jobId': jobId},
      );
}

/// Read endpoints for worker_runtime durable state (registrations +
/// executions + results).
/// {@category Endpoint}
class EndpointWorkerEndpoints extends _i1.EndpointRef {
  EndpointWorkerEndpoints(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'workerEndpoints';

  /// Lists registered workers. Reads only.
  _i2.Future<Map<String, dynamic>> listWorkers() =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'workerEndpoints',
        'listWorkers',
        {},
      );

  /// Lists worker executions, newest first. Reads only.
  _i2.Future<Map<String, dynamic>> listExecutions({String? workItemId}) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'workerEndpoints',
        'listExecutions',
        {'workItemId': workItemId},
      );

  /// Returns one execution, its events and (if present) its result. Reads only.
  _i2.Future<Map<String, dynamic>> inspect({
    required String workerExecutionId,
  }) => caller.callServerEndpoint<Map<String, dynamic>>(
    'workerEndpoints',
    'inspect',
    {'workerExecutionId': workerExecutionId},
  );
}

/// Read endpoints for durable workflow state (work items + their transitions).
/// {@category Endpoint}
class EndpointWorkflowEndpoints extends _i1.EndpointRef {
  EndpointWorkflowEndpoints(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'workflowEndpoints';

  /// Returns the jobs belonging to a work item, newest first.
  ///
  /// Read-only: the operator surface reports what the scheduler has committed
  /// and never enqueues, claims or cancels. Feeds the Run detail line that
  /// explains what is held up behind a pending decision.
  _i2.Future<List<_i12.JobSummaryView>> jobsForWorkItem({
    required String workItemId,
  }) => caller.callServerEndpoint<List<_i12.JobSummaryView>>(
    'workflowEndpoints',
    'jobsForWorkItem',
    {'workItemId': workItemId},
  );

  /// Returns the current work item and its transition history. Never mutates
  /// state; `WorkItem.state` on the wire is always reported, never written.
  _i2.Future<_i13.WorkItemDetailView> inspect({required String workItemId}) =>
      caller.callServerEndpoint<_i13.WorkItemDetailView>(
        'workflowEndpoints',
        'inspect',
        {'workItemId': workItemId},
      );

  /// Lists every decision attached to a work item, most recent first.
  _i2.Future<List<_i5.DecisionView>> listDecisions({
    required String workItemId,
  }) => caller.callServerEndpoint<List<_i5.DecisionView>>(
    'workflowEndpoints',
    'listDecisions',
    {'workItemId': workItemId},
  );

  /// Resolves a human decision through the durable engine.
  ///
  /// This is the only legal request-side state transition. The decision,
  /// its resolution, and the resulting work item move are persisted
  /// transactionally; a repeated call is an idempotent replay, so retries
  /// after a network failure never double-apply the transition.
  _i2.Future<_i14.ResolveDecisionView> resolveDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String algorithm,
    required String publicKey,
    required String signature,
    required DateTime signedAt,
  }) => caller.callServerEndpoint<_i14.ResolveDecisionView>(
    'workflowEndpoints',
    'resolveDecision',
    {
      'decisionId': decisionId,
      'choice': choice,
      'decider': decider,
      'rationale': rationale,
      'algorithm': algorithm,
      'publicKey': publicKey,
      'signature': signature,
      'signedAt': signedAt,
    },
  );
}

class Client extends _i1.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    @Deprecated(
      'Use authKeyProvider instead. This will be removed in future releases.',
    )
    super.authenticationKeyManager,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _i1.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_i1.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
  }) : super(
         host,
         _i15.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
       ) {
    executionEndpoints = EndpointExecutionEndpoints(this);
    homeEndpoints = EndpointHomeEndpoints(this);
    productRegistryEndpoints = EndpointProductRegistryEndpoints(this);
    schedulerEndpoints = EndpointSchedulerEndpoints(this);
    workerEndpoints = EndpointWorkerEndpoints(this);
    workflowEndpoints = EndpointWorkflowEndpoints(this);
  }

  late final EndpointExecutionEndpoints executionEndpoints;

  late final EndpointHomeEndpoints homeEndpoints;

  late final EndpointProductRegistryEndpoints productRegistryEndpoints;

  late final EndpointSchedulerEndpoints schedulerEndpoints;

  late final EndpointWorkerEndpoints workerEndpoints;

  late final EndpointWorkflowEndpoints workflowEndpoints;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {
    'executionEndpoints': executionEndpoints,
    'homeEndpoints': homeEndpoints,
    'productRegistryEndpoints': productRegistryEndpoints,
    'schedulerEndpoints': schedulerEndpoints,
    'workerEndpoints': workerEndpoints,
    'workflowEndpoints': workflowEndpoints,
  };

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {};
}
