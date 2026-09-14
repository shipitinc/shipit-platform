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
import 'protocol.dart' as _i3;

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

  /// Returns the current work item and its transition history. Never mutates
  /// state; `WorkItem.state` on the wire is always reported, never written.
  _i2.Future<Map<String, dynamic>> inspect({required String workItemId}) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'workflowEndpoints',
        'inspect',
        {'workItemId': workItemId},
      );

  /// Lists every decision attached to a work item, most recent first.
  _i2.Future<Map<String, dynamic>> listDecisions({
    required String workItemId,
  }) => caller.callServerEndpoint<Map<String, dynamic>>(
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
  _i2.Future<Map<String, dynamic>> resolveDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String algorithm,
    required String publicKey,
    required String signature,
    required DateTime signedAt,
  }) => caller.callServerEndpoint<Map<String, dynamic>>(
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
         _i3.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
       ) {
    executionEndpoints = EndpointExecutionEndpoints(this);
    schedulerEndpoints = EndpointSchedulerEndpoints(this);
    workerEndpoints = EndpointWorkerEndpoints(this);
    workflowEndpoints = EndpointWorkflowEndpoints(this);
  }

  late final EndpointExecutionEndpoints executionEndpoints;

  late final EndpointSchedulerEndpoints schedulerEndpoints;

  late final EndpointWorkerEndpoints workerEndpoints;

  late final EndpointWorkflowEndpoints workflowEndpoints;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {
    'executionEndpoints': executionEndpoints,
    'schedulerEndpoints': schedulerEndpoints,
    'workerEndpoints': workerEndpoints,
    'workflowEndpoints': workflowEndpoints,
  };

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {};
}
