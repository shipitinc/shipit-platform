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

import 'package:serverpod/serverpod.dart' as _i1;
import '../endpoints/execution_endpoints.dart' as _i2;
import '../endpoints/home_endpoints.dart' as _i3;
import '../endpoints/product_registry_endpoints.dart' as _i4;
import '../endpoints/scheduler_endpoints.dart' as _i5;
import '../endpoints/worker_endpoints.dart' as _i6;
import '../endpoints/workflow_endpoints.dart' as _i7;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'executionEndpoints': _i2.ExecutionEndpoints()
        ..initialize(
          server,
          'executionEndpoints',
          null,
        ),
      'homeEndpoints': _i3.HomeEndpoints()
        ..initialize(
          server,
          'homeEndpoints',
          null,
        ),
      'productRegistryEndpoints': _i4.ProductRegistryEndpoints()
        ..initialize(
          server,
          'productRegistryEndpoints',
          null,
        ),
      'schedulerEndpoints': _i5.SchedulerEndpoints()
        ..initialize(
          server,
          'schedulerEndpoints',
          null,
        ),
      'workerEndpoints': _i6.WorkerEndpoints()
        ..initialize(
          server,
          'workerEndpoints',
          null,
        ),
      'workflowEndpoints': _i7.WorkflowEndpoints()
        ..initialize(
          server,
          'workflowEndpoints',
          null,
        ),
    };
    connectors['executionEndpoints'] = _i1.EndpointConnector(
      name: 'executionEndpoints',
      endpoint: endpoints['executionEndpoints']!,
      methodConnectors: {
        'list': _i1.MethodConnector(
          name: 'list',
          params: {
            'workItemId': _i1.ParameterDescription(
              name: 'workItemId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['executionEndpoints'] as _i2.ExecutionEndpoints)
                      .list(
                        session,
                        workItemId: params['workItemId'],
                      ),
        ),
        'inspect': _i1.MethodConnector(
          name: 'inspect',
          params: {
            'executionId': _i1.ParameterDescription(
              name: 'executionId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['executionEndpoints'] as _i2.ExecutionEndpoints)
                      .inspect(
                        session,
                        executionId: params['executionId'],
                      ),
        ),
      },
    );
    connectors['homeEndpoints'] = _i1.EndpointConnector(
      name: 'homeEndpoints',
      endpoint: endpoints['homeEndpoints']!,
      methodConnectors: {
        'overview': _i1.MethodConnector(
          name: 'overview',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['homeEndpoints'] as _i3.HomeEndpoints)
                  .overview(session),
        ),
        'listWorkItems': _i1.MethodConnector(
          name: 'listWorkItems',
          params: {
            'state': _i1.ParameterDescription(
              name: 'state',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'limit': _i1.ParameterDescription(
              name: 'limit',
              type: _i1.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['homeEndpoints'] as _i3.HomeEndpoints)
                  .listWorkItems(
                    session,
                    state: params['state'],
                    limit: params['limit'],
                  ),
        ),
        'recentDecisions': _i1.MethodConnector(
          name: 'recentDecisions',
          params: {
            'limit': _i1.ParameterDescription(
              name: 'limit',
              type: _i1.getType<int?>(),
              nullable: true,
            ),
            'offset': _i1.ParameterDescription(
              name: 'offset',
              type: _i1.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['homeEndpoints'] as _i3.HomeEndpoints)
                  .recentDecisions(
                    session,
                    limit: params['limit'],
                    offset: params['offset'],
                  ),
        ),
        'pendingDecisions': _i1.MethodConnector(
          name: 'pendingDecisions',
          params: {
            'limit': _i1.ParameterDescription(
              name: 'limit',
              type: _i1.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['homeEndpoints'] as _i3.HomeEndpoints)
                  .pendingDecisions(
                    session,
                    limit: params['limit'],
                  ),
        ),
      },
    );
    connectors['productRegistryEndpoints'] = _i1.EndpointConnector(
      name: 'productRegistryEndpoints',
      endpoint: endpoints['productRegistryEndpoints']!,
      methodConnectors: {
        'listProducts': _i1.MethodConnector(
          name: 'listProducts',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['productRegistryEndpoints']
                          as _i4.ProductRegistryEndpoints)
                      .listProducts(session),
        ),
        'listProductSummaries': _i1.MethodConnector(
          name: 'listProductSummaries',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['productRegistryEndpoints']
                          as _i4.ProductRegistryEndpoints)
                      .listProductSummaries(session),
        ),
        'productDetail': _i1.MethodConnector(
          name: 'productDetail',
          params: {
            'productId': _i1.ParameterDescription(
              name: 'productId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['productRegistryEndpoints']
                          as _i4.ProductRegistryEndpoints)
                      .productDetail(
                        session,
                        productId: params['productId'],
                      ),
        ),
        'productContext': _i1.MethodConnector(
          name: 'productContext',
          params: {
            'productId': _i1.ParameterDescription(
              name: 'productId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['productRegistryEndpoints']
                          as _i4.ProductRegistryEndpoints)
                      .productContext(
                        session,
                        productId: params['productId'],
                      ),
        ),
        'requestBaselineApproval': _i1.MethodConnector(
          name: 'requestBaselineApproval',
          params: {
            'productId': _i1.ParameterDescription(
              name: 'productId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'baselineId': _i1.ParameterDescription(
              name: 'baselineId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'decisionId': _i1.ParameterDescription(
              name: 'decisionId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['productRegistryEndpoints']
                          as _i4.ProductRegistryEndpoints)
                      .requestBaselineApproval(
                        session,
                        productId: params['productId'],
                        baselineId: params['baselineId'],
                        decisionId: params['decisionId'],
                      ),
        ),
        'requestLifecycleDecision': _i1.MethodConnector(
          name: 'requestLifecycleDecision',
          params: {
            'productId': _i1.ParameterDescription(
              name: 'productId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'action': _i1.ParameterDescription(
              name: 'action',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'drainInFlight': _i1.ParameterDescription(
              name: 'drainInFlight',
              type: _i1.getType<bool>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['productRegistryEndpoints']
                          as _i4.ProductRegistryEndpoints)
                      .requestLifecycleDecision(
                        session,
                        productId: params['productId'],
                        action: params['action'],
                        drainInFlight: params['drainInFlight'],
                      ),
        ),
        'resolveLifecycleDecision': _i1.MethodConnector(
          name: 'resolveLifecycleDecision',
          params: {
            'decisionId': _i1.ParameterDescription(
              name: 'decisionId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'choice': _i1.ParameterDescription(
              name: 'choice',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'decider': _i1.ParameterDescription(
              name: 'decider',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'rationale': _i1.ParameterDescription(
              name: 'rationale',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'signature': _i1.ParameterDescription(
              name: 'signature',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'publicKey': _i1.ParameterDescription(
              name: 'publicKey',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'algorithm': _i1.ParameterDescription(
              name: 'algorithm',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'signedAt': _i1.ParameterDescription(
              name: 'signedAt',
              type: _i1.getType<DateTime>(),
              nullable: false,
            ),
            'noWorkInFlight': _i1.ParameterDescription(
              name: 'noWorkInFlight',
              type: _i1.getType<bool>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['productRegistryEndpoints']
                          as _i4.ProductRegistryEndpoints)
                      .resolveLifecycleDecision(
                        session,
                        decisionId: params['decisionId'],
                        choice: params['choice'],
                        decider: params['decider'],
                        rationale: params['rationale'],
                        signature: params['signature'],
                        publicKey: params['publicKey'],
                        algorithm: params['algorithm'],
                        signedAt: params['signedAt'],
                        noWorkInFlight: params['noWorkInFlight'],
                      ),
        ),
        'requestPolicyAuthorisation': _i1.MethodConnector(
          name: 'requestPolicyAuthorisation',
          params: {
            'productId': _i1.ParameterDescription(
              name: 'productId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'actions': _i1.ParameterDescription(
              name: 'actions',
              type: _i1.getType<List<String>>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['productRegistryEndpoints']
                          as _i4.ProductRegistryEndpoints)
                      .requestPolicyAuthorisation(
                        session,
                        productId: params['productId'],
                        actions: params['actions'],
                      ),
        ),
        'resolvePolicyAuthorisation': _i1.MethodConnector(
          name: 'resolvePolicyAuthorisation',
          params: {
            'decisionId': _i1.ParameterDescription(
              name: 'decisionId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'choice': _i1.ParameterDescription(
              name: 'choice',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'decider': _i1.ParameterDescription(
              name: 'decider',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'rationale': _i1.ParameterDescription(
              name: 'rationale',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'signature': _i1.ParameterDescription(
              name: 'signature',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'publicKey': _i1.ParameterDescription(
              name: 'publicKey',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'algorithm': _i1.ParameterDescription(
              name: 'algorithm',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'signedAt': _i1.ParameterDescription(
              name: 'signedAt',
              type: _i1.getType<DateTime>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['productRegistryEndpoints']
                          as _i4.ProductRegistryEndpoints)
                      .resolvePolicyAuthorisation(
                        session,
                        decisionId: params['decisionId'],
                        choice: params['choice'],
                        decider: params['decider'],
                        rationale: params['rationale'],
                        signature: params['signature'],
                        publicKey: params['publicKey'],
                        algorithm: params['algorithm'],
                        signedAt: params['signedAt'],
                      ),
        ),
        'revokeStandingPolicy': _i1.MethodConnector(
          name: 'revokeStandingPolicy',
          params: {
            'productId': _i1.ParameterDescription(
              name: 'productId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'policyId': _i1.ParameterDescription(
              name: 'policyId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'revokedBy': _i1.ParameterDescription(
              name: 'revokedBy',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['productRegistryEndpoints']
                          as _i4.ProductRegistryEndpoints)
                      .revokeStandingPolicy(
                        session,
                        productId: params['productId'],
                        policyId: params['policyId'],
                        revokedBy: params['revokedBy'],
                      ),
        ),
        'resolveBaselineApproval': _i1.MethodConnector(
          name: 'resolveBaselineApproval',
          params: {
            'decisionId': _i1.ParameterDescription(
              name: 'decisionId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'choice': _i1.ParameterDescription(
              name: 'choice',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'decider': _i1.ParameterDescription(
              name: 'decider',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'rationale': _i1.ParameterDescription(
              name: 'rationale',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'signature': _i1.ParameterDescription(
              name: 'signature',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'publicKey': _i1.ParameterDescription(
              name: 'publicKey',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'algorithm': _i1.ParameterDescription(
              name: 'algorithm',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'signedAt': _i1.ParameterDescription(
              name: 'signedAt',
              type: _i1.getType<DateTime>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['productRegistryEndpoints']
                          as _i4.ProductRegistryEndpoints)
                      .resolveBaselineApproval(
                        session,
                        decisionId: params['decisionId'],
                        choice: params['choice'],
                        decider: params['decider'],
                        rationale: params['rationale'],
                        signature: params['signature'],
                        publicKey: params['publicKey'],
                        algorithm: params['algorithm'],
                        signedAt: params['signedAt'],
                      ),
        ),
        'baselineApproval': _i1.MethodConnector(
          name: 'baselineApproval',
          params: {
            'productId': _i1.ParameterDescription(
              name: 'productId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'baselineId': _i1.ParameterDescription(
              name: 'baselineId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['productRegistryEndpoints']
                          as _i4.ProductRegistryEndpoints)
                      .baselineApproval(
                        session,
                        productId: params['productId'],
                        baselineId: params['baselineId'],
                      ),
        ),
        'answerClarification': _i1.MethodConnector(
          name: 'answerClarification',
          params: {
            'clarificationId': _i1.ParameterDescription(
              name: 'clarificationId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'answer': _i1.ParameterDescription(
              name: 'answer',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'answeredBy': _i1.ParameterDescription(
              name: 'answeredBy',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['productRegistryEndpoints']
                          as _i4.ProductRegistryEndpoints)
                      .answerClarification(
                        session,
                        clarificationId: params['clarificationId'],
                        answer: params['answer'],
                        answeredBy: params['answeredBy'],
                      ),
        ),
      },
    );
    connectors['schedulerEndpoints'] = _i1.EndpointConnector(
      name: 'schedulerEndpoints',
      endpoint: endpoints['schedulerEndpoints']!,
      methodConnectors: {
        'listJobs': _i1.MethodConnector(
          name: 'listJobs',
          params: {
            'workItemId': _i1.ParameterDescription(
              name: 'workItemId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['schedulerEndpoints'] as _i5.SchedulerEndpoints)
                      .listJobs(
                        session,
                        workItemId: params['workItemId'],
                      ),
        ),
        'inspect': _i1.MethodConnector(
          name: 'inspect',
          params: {
            'jobId': _i1.ParameterDescription(
              name: 'jobId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['schedulerEndpoints'] as _i5.SchedulerEndpoints)
                      .inspect(
                        session,
                        jobId: params['jobId'],
                      ),
        ),
      },
    );
    connectors['workerEndpoints'] = _i1.EndpointConnector(
      name: 'workerEndpoints',
      endpoint: endpoints['workerEndpoints']!,
      methodConnectors: {
        'listWorkers': _i1.MethodConnector(
          name: 'listWorkers',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['workerEndpoints'] as _i6.WorkerEndpoints)
                  .listWorkers(session),
        ),
        'listExecutions': _i1.MethodConnector(
          name: 'listExecutions',
          params: {
            'workItemId': _i1.ParameterDescription(
              name: 'workItemId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['workerEndpoints'] as _i6.WorkerEndpoints)
                  .listExecutions(
                    session,
                    workItemId: params['workItemId'],
                  ),
        ),
        'inspect': _i1.MethodConnector(
          name: 'inspect',
          params: {
            'workerExecutionId': _i1.ParameterDescription(
              name: 'workerExecutionId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['workerEndpoints'] as _i6.WorkerEndpoints).inspect(
                    session,
                    workerExecutionId: params['workerExecutionId'],
                  ),
        ),
      },
    );
    connectors['workflowEndpoints'] = _i1.EndpointConnector(
      name: 'workflowEndpoints',
      endpoint: endpoints['workflowEndpoints']!,
      methodConnectors: {
        'jobsForWorkItem': _i1.MethodConnector(
          name: 'jobsForWorkItem',
          params: {
            'workItemId': _i1.ParameterDescription(
              name: 'workItemId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['workflowEndpoints'] as _i7.WorkflowEndpoints)
                      .jobsForWorkItem(
                        session,
                        workItemId: params['workItemId'],
                      ),
        ),
        'inspect': _i1.MethodConnector(
          name: 'inspect',
          params: {
            'workItemId': _i1.ParameterDescription(
              name: 'workItemId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['workflowEndpoints'] as _i7.WorkflowEndpoints)
                      .inspect(
                        session,
                        workItemId: params['workItemId'],
                      ),
        ),
        'listDecisions': _i1.MethodConnector(
          name: 'listDecisions',
          params: {
            'workItemId': _i1.ParameterDescription(
              name: 'workItemId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['workflowEndpoints'] as _i7.WorkflowEndpoints)
                      .listDecisions(
                        session,
                        workItemId: params['workItemId'],
                      ),
        ),
        'resolveDecision': _i1.MethodConnector(
          name: 'resolveDecision',
          params: {
            'decisionId': _i1.ParameterDescription(
              name: 'decisionId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'choice': _i1.ParameterDescription(
              name: 'choice',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'decider': _i1.ParameterDescription(
              name: 'decider',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'rationale': _i1.ParameterDescription(
              name: 'rationale',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'algorithm': _i1.ParameterDescription(
              name: 'algorithm',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'publicKey': _i1.ParameterDescription(
              name: 'publicKey',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'signature': _i1.ParameterDescription(
              name: 'signature',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'signedAt': _i1.ParameterDescription(
              name: 'signedAt',
              type: _i1.getType<DateTime>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['workflowEndpoints'] as _i7.WorkflowEndpoints)
                      .resolveDecision(
                        session,
                        decisionId: params['decisionId'],
                        choice: params['choice'],
                        decider: params['decider'],
                        rationale: params['rationale'],
                        algorithm: params['algorithm'],
                        publicKey: params['publicKey'],
                        signature: params['signature'],
                        signedAt: params['signedAt'],
                      ),
        ),
      },
    );
  }
}
