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
import '../endpoints/credential_endpoints.dart' as _i2;
import '../endpoints/defect_endpoints.dart' as _i3;
import '../endpoints/execution_endpoints.dart' as _i4;
import '../endpoints/health_endpoints.dart' as _i5;
import '../endpoints/home_endpoints.dart' as _i6;
import '../endpoints/human_direction_endpoints.dart' as _i7;
import '../endpoints/intake_endpoints.dart' as _i8;
import '../endpoints/product_registry_endpoints.dart' as _i9;
import '../endpoints/provider_health_endpoints.dart' as _i10;
import '../endpoints/scheduler_endpoints.dart' as _i11;
import '../endpoints/worker_endpoints.dart' as _i12;
import '../endpoints/workflow_endpoints.dart' as _i13;
import 'package:control_plane_server/src/generated/human_direction_attachment_view.dart'
    as _i14;
import 'package:platform_contracts/src/types/baseline_fact.dart' as _i15;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'credentialEndpoints': _i2.CredentialEndpoints()
        ..initialize(
          server,
          'credentialEndpoints',
          null,
        ),
      'defectEndpoints': _i3.DefectEndpoints()
        ..initialize(
          server,
          'defectEndpoints',
          null,
        ),
      'executionEndpoints': _i4.ExecutionEndpoints()
        ..initialize(
          server,
          'executionEndpoints',
          null,
        ),
      'healthEndpoints': _i5.HealthEndpoints()
        ..initialize(
          server,
          'healthEndpoints',
          null,
        ),
      'homeEndpoints': _i6.HomeEndpoints()
        ..initialize(
          server,
          'homeEndpoints',
          null,
        ),
      'humanDirectionEndpoints': _i7.HumanDirectionEndpoints()
        ..initialize(
          server,
          'humanDirectionEndpoints',
          null,
        ),
      'intakeEndpoints': _i8.IntakeEndpoints()
        ..initialize(
          server,
          'intakeEndpoints',
          null,
        ),
      'productRegistryEndpoints': _i9.ProductRegistryEndpoints()
        ..initialize(
          server,
          'productRegistryEndpoints',
          null,
        ),
      'providerHealthEndpoints': _i10.ProviderHealthEndpoints()
        ..initialize(
          server,
          'providerHealthEndpoints',
          null,
        ),
      'schedulerEndpoints': _i11.SchedulerEndpoints()
        ..initialize(
          server,
          'schedulerEndpoints',
          null,
        ),
      'workerEndpoints': _i12.WorkerEndpoints()
        ..initialize(
          server,
          'workerEndpoints',
          null,
        ),
      'workflowEndpoints': _i13.WorkflowEndpoints()
        ..initialize(
          server,
          'workflowEndpoints',
          null,
        ),
    };
    connectors['credentialEndpoints'] = _i1.EndpointConnector(
      name: 'credentialEndpoints',
      endpoint: endpoints['credentialEndpoints']!,
      methodConnectors: {
        'generate': _i1.MethodConnector(
          name: 'generate',
          params: {
            'productId': _i1.ParameterDescription(
              name: 'productId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'repositoryId': _i1.ParameterDescription(
              name: 'repositoryId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'credentialId': _i1.ParameterDescription(
              name: 'credentialId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['credentialEndpoints'] as _i2.CredentialEndpoints)
                      .generate(
                        session,
                        productId: params['productId'],
                        repositoryId: params['repositoryId'],
                        credentialId: params['credentialId'],
                      ),
        ),
        'verifyAccess': _i1.MethodConnector(
          name: 'verifyAccess',
          params: {
            'productId': _i1.ParameterDescription(
              name: 'productId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'repositoryId': _i1.ParameterDescription(
              name: 'repositoryId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'hostKeyFingerprint': _i1.ParameterDescription(
              name: 'hostKeyFingerprint',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'confirmedBy': _i1.ParameterDescription(
              name: 'confirmedBy',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'checkedBy': _i1.ParameterDescription(
              name: 'checkedBy',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['credentialEndpoints'] as _i2.CredentialEndpoints)
                      .verifyAccess(
                        session,
                        productId: params['productId'],
                        repositoryId: params['repositoryId'],
                        hostKeyFingerprint: params['hostKeyFingerprint'],
                        confirmedBy: params['confirmedBy'],
                        checkedBy: params['checkedBy'],
                      ),
        ),
      },
    );
    connectors['defectEndpoints'] = _i1.EndpointConnector(
      name: 'defectEndpoints',
      endpoint: endpoints['defectEndpoints']!,
      methodConnectors: {
        'create': _i1.MethodConnector(
          name: 'create',
          params: {
            'title': _i1.ParameterDescription(
              name: 'title',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'description': _i1.ParameterDescription(
              name: 'description',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'expectedBehavior': _i1.ParameterDescription(
              name: 'expectedBehavior',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'reproductionSteps': _i1.ParameterDescription(
              name: 'reproductionSteps',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'severity': _i1.ParameterDescription(
              name: 'severity',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'intakeCategory': _i1.ParameterDescription(
              name: 'intakeCategory',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'productId': _i1.ParameterDescription(
              name: 'productId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'affectedWorkItemId': _i1.ParameterDescription(
              name: 'affectedWorkItemId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'affectedRunId': _i1.ParameterDescription(
              name: 'affectedRunId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'clientContextJson': _i1.ParameterDescription(
              name: 'clientContextJson',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'reporter': _i1.ParameterDescription(
              name: 'reporter',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['defectEndpoints'] as _i3.DefectEndpoints).create(
                    session,
                    title: params['title'],
                    description: params['description'],
                    expectedBehavior: params['expectedBehavior'],
                    reproductionSteps: params['reproductionSteps'],
                    severity: params['severity'],
                    intakeCategory: params['intakeCategory'],
                    productId: params['productId'],
                    affectedWorkItemId: params['affectedWorkItemId'],
                    affectedRunId: params['affectedRunId'],
                    clientContextJson: params['clientContextJson'],
                    reporter: params['reporter'],
                  ),
        ),
        'list': _i1.MethodConnector(
          name: 'list',
          params: {
            'productId': _i1.ParameterDescription(
              name: 'productId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'status': _i1.ParameterDescription(
              name: 'status',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'classification': _i1.ParameterDescription(
              name: 'classification',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
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
              ) async =>
                  (endpoints['defectEndpoints'] as _i3.DefectEndpoints).list(
                    session,
                    productId: params['productId'],
                    status: params['status'],
                    classification: params['classification'],
                    limit: params['limit'],
                    offset: params['offset'],
                  ),
        ),
        'inspect': _i1.MethodConnector(
          name: 'inspect',
          params: {
            'defectId': _i1.ParameterDescription(
              name: 'defectId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['defectEndpoints'] as _i3.DefectEndpoints).inspect(
                    session,
                    defectId: params['defectId'],
                  ),
        ),
        'addEvidence': _i1.MethodConnector(
          name: 'addEvidence',
          params: {
            'defectId': _i1.ParameterDescription(
              name: 'defectId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'kind': _i1.ParameterDescription(
              name: 'kind',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'description': _i1.ParameterDescription(
              name: 'description',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'artifactId': _i1.ParameterDescription(
              name: 'artifactId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'contentHash': _i1.ParameterDescription(
              name: 'contentHash',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'sourceRef': _i1.ParameterDescription(
              name: 'sourceRef',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['defectEndpoints'] as _i3.DefectEndpoints)
                  .addEvidence(
                    session,
                    defectId: params['defectId'],
                    kind: params['kind'],
                    description: params['description'],
                    artifactId: params['artifactId'],
                    contentHash: params['contentHash'],
                    sourceRef: params['sourceRef'],
                  ),
        ),
        'requestClarification': _i1.MethodConnector(
          name: 'requestClarification',
          params: {
            'defectId': _i1.ParameterDescription(
              name: 'defectId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'question': _i1.ParameterDescription(
              name: 'question',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'reason': _i1.ParameterDescription(
              name: 'reason',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'triageJobId': _i1.ParameterDescription(
              name: 'triageJobId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['defectEndpoints'] as _i3.DefectEndpoints)
                  .requestClarification(
                    session,
                    defectId: params['defectId'],
                    question: params['question'],
                    reason: params['reason'],
                    triageJobId: params['triageJobId'],
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
              ) async => (endpoints['defectEndpoints'] as _i3.DefectEndpoints)
                  .answerClarification(
                    session,
                    clarificationId: params['clarificationId'],
                    answer: params['answer'],
                    answeredBy: params['answeredBy'],
                  ),
        ),
        'verifyFix': _i1.MethodConnector(
          name: 'verifyFix',
          params: {
            'defectId': _i1.ParameterDescription(
              name: 'defectId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'choice': _i1.ParameterDescription(
              name: 'choice',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'rationale': _i1.ParameterDescription(
              name: 'rationale',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'decider': _i1.ParameterDescription(
              name: 'decider',
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
              ) async => (endpoints['defectEndpoints'] as _i3.DefectEndpoints)
                  .verifyFix(
                    session,
                    defectId: params['defectId'],
                    choice: params['choice'],
                    rationale: params['rationale'],
                    decider: params['decider'],
                    signature: params['signature'],
                    publicKey: params['publicKey'],
                    algorithm: params['algorithm'],
                    signedAt: params['signedAt'],
                  ),
        ),
      },
    );
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
                  (endpoints['executionEndpoints'] as _i4.ExecutionEndpoints)
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
                  (endpoints['executionEndpoints'] as _i4.ExecutionEndpoints)
                      .inspect(
                        session,
                        executionId: params['executionId'],
                      ),
        ),
      },
    );
    connectors['healthEndpoints'] = _i1.EndpointConnector(
      name: 'healthEndpoints',
      endpoint: endpoints['healthEndpoints']!,
      methodConnectors: {
        'health': _i1.MethodConnector(
          name: 'health',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['healthEndpoints'] as _i5.HealthEndpoints)
                  .health(session),
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
              ) async => (endpoints['homeEndpoints'] as _i6.HomeEndpoints)
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
            'productId': _i1.ParameterDescription(
              name: 'productId',
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
              ) async => (endpoints['homeEndpoints'] as _i6.HomeEndpoints)
                  .listWorkItems(
                    session,
                    state: params['state'],
                    productId: params['productId'],
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
              ) async => (endpoints['homeEndpoints'] as _i6.HomeEndpoints)
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
              ) async => (endpoints['homeEndpoints'] as _i6.HomeEndpoints)
                  .pendingDecisions(
                    session,
                    limit: params['limit'],
                  ),
        ),
      },
    );
    connectors['humanDirectionEndpoints'] = _i1.EndpointConnector(
      name: 'humanDirectionEndpoints',
      endpoint: endpoints['humanDirectionEndpoints']!,
      methodConnectors: {
        'createDirection': _i1.MethodConnector(
          name: 'createDirection',
          params: {
            'directionType': _i1.ParameterDescription(
              name: 'directionType',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'targetType': _i1.ParameterDescription(
              name: 'targetType',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'targetId': _i1.ParameterDescription(
              name: 'targetId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'title': _i1.ParameterDescription(
              name: 'title',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'description': _i1.ParameterDescription(
              name: 'description',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'contextJson': _i1.ParameterDescription(
              name: 'contextJson',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'attachments': _i1.ParameterDescription(
              name: 'attachments',
              type: _i1.getType<List<_i14.HumanDirectionAttachmentView>?>(),
              nullable: true,
            ),
            'createdBy': _i1.ParameterDescription(
              name: 'createdBy',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'assignedTo': _i1.ParameterDescription(
              name: 'assignedTo',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['humanDirectionEndpoints']
                          as _i7.HumanDirectionEndpoints)
                      .createDirection(
                        session,
                        directionType: params['directionType'],
                        targetType: params['targetType'],
                        targetId: params['targetId'],
                        title: params['title'],
                        description: params['description'],
                        contextJson: params['contextJson'],
                        attachments: params['attachments'],
                        createdBy: params['createdBy'],
                        assignedTo: params['assignedTo'],
                      ),
        ),
        'listDirectionsForTarget': _i1.MethodConnector(
          name: 'listDirectionsForTarget',
          params: {
            'targetType': _i1.ParameterDescription(
              name: 'targetType',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'targetId': _i1.ParameterDescription(
              name: 'targetId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'status': _i1.ParameterDescription(
              name: 'status',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
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
              ) async =>
                  (endpoints['humanDirectionEndpoints']
                          as _i7.HumanDirectionEndpoints)
                      .listDirectionsForTarget(
                        session,
                        targetType: params['targetType'],
                        targetId: params['targetId'],
                        status: params['status'],
                        limit: params['limit'],
                        offset: params['offset'],
                      ),
        ),
        'listDirectionsByStatus': _i1.MethodConnector(
          name: 'listDirectionsByStatus',
          params: {
            'status': _i1.ParameterDescription(
              name: 'status',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'directionType': _i1.ParameterDescription(
              name: 'directionType',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'targetType': _i1.ParameterDescription(
              name: 'targetType',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
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
              ) async =>
                  (endpoints['humanDirectionEndpoints']
                          as _i7.HumanDirectionEndpoints)
                      .listDirectionsByStatus(
                        session,
                        status: params['status'],
                        directionType: params['directionType'],
                        targetType: params['targetType'],
                        limit: params['limit'],
                        offset: params['offset'],
                      ),
        ),
        'readDirection': _i1.MethodConnector(
          name: 'readDirection',
          params: {
            'directionId': _i1.ParameterDescription(
              name: 'directionId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['humanDirectionEndpoints']
                          as _i7.HumanDirectionEndpoints)
                      .readDirection(
                        session,
                        directionId: params['directionId'],
                      ),
        ),
        'acknowledgeDirection': _i1.MethodConnector(
          name: 'acknowledgeDirection',
          params: {
            'directionId': _i1.ParameterDescription(
              name: 'directionId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'acknowledgedBy': _i1.ParameterDescription(
              name: 'acknowledgedBy',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['humanDirectionEndpoints']
                          as _i7.HumanDirectionEndpoints)
                      .acknowledgeDirection(
                        session,
                        directionId: params['directionId'],
                        acknowledgedBy: params['acknowledgedBy'],
                      ),
        ),
        'startWorkingDirection': _i1.MethodConnector(
          name: 'startWorkingDirection',
          params: {
            'directionId': _i1.ParameterDescription(
              name: 'directionId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'startedBy': _i1.ParameterDescription(
              name: 'startedBy',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['humanDirectionEndpoints']
                          as _i7.HumanDirectionEndpoints)
                      .startWorkingDirection(
                        session,
                        directionId: params['directionId'],
                        startedBy: params['startedBy'],
                      ),
        ),
        'completeDirection': _i1.MethodConnector(
          name: 'completeDirection',
          params: {
            'directionId': _i1.ParameterDescription(
              name: 'directionId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'completedBy': _i1.ParameterDescription(
              name: 'completedBy',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'completionSummary': _i1.ParameterDescription(
              name: 'completionSummary',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['humanDirectionEndpoints']
                          as _i7.HumanDirectionEndpoints)
                      .completeDirection(
                        session,
                        directionId: params['directionId'],
                        completedBy: params['completedBy'],
                        completionSummary: params['completionSummary'],
                      ),
        ),
        'rejectDirection': _i1.MethodConnector(
          name: 'rejectDirection',
          params: {
            'directionId': _i1.ParameterDescription(
              name: 'directionId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'rejectedBy': _i1.ParameterDescription(
              name: 'rejectedBy',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'rejectionReason': _i1.ParameterDescription(
              name: 'rejectionReason',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['humanDirectionEndpoints']
                          as _i7.HumanDirectionEndpoints)
                      .rejectDirection(
                        session,
                        directionId: params['directionId'],
                        rejectedBy: params['rejectedBy'],
                        rejectionReason: params['rejectionReason'],
                      ),
        ),
        'supersedeDirection': _i1.MethodConnector(
          name: 'supersedeDirection',
          params: {
            'directionId': _i1.ParameterDescription(
              name: 'directionId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'supersededByDirectionId': _i1.ParameterDescription(
              name: 'supersededByDirectionId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'supersededBy': _i1.ParameterDescription(
              name: 'supersededBy',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['humanDirectionEndpoints']
                          as _i7.HumanDirectionEndpoints)
                      .supersedeDirection(
                        session,
                        directionId: params['directionId'],
                        supersededByDirectionId:
                            params['supersededByDirectionId'],
                        supersededBy: params['supersededBy'],
                      ),
        ),
      },
    );
    connectors['intakeEndpoints'] = _i1.EndpointConnector(
      name: 'intakeEndpoints',
      endpoint: endpoints['intakeEndpoints']!,
      methodConnectors: {
        'createFeatureRequest': _i1.MethodConnector(
          name: 'createFeatureRequest',
          params: {
            'title': _i1.ParameterDescription(
              name: 'title',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'description': _i1.ParameterDescription(
              name: 'description',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'productId': _i1.ParameterDescription(
              name: 'productId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'reporter': _i1.ParameterDescription(
              name: 'reporter',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['intakeEndpoints'] as _i8.IntakeEndpoints)
                  .createFeatureRequest(
                    session,
                    title: params['title'],
                    description: params['description'],
                    productId: params['productId'],
                    reporter: params['reporter'],
                  ),
        ),
        'listFeatureRequests': _i1.MethodConnector(
          name: 'listFeatureRequests',
          params: {
            'productId': _i1.ParameterDescription(
              name: 'productId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
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
              ) async => (endpoints['intakeEndpoints'] as _i8.IntakeEndpoints)
                  .listFeatureRequests(
                    session,
                    productId: params['productId'],
                    state: params['state'],
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
                          as _i9.ProductRegistryEndpoints)
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
                          as _i9.ProductRegistryEndpoints)
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
                          as _i9.ProductRegistryEndpoints)
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
                          as _i9.ProductRegistryEndpoints)
                      .productContext(
                        session,
                        productId: params['productId'],
                      ),
        ),
        'proposeBaseline': _i1.MethodConnector(
          name: 'proposeBaseline',
          params: {
            'productId': _i1.ParameterDescription(
              name: 'productId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'facts': _i1.ParameterDescription(
              name: 'facts',
              type: _i1.getType<List<_i15.BaselineFact>>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['productRegistryEndpoints']
                          as _i9.ProductRegistryEndpoints)
                      .proposeBaseline(
                        session,
                        productId: params['productId'],
                        facts: params['facts'],
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
                          as _i9.ProductRegistryEndpoints)
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
                          as _i9.ProductRegistryEndpoints)
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
                          as _i9.ProductRegistryEndpoints)
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
                          as _i9.ProductRegistryEndpoints)
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
                          as _i9.ProductRegistryEndpoints)
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
                          as _i9.ProductRegistryEndpoints)
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
                          as _i9.ProductRegistryEndpoints)
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
                          as _i9.ProductRegistryEndpoints)
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
                          as _i9.ProductRegistryEndpoints)
                      .answerClarification(
                        session,
                        clarificationId: params['clarificationId'],
                        answer: params['answer'],
                        answeredBy: params['answeredBy'],
                      ),
        ),
        'createProduct': _i1.MethodConnector(
          name: 'createProduct',
          params: {
            'productId': _i1.ParameterDescription(
              name: 'productId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'name': _i1.ParameterDescription(
              name: 'name',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'description': _i1.ParameterDescription(
              name: 'description',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'manifestJson': _i1.ParameterDescription(
              name: 'manifestJson',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'manifestVersion': _i1.ParameterDescription(
              name: 'manifestVersion',
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
                          as _i9.ProductRegistryEndpoints)
                      .createProduct(
                        session,
                        productId: params['productId'],
                        name: params['name'],
                        description: params['description'],
                        manifestJson: params['manifestJson'],
                        manifestVersion: params['manifestVersion'],
                      ),
        ),
        'addRepositoryReference': _i1.MethodConnector(
          name: 'addRepositoryReference',
          params: {
            'productId': _i1.ParameterDescription(
              name: 'productId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'repositoryId': _i1.ParameterDescription(
              name: 'repositoryId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'uri': _i1.ParameterDescription(
              name: 'uri',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'kind': _i1.ParameterDescription(
              name: 'kind',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'provider': _i1.ParameterDescription(
              name: 'provider',
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
                          as _i9.ProductRegistryEndpoints)
                      .addRepositoryReference(
                        session,
                        productId: params['productId'],
                        repositoryId: params['repositoryId'],
                        uri: params['uri'],
                        kind: params['kind'],
                        provider: params['provider'],
                      ),
        ),
        'verifyBaseline': _i1.MethodConnector(
          name: 'verifyBaseline',
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
            'verifiedBy': _i1.ParameterDescription(
              name: 'verifiedBy',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'kind': _i1.ParameterDescription(
              name: 'kind',
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
                          as _i9.ProductRegistryEndpoints)
                      .verifyBaseline(
                        session,
                        productId: params['productId'],
                        baselineId: params['baselineId'],
                        verifiedBy: params['verifiedBy'],
                        kind: params['kind'],
                      ),
        ),
        'addHumanBaselineClaim': _i1.MethodConnector(
          name: 'addHumanBaselineClaim',
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
            'section': _i1.ParameterDescription(
              name: 'section',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'claim': _i1.ParameterDescription(
              name: 'claim',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'author': _i1.ParameterDescription(
              name: 'author',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'evidenceRefs': _i1.ParameterDescription(
              name: 'evidenceRefs',
              type: _i1.getType<List<String>?>(),
              nullable: true,
            ),
            'maturity': _i1.ParameterDescription(
              name: 'maturity',
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
                          as _i9.ProductRegistryEndpoints)
                      .addHumanBaselineClaim(
                        session,
                        productId: params['productId'],
                        baselineId: params['baselineId'],
                        section: params['section'],
                        claim: params['claim'],
                        author: params['author'],
                        evidenceRefs: params['evidenceRefs'],
                        maturity: params['maturity'],
                      ),
        ),
      },
    );
    connectors['providerHealthEndpoints'] = _i1.EndpointConnector(
      name: 'providerHealthEndpoints',
      endpoint: endpoints['providerHealthEndpoints']!,
      methodConnectors: {
        'getProviderHealth': _i1.MethodConnector(
          name: 'getProviderHealth',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['providerHealthEndpoints']
                          as _i10.ProviderHealthEndpoints)
                      .getProviderHealth(session),
        ),
        'listModelPolicies': _i1.MethodConnector(
          name: 'listModelPolicies',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['providerHealthEndpoints']
                          as _i10.ProviderHealthEndpoints)
                      .listModelPolicies(session),
        ),
        'updateModelPolicy': _i1.MethodConnector(
          name: 'updateModelPolicy',
          params: {
            'role': _i1.ParameterDescription(
              name: 'role',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'chainJson': _i1.ParameterDescription(
              name: 'chainJson',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'version': _i1.ParameterDescription(
              name: 'version',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'updatedByDecisionId': _i1.ParameterDescription(
              name: 'updatedByDecisionId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['providerHealthEndpoints']
                          as _i10.ProviderHealthEndpoints)
                      .updateModelPolicy(
                        session,
                        role: params['role'],
                        chainJson: params['chainJson'],
                        version: params['version'],
                        updatedByDecisionId: params['updatedByDecisionId'],
                      ),
        ),
        'listModelExecutions': _i1.MethodConnector(
          name: 'listModelExecutions',
          params: {
            'workItemId': _i1.ParameterDescription(
              name: 'workItemId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'provider': _i1.ParameterDescription(
              name: 'provider',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'modelId': _i1.ParameterDescription(
              name: 'modelId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'from': _i1.ParameterDescription(
              name: 'from',
              type: _i1.getType<DateTime?>(),
              nullable: true,
            ),
            'to': _i1.ParameterDescription(
              name: 'to',
              type: _i1.getType<DateTime?>(),
              nullable: true,
            ),
            'limit': _i1.ParameterDescription(
              name: 'limit',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'offset': _i1.ParameterDescription(
              name: 'offset',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['providerHealthEndpoints']
                          as _i10.ProviderHealthEndpoints)
                      .listModelExecutions(
                        session,
                        workItemId: params['workItemId'],
                        provider: params['provider'],
                        modelId: params['modelId'],
                        from: params['from'],
                        to: params['to'],
                        limit: params['limit'],
                        offset: params['offset'],
                      ),
        ),
        'getModelStats': _i1.MethodConnector(
          name: 'getModelStats',
          params: {
            'from': _i1.ParameterDescription(
              name: 'from',
              type: _i1.getType<DateTime?>(),
              nullable: true,
            ),
            'to': _i1.ParameterDescription(
              name: 'to',
              type: _i1.getType<DateTime?>(),
              nullable: true,
            ),
            'groupBy': _i1.ParameterDescription(
              name: 'groupBy',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['providerHealthEndpoints']
                          as _i10.ProviderHealthEndpoints)
                      .getModelStats(
                        session,
                        from: params['from'],
                        to: params['to'],
                        groupBy: params['groupBy'],
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
                  (endpoints['schedulerEndpoints'] as _i11.SchedulerEndpoints)
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
                  (endpoints['schedulerEndpoints'] as _i11.SchedulerEndpoints)
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
              ) async => (endpoints['workerEndpoints'] as _i12.WorkerEndpoints)
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
              ) async => (endpoints['workerEndpoints'] as _i12.WorkerEndpoints)
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
              ) async => (endpoints['workerEndpoints'] as _i12.WorkerEndpoints)
                  .inspect(
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
                  (endpoints['workflowEndpoints'] as _i13.WorkflowEndpoints)
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
                  (endpoints['workflowEndpoints'] as _i13.WorkflowEndpoints)
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
                  (endpoints['workflowEndpoints'] as _i13.WorkflowEndpoints)
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
                  (endpoints['workflowEndpoints'] as _i13.WorkflowEndpoints)
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
