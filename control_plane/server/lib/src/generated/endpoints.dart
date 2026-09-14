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
import '../endpoints/scheduler_endpoints.dart' as _i3;
import '../endpoints/worker_endpoints.dart' as _i4;
import '../endpoints/workflow_endpoints.dart' as _i5;

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
      'schedulerEndpoints': _i3.SchedulerEndpoints()
        ..initialize(
          server,
          'schedulerEndpoints',
          null,
        ),
      'workerEndpoints': _i4.WorkerEndpoints()
        ..initialize(
          server,
          'workerEndpoints',
          null,
        ),
      'workflowEndpoints': _i5.WorkflowEndpoints()
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
                  (endpoints['schedulerEndpoints'] as _i3.SchedulerEndpoints)
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
                  (endpoints['schedulerEndpoints'] as _i3.SchedulerEndpoints)
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
              ) async => (endpoints['workerEndpoints'] as _i4.WorkerEndpoints)
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
              ) async => (endpoints['workerEndpoints'] as _i4.WorkerEndpoints)
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
                  (endpoints['workerEndpoints'] as _i4.WorkerEndpoints).inspect(
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
                  (endpoints['workflowEndpoints'] as _i5.WorkflowEndpoints)
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
                  (endpoints['workflowEndpoints'] as _i5.WorkflowEndpoints)
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
                  (endpoints['workflowEndpoints'] as _i5.WorkflowEndpoints)
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
