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
import 'package:serverpod/protocol.dart' as _i2;
import 'artifact_reference_view.dart' as _i3;
import 'baseline_fact_view.dart' as _i4;
import 'clarification_view.dart' as _i5;
import 'credential_access_verification_view.dart' as _i6;
import 'database/agent_event.dart' as _i7;
import 'database/agent_execution.dart' as _i8;
import 'database/agent_execution_request.dart' as _i9;
import 'database/agent_result.dart' as _i10;
import 'database/baseline_fact.dart' as _i11;
import 'database/clarification_request.dart' as _i12;
import 'database/defect.dart' as _i13;
import 'database/defect_clarification.dart' as _i14;
import 'database/defect_event.dart' as _i15;
import 'database/defect_evidence.dart' as _i16;
import 'database/design_finding.dart' as _i17;
import 'database/design_review_result.dart' as _i18;
import 'database/design_revision.dart' as _i19;
import 'database/design_revision_event.dart' as _i20;
import 'database/engineering_review_result.dart' as _i21;
import 'database/human_decision.dart' as _i22;
import 'database/human_direction.dart' as _i23;
import 'database/job.dart' as _i24;
import 'database/job_claim.dart' as _i25;
import 'database/model_execution_record.dart' as _i26;
import 'database/model_policy.dart' as _i27;
import 'database/onboarding_record.dart' as _i28;
import 'database/platform_verification.dart' as _i29;
import 'database/product.dart' as _i30;
import 'database/product_baseline.dart' as _i31;
import 'database/product_registry_audit.dart' as _i32;
import 'database/qa_contract.dart' as _i33;
import 'database/qa_review_result.dart' as _i34;
import 'database/repository_credential.dart' as _i35;
import 'database/repository_reference.dart' as _i36;
import 'database/scheduler_event.dart' as _i37;
import 'database/standing_policy.dart' as _i38;
import 'database/triage_result.dart' as _i39;
import 'database/work_item.dart' as _i40;
import 'database/work_item_transition.dart' as _i41;
import 'database/worker_event.dart' as _i42;
import 'database/worker_execution.dart' as _i43;
import 'database/worker_registration.dart' as _i44;
import 'database/worker_result.dart' as _i45;
import 'decision_context_view.dart' as _i46;
import 'decision_option_view.dart' as _i47;
import 'decision_view.dart' as _i48;
import 'feature_request_summary_view.dart' as _i49;
import 'human_direction_attachment_view.dart' as _i50;
import 'human_direction_payload_view.dart' as _i51;
import 'human_direction_view.dart' as _i52;
import 'job_summary_view.dart' as _i53;
import 'minted_credential_view.dart' as _i54;
import 'overview.dart' as _i55;
import 'product_baseline_view.dart' as _i56;
import 'product_context_view.dart' as _i57;
import 'product_detail_view.dart' as _i58;
import 'product_summary_view.dart' as _i59;
import 'product_view.dart' as _i60;
import 'repository_credential_view.dart' as _i61;
import 'repository_reference_view.dart' as _i62;
import 'resolve_decision_view.dart' as _i63;
import 'standing_policy_view.dart' as _i64;
import 'transition_view.dart' as _i65;
import 'work_item_detail_view.dart' as _i66;
import 'work_item_view.dart' as _i67;
import 'package:control_plane_server/src/generated/work_item_view.dart' as _i68;
import 'package:control_plane_server/src/generated/decision_view.dart' as _i69;
import 'package:control_plane_server/src/generated/human_direction_attachment_view.dart'
    as _i70;
import 'package:control_plane_server/src/generated/human_direction_view.dart'
    as _i71;
import 'package:control_plane_server/src/generated/feature_request_summary_view.dart'
    as _i72;
import 'package:control_plane_server/src/generated/product_view.dart' as _i73;
import 'package:control_plane_server/src/generated/product_summary_view.dart'
    as _i74;
import 'package:platform_contracts/src/types/baseline_fact.dart' as _i75;
import 'package:control_plane_server/src/generated/job_summary_view.dart'
    as _i76;
export 'artifact_reference_view.dart';
export 'baseline_fact_view.dart';
export 'clarification_view.dart';
export 'credential_access_verification_view.dart';
export 'database/agent_event.dart';
export 'database/agent_execution.dart';
export 'database/agent_execution_request.dart';
export 'database/agent_result.dart';
export 'database/baseline_fact.dart';
export 'database/clarification_request.dart';
export 'database/defect.dart';
export 'database/defect_clarification.dart';
export 'database/defect_event.dart';
export 'database/defect_evidence.dart';
export 'database/design_finding.dart';
export 'database/design_review_result.dart';
export 'database/design_revision.dart';
export 'database/design_revision_event.dart';
export 'database/engineering_review_result.dart';
export 'database/human_decision.dart';
export 'database/human_direction.dart';
export 'database/job.dart';
export 'database/job_claim.dart';
export 'database/model_execution_record.dart';
export 'database/model_policy.dart';
export 'database/onboarding_record.dart';
export 'database/platform_verification.dart';
export 'database/product.dart';
export 'database/product_baseline.dart';
export 'database/product_registry_audit.dart';
export 'database/qa_contract.dart';
export 'database/qa_review_result.dart';
export 'database/repository_credential.dart';
export 'database/repository_reference.dart';
export 'database/scheduler_event.dart';
export 'database/standing_policy.dart';
export 'database/triage_result.dart';
export 'database/work_item.dart';
export 'database/work_item_transition.dart';
export 'database/worker_event.dart';
export 'database/worker_execution.dart';
export 'database/worker_registration.dart';
export 'database/worker_result.dart';
export 'decision_context_view.dart';
export 'decision_option_view.dart';
export 'decision_view.dart';
export 'feature_request_summary_view.dart';
export 'human_direction_attachment_view.dart';
export 'human_direction_payload_view.dart';
export 'human_direction_view.dart';
export 'job_summary_view.dart';
export 'minted_credential_view.dart';
export 'overview.dart';
export 'product_baseline_view.dart';
export 'product_context_view.dart';
export 'product_detail_view.dart';
export 'product_summary_view.dart';
export 'product_view.dart';
export 'repository_credential_view.dart';
export 'repository_reference_view.dart';
export 'resolve_decision_view.dart';
export 'standing_policy_view.dart';
export 'transition_view.dart';
export 'work_item_detail_view.dart';
export 'work_item_view.dart';

class Protocol extends _i1.SerializationManagerServer {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static final List<_i2.TableDefinition> targetTableDefinitions = [
    _i2.TableDefinition(
      name: 'agent_event',
      dartName: 'AgentEventRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'agent_event_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'eventId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'executionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workItemId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'sequence',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'type',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'occurredAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'payloadJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'agent_event_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'agent_event_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'eventId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'agent_event_execution_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'executionId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'agent_event_execution_sequence_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'executionId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'sequence',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'agent_execution',
      dartName: 'AgentExecutionRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'agent_execution_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'executionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workItemId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'requestId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'runtimeTypeId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'role',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workspaceJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'sessionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'resultId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'startedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'completedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'reason',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'metadataJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'agent_execution_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'agent_execution_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'executionId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'agent_execution_work_item_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workItemId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'agent_execution_request',
      dartName: 'AgentExecutionRequestRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault:
              'nextval(\'agent_execution_request_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'executionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workItemId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'role',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'runtimeTypeId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workspaceJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'instruction',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'timeoutSeconds',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'permittedScope',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'expectedResultJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'expectedArtifactsJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'runtimeConfigJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'environmentJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'agent_execution_request_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'agent_execution_request_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'executionId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'agent_result',
      dartName: 'AgentResultRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'agent_result_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'resultId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'sessionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workItemId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'artifactsJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'diagnosticsJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'structuredResultJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'executionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'role',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'changedFilesJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'claimedChecksJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'summary',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'completedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'metadataJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'agent_result_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'agent_result_execution_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'executionId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'baseline_fact',
      dartName: 'BaselineFactRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'baseline_fact_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'factId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'baselineId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'section',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'claim',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'provenance',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'maturity',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'evidenceRefsJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'assumptionNote',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'redacted',
          columnType: _i2.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'baseline_fact_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'baseline_fact_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'factId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'baselineId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'baseline_fact_baseline_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'baselineId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'clarification_request',
      dartName: 'ClarificationRequestRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'clarification_request_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'clarificationId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'productId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'onboardingId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'section',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'question',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'answer',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'answeredAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'answeredBy',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'clarification_request_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'clarification_request_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'clarificationId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'clarification_request_product_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'productId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'clarification_request_status_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'status',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'defect',
      dartName: 'DefectRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'defect_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'defectId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'title',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'description',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'expectedBehavior',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'reproductionSteps',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'severity',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'classification',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'reporter',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'productId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'affectedWorkItemId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'affectedRunId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'remediationWorkItemId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'duplicateOfDefectId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'currentTriageJobId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'clientContextJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'metadataJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'updatedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'resolvedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'closedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'defect_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'defectId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_status_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'status',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_classification_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'classification',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_reporter_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'reporter',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_affected_work_item_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'affectedWorkItemId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_triage_job_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'currentTriageJobId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'defect_clarification',
      dartName: 'DefectClarificationRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'defect_clarification_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'clarificationId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'defectId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'question',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'reason',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'answer',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'humanDecisionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'requestedByTriageJobId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'requestedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'answeredAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'defect_clarification_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_clarification_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'clarificationId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_clarification_defect_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'defectId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_clarification_status_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'status',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_clarification_human_decision_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'humanDecisionId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_clarification_triage_job_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'requestedByTriageJobId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'defect_event',
      dartName: 'DefectEventRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'defect_event_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'eventId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'defectId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'sequence',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'type',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'fromStatus',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'toStatus',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'actorType',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'actorId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'payloadJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'occurredAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'defect_event_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_event_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'eventId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_event_defect_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'defectId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_event_sequence_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'defectId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'sequence',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'defect_evidence',
      dartName: 'DefectEvidenceRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'defect_evidence_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'evidenceId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'defectId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'kind',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'artifactId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'contentHash',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'description',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'sourceRef',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'capturedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'defect_evidence_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_evidence_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'evidenceId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_evidence_defect_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'defectId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'defect_evidence_artifact_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'artifactId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'design_finding',
      dartName: 'DesignFindingRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'design_finding_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'findingId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'revisionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'reviewExecutionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'category',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'severity',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'dimension',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'evidence',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'requiredCorrection',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'affectedSurface',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'resolvedByRevisionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'design_finding_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'design_finding_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'findingId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'design_finding_revision_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'revisionId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'design_finding_review_execution_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'reviewExecutionId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'design_finding_resolved_by_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'resolvedByRevisionId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'design_review_result',
      dartName: 'DesignReviewResultRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'design_review_result_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'reviewResultId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'revisionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'reviewExecutionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'verdict',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'findingsJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'assessedDimensionsJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'reviewScopeJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'design_review_result_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'design_review_result_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'reviewResultId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'design_review_result_revision_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'revisionId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'design_review_result_execution_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'reviewExecutionId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'design_revision',
      dartName: 'DesignRevisionRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'design_revision_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'revisionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workItemId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'productId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'parentRevisionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'designSystemRevision',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'providerType',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'penpotFileId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'penpotPageId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'boardIdsJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'responsiveTargetsJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'statesRepresentedJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'artifactRefsJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'designerExecutionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'reviewExecutionIdsJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'riskTier',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'reviewScopeJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'carriedForwardFromRevisionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'supersededByRevisionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'updatedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'approvedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'design_revision_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'design_revision_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'revisionId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'design_revision_work_item_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workItemId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'design_revision_status_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'status',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'design_revision_designer_execution_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'designerExecutionId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'design_revision_event',
      dartName: 'DesignRevisionEventRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'design_revision_event_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'eventId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'designRevisionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'eventType',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'payloadJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'sequence',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'design_revision_event_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'design_revision_event_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'eventId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'design_revision_event_revision_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'designRevisionId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'design_revision_event_sequence_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'designRevisionId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'sequence',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'engineering_review_result',
      dartName: 'EngineeringReviewResultRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault:
              'nextval(\'engineering_review_result_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'reviewExecutionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'revisionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'verdict',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'findingsJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'assessedDimensionsJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'reviewScopeJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'engineering_review_result_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'engineering_review_result_revision',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'revisionId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'engineering_review_result_verdict',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'verdict',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'human_decision',
      dartName: 'HumanDecisionRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'human_decision_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'decisionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workItemId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'decisionType',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'question',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'contextJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'optionsJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'recommendation',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'blocking',
          columnType: _i2.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _i2.ColumnDefinition(
          name: 'requestedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'expiration',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'decider',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'choice',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'rationale',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'timestamp',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'signatureJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'resolvedOptionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'metadataJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'updatedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'human_decision_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'human_decision_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'decisionId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'human_decision_work_item_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workItemId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'human_direction',
      dartName: 'HumanDirectionRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'human_direction_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'directionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'directionType',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'targetType',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'targetId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'payloadJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'createdBy',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'assignedTo',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'ackedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'ackedBy',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'startedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'startedBy',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'completedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'completedBy',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'completionSummary',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'rejectedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'rejectedBy',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'rejectionReason',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'supersededAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'supersededByDirectionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'updatedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'metadataJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'human_direction_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'human_direction_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'directionId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'human_direction_target_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'targetType',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'targetId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'human_direction_status_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'status',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'human_direction_created_by_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'createdBy',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'job',
      dartName: 'JobRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'job_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'jobId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workItemId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'jobType',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'requiredRole',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'requiredCapabilitiesJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'priority',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'state',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'dedupeKey',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'activeDedupeKey',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'availableAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'instruction',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'attempt',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'maxAttempts',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'startedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'completedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'executionReferenceJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'workerId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'failureJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'cancelReason',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'job_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'job_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'jobId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'job_work_item_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workItemId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'job_dedupe_key_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'dedupeKey',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'job_active_dedupe_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'activeDedupeKey',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'job_claim',
      dartName: 'JobClaimRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'job_claim_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'claimId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'jobId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'ownerId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'leasedUntil',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'job_claim_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'job_claim_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'claimId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'job_claim_job_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'jobId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'model_execution_record',
      dartName: 'ModelExecutionRecordRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'model_execution_record_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'workItemId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'jobId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'agentExecutionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'role',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'modelId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'provider',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'inputTokens',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'outputTokens',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'totalTokens',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'cachedReadTokens',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'costUsd',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
        _i2.ColumnDefinition(
          name: 'currency',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'startedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'finishedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'success',
          columnType: _i2.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
        ),
        _i2.ColumnDefinition(
          name: 'error',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'escalationIndex',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'taskType',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'model_execution_record_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'model_execution_record_work_item',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workItemId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'model_execution_record_job',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'jobId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'model_execution_record_model_provider',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'modelId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'model_execution_record_started_at',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'startedAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'model_policy',
      dartName: 'ModelPolicyRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'model_policy_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'role',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'chainJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'updatedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'updatedByDecisionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'model_policy_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'model_policy_role_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'role',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'model_policy_version',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'version',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'onboarding_record',
      dartName: 'OnboardingRecordRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'onboarding_record_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'onboardingId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'productId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'currentBaselineRevision',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'pendingClarifications',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'completed',
          columnType: _i2.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'updatedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'onboarding_record_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'onboarding_product_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'productId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'platform_verification',
      dartName: 'PlatformVerificationRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'platform_verification_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'verificationId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'executionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workItemId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'checkName',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'mechanism',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'command',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'capturedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'evidenceKind',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'outputRef',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'detail',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'resultPath',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'platform_verification_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'platform_verification_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'verificationId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'platform_verification_execution_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'executionId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'product',
      dartName: 'ProductRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'product_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'productId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'description',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'manifestVersion',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'state',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'updatedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'product_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'product_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'productId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'product_baseline',
      dartName: 'ProductBaselineRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'product_baseline_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'baselineId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'productId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'revision',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'factsJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'contentHash',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'contentHashVersion',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'supersedesBaselineId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'proposedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'reviewedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'acceptedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'acceptedBy',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'acceptedDecisionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'verifiedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'verifiedBy',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'verificationKind',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'updatedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'product_baseline_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'product_baseline_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'baselineId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'product_baseline_product_revision_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'productId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'revision',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'product_baseline_product_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'productId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'product_credential',
      dartName: 'RepositoryCredentialRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'product_credential_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'credentialId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'productId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'repositoryId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'referenceName',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'publicKey',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'fingerprint',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'algorithm',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'lastVerifiedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'lastVerifiedBy',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'lastFailureReason',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'hostKeyStatus',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'host',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'hostKeyFingerprint',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'hostConfirmedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'hostConfirmedBy',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'revokedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'revokedReason',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'supersedesCredentialId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'product_credential_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'product_credential_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'credentialId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'product_credential_repo_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'repositoryId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'product_credential_product_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'productId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'product_registry_audit',
      dartName: 'ProductRegistryAuditRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'product_registry_audit_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'auditId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'productId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'entityType',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'entityId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'action',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'beforeJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'afterJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'actor',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'timestamp',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'product_registry_audit_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'product_registry_audit_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'auditId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'product_registry_audit_product_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'productId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'product_registry_audit_timestamp_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'timestamp',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'qa_contract',
      dartName: 'QAContractRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'qa_contract_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'contractId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workItemCategory',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'gatesJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'passCriteriaJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'updatedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'evidenceRowsJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'metadataJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'qa_contract_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'qa_contract_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'contractId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'qa_contract_work_item_category_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workItemCategory',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'qa_review_result',
      dartName: 'QaReviewResultRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'qa_review_result_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'reviewExecutionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'revisionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'verdict',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'findingsJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'assessedDimensionsJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'reviewScopeJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'qa_review_result_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'qa_review_result_revision',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'revisionId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'qa_review_result_verdict',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'verdict',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'repository_reference',
      dartName: 'RepositoryReferenceRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'repository_reference_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'repositoryId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'productId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'kind',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'uri',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'provider',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'addedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'repository_reference_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'repository_reference_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'repositoryId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'repository_reference_product_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'productId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'scheduler_event',
      dartName: 'SchedulerEventRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'scheduler_event_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'eventId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'jobId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workItemId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'sequence',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'type',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'occurredAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'payloadJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'scheduler_event_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'scheduler_event_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'eventId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'scheduler_event_job_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'jobId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'scheduler_event_job_sequence_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'jobId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'sequence',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'standing_policy',
      dartName: 'StandingPolicyRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'standing_policy_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'policyId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'productId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'actionsJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'authorisingDecisionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'authorisedBy',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'rationale',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'authorisedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'revokedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'revokedBy',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'revocationDecisionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'revocationReason',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'standing_policy_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'standing_policy_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'policyId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'standing_policy_product_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'productId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'triage_result',
      dartName: 'TriageResultRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'triage_result_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'resultId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'defectId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'recommendedStatus',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'recommendedClassification',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'confidence',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
        _i2.ColumnDefinition(
          name: 'suspectedCategory',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'suspectedComponents',
          columnType: _i2.ColumnType.json,
          isNullable: false,
          dartType: 'List<String>',
        ),
        _i2.ColumnDefinition(
          name: 'reproductionSupported',
          columnType: _i2.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
        ),
        _i2.ColumnDefinition(
          name: 'evidenceUsed',
          columnType: _i2.ColumnType.json,
          isNullable: false,
          dartType: 'List<String>',
        ),
        _i2.ColumnDefinition(
          name: 'clarificationRequired',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'recommendedNextAction',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'possibleDuplicateDefectId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'recommendedWorkItemCategory',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'summary',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'jobId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'executionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'completedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'triage_result_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'result_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'resultId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'triage_result_defect_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'defectId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'triage_result_job_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'jobId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'triage_result_classification_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'recommendedClassification',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'work_item',
      dartName: 'WorkItemRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'work_item_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'workItemId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'productId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'category',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'title',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'description',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'state',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'designContractId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'agentSessionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'qaContractId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'featureRef',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'requirementRef',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'blockingHumanDecisionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'blockingReason',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'artifactRefsJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'metadataJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'updatedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'completedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'terminatedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'work_item_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'work_item_work_item_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workItemId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'work_item_state_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'state',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'work_item_transition',
      dartName: 'WorkItemTransitionRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'work_item_transition_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'transitionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workItemId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'fromState',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'toState',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'trigger',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'actorType',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'actorId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'decisionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'outcome',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'reason',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'guardEvaluationsJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'idempotencyKey',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'occurredAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'work_item_transition_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'work_item_transition_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'transitionId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'work_item_transition_work_item_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workItemId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'work_item_transition_idempotency_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workItemId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'idempotencyKey',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'worker_event',
      dartName: 'WorkerEventRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'worker_event_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'eventId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workerExecutionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workItemId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'sequence',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'type',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'occurredAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'payloadJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'worker_event_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'worker_event_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'eventId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'worker_event_execution_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workerExecutionId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'worker_event_execution_sequence_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workerExecutionId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'sequence',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'worker_execution',
      dartName: 'WorkerExecutionRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'worker_execution_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'workerExecutionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workItemId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'repositoryPath',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'requestedStartingRevision',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'requiredCapabilitiesJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'cleanupPolicy',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workerId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'workspaceId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'agentExecutionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'resultId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'endingRevision',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'cleanupStatus',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'failureCode',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'startedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'endedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'reason',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'version',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'worker_execution_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'worker_execution_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workerExecutionId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'worker_execution_work_item_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workItemId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'worker_registration',
      dartName: 'WorkerRegistrationRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'worker_registration_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'workerId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'poolId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'capabilitiesJson',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'currentLoad',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'maxConcurrency',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'lastHeartbeat',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'artifactCacheJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'platform',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'worker_registration_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'worker_registration_id_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workerId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'worker_result',
      dartName: 'WorkerResultRow',
      schema: 'public',
      module: 'control_plane',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'worker_result_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'workerExecutionId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workItemId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workerId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'workspaceId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'startingRevision',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'endingRevision',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'agentExecutionId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'agentResultStatus',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'verificationId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'verificationPassed',
          columnType: _i2.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _i2.ColumnDefinition(
          name: 'changedFilesJson',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'diffSummary',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'diffRef',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'cleanupStatus',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'failureCode',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'failureDetail',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'startedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'endedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'worker_result_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'worker_result_execution_unique',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workerExecutionId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'worker_result_work_item_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workItemId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    ..._i2.Protocol.targetTableDefinitions,
  ];

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on FormatException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _i3.ArtifactReferenceView) {
      return _i3.ArtifactReferenceView.fromJson(data) as T;
    }
    if (t == _i4.BaselineFactView) {
      return _i4.BaselineFactView.fromJson(data) as T;
    }
    if (t == _i5.ClarificationView) {
      return _i5.ClarificationView.fromJson(data) as T;
    }
    if (t == _i6.CredentialAccessVerificationView) {
      return _i6.CredentialAccessVerificationView.fromJson(data) as T;
    }
    if (t == _i7.AgentEventRow) {
      return _i7.AgentEventRow.fromJson(data) as T;
    }
    if (t == _i8.AgentExecutionRow) {
      return _i8.AgentExecutionRow.fromJson(data) as T;
    }
    if (t == _i9.AgentExecutionRequestRow) {
      return _i9.AgentExecutionRequestRow.fromJson(data) as T;
    }
    if (t == _i10.AgentResultRow) {
      return _i10.AgentResultRow.fromJson(data) as T;
    }
    if (t == _i11.BaselineFactRow) {
      return _i11.BaselineFactRow.fromJson(data) as T;
    }
    if (t == _i12.ClarificationRequestRow) {
      return _i12.ClarificationRequestRow.fromJson(data) as T;
    }
    if (t == _i13.DefectRow) {
      return _i13.DefectRow.fromJson(data) as T;
    }
    if (t == _i14.DefectClarificationRow) {
      return _i14.DefectClarificationRow.fromJson(data) as T;
    }
    if (t == _i15.DefectEventRow) {
      return _i15.DefectEventRow.fromJson(data) as T;
    }
    if (t == _i16.DefectEvidenceRow) {
      return _i16.DefectEvidenceRow.fromJson(data) as T;
    }
    if (t == _i17.DesignFindingRow) {
      return _i17.DesignFindingRow.fromJson(data) as T;
    }
    if (t == _i18.DesignReviewResultRow) {
      return _i18.DesignReviewResultRow.fromJson(data) as T;
    }
    if (t == _i19.DesignRevisionRow) {
      return _i19.DesignRevisionRow.fromJson(data) as T;
    }
    if (t == _i20.DesignRevisionEventRow) {
      return _i20.DesignRevisionEventRow.fromJson(data) as T;
    }
    if (t == _i21.EngineeringReviewResultRow) {
      return _i21.EngineeringReviewResultRow.fromJson(data) as T;
    }
    if (t == _i22.HumanDecisionRow) {
      return _i22.HumanDecisionRow.fromJson(data) as T;
    }
    if (t == _i23.HumanDirectionRow) {
      return _i23.HumanDirectionRow.fromJson(data) as T;
    }
    if (t == _i24.JobRow) {
      return _i24.JobRow.fromJson(data) as T;
    }
    if (t == _i25.JobClaimRow) {
      return _i25.JobClaimRow.fromJson(data) as T;
    }
    if (t == _i26.ModelExecutionRecordRow) {
      return _i26.ModelExecutionRecordRow.fromJson(data) as T;
    }
    if (t == _i27.ModelPolicyRow) {
      return _i27.ModelPolicyRow.fromJson(data) as T;
    }
    if (t == _i28.OnboardingRecordRow) {
      return _i28.OnboardingRecordRow.fromJson(data) as T;
    }
    if (t == _i29.PlatformVerificationRow) {
      return _i29.PlatformVerificationRow.fromJson(data) as T;
    }
    if (t == _i30.ProductRow) {
      return _i30.ProductRow.fromJson(data) as T;
    }
    if (t == _i31.ProductBaselineRow) {
      return _i31.ProductBaselineRow.fromJson(data) as T;
    }
    if (t == _i32.ProductRegistryAuditRow) {
      return _i32.ProductRegistryAuditRow.fromJson(data) as T;
    }
    if (t == _i33.QAContractRow) {
      return _i33.QAContractRow.fromJson(data) as T;
    }
    if (t == _i34.QaReviewResultRow) {
      return _i34.QaReviewResultRow.fromJson(data) as T;
    }
    if (t == _i35.RepositoryCredentialRow) {
      return _i35.RepositoryCredentialRow.fromJson(data) as T;
    }
    if (t == _i36.RepositoryReferenceRow) {
      return _i36.RepositoryReferenceRow.fromJson(data) as T;
    }
    if (t == _i37.SchedulerEventRow) {
      return _i37.SchedulerEventRow.fromJson(data) as T;
    }
    if (t == _i38.StandingPolicyRow) {
      return _i38.StandingPolicyRow.fromJson(data) as T;
    }
    if (t == _i39.TriageResultRow) {
      return _i39.TriageResultRow.fromJson(data) as T;
    }
    if (t == _i40.WorkItemRow) {
      return _i40.WorkItemRow.fromJson(data) as T;
    }
    if (t == _i41.WorkItemTransitionRow) {
      return _i41.WorkItemTransitionRow.fromJson(data) as T;
    }
    if (t == _i42.WorkerEventRow) {
      return _i42.WorkerEventRow.fromJson(data) as T;
    }
    if (t == _i43.WorkerExecutionRow) {
      return _i43.WorkerExecutionRow.fromJson(data) as T;
    }
    if (t == _i44.WorkerRegistrationRow) {
      return _i44.WorkerRegistrationRow.fromJson(data) as T;
    }
    if (t == _i45.WorkerResultRow) {
      return _i45.WorkerResultRow.fromJson(data) as T;
    }
    if (t == _i46.DecisionContextView) {
      return _i46.DecisionContextView.fromJson(data) as T;
    }
    if (t == _i47.DecisionOptionView) {
      return _i47.DecisionOptionView.fromJson(data) as T;
    }
    if (t == _i48.DecisionView) {
      return _i48.DecisionView.fromJson(data) as T;
    }
    if (t == _i49.FeatureRequestSummaryView) {
      return _i49.FeatureRequestSummaryView.fromJson(data) as T;
    }
    if (t == _i50.HumanDirectionAttachmentView) {
      return _i50.HumanDirectionAttachmentView.fromJson(data) as T;
    }
    if (t == _i51.HumanDirectionPayloadView) {
      return _i51.HumanDirectionPayloadView.fromJson(data) as T;
    }
    if (t == _i52.HumanDirectionView) {
      return _i52.HumanDirectionView.fromJson(data) as T;
    }
    if (t == _i53.JobSummaryView) {
      return _i53.JobSummaryView.fromJson(data) as T;
    }
    if (t == _i54.MintedCredentialView) {
      return _i54.MintedCredentialView.fromJson(data) as T;
    }
    if (t == _i55.Overview) {
      return _i55.Overview.fromJson(data) as T;
    }
    if (t == _i56.ProductBaselineView) {
      return _i56.ProductBaselineView.fromJson(data) as T;
    }
    if (t == _i57.ProductContextView) {
      return _i57.ProductContextView.fromJson(data) as T;
    }
    if (t == _i58.ProductDetailView) {
      return _i58.ProductDetailView.fromJson(data) as T;
    }
    if (t == _i59.ProductSummaryView) {
      return _i59.ProductSummaryView.fromJson(data) as T;
    }
    if (t == _i60.ProductView) {
      return _i60.ProductView.fromJson(data) as T;
    }
    if (t == _i61.RepositoryCredentialView) {
      return _i61.RepositoryCredentialView.fromJson(data) as T;
    }
    if (t == _i62.RepositoryReferenceView) {
      return _i62.RepositoryReferenceView.fromJson(data) as T;
    }
    if (t == _i63.ResolveDecisionView) {
      return _i63.ResolveDecisionView.fromJson(data) as T;
    }
    if (t == _i64.StandingPolicyView) {
      return _i64.StandingPolicyView.fromJson(data) as T;
    }
    if (t == _i65.TransitionView) {
      return _i65.TransitionView.fromJson(data) as T;
    }
    if (t == _i66.WorkItemDetailView) {
      return _i66.WorkItemDetailView.fromJson(data) as T;
    }
    if (t == _i67.WorkItemView) {
      return _i67.WorkItemView.fromJson(data) as T;
    }
    if (t == _i1.getType<_i3.ArtifactReferenceView?>()) {
      return (data != null ? _i3.ArtifactReferenceView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i4.BaselineFactView?>()) {
      return (data != null ? _i4.BaselineFactView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.ClarificationView?>()) {
      return (data != null ? _i5.ClarificationView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.CredentialAccessVerificationView?>()) {
      return (data != null
              ? _i6.CredentialAccessVerificationView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i7.AgentEventRow?>()) {
      return (data != null ? _i7.AgentEventRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.AgentExecutionRow?>()) {
      return (data != null ? _i8.AgentExecutionRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.AgentExecutionRequestRow?>()) {
      return (data != null ? _i9.AgentExecutionRequestRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i10.AgentResultRow?>()) {
      return (data != null ? _i10.AgentResultRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i11.BaselineFactRow?>()) {
      return (data != null ? _i11.BaselineFactRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i12.ClarificationRequestRow?>()) {
      return (data != null ? _i12.ClarificationRequestRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i13.DefectRow?>()) {
      return (data != null ? _i13.DefectRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i14.DefectClarificationRow?>()) {
      return (data != null ? _i14.DefectClarificationRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i15.DefectEventRow?>()) {
      return (data != null ? _i15.DefectEventRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i16.DefectEvidenceRow?>()) {
      return (data != null ? _i16.DefectEvidenceRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i17.DesignFindingRow?>()) {
      return (data != null ? _i17.DesignFindingRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i18.DesignReviewResultRow?>()) {
      return (data != null ? _i18.DesignReviewResultRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i19.DesignRevisionRow?>()) {
      return (data != null ? _i19.DesignRevisionRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i20.DesignRevisionEventRow?>()) {
      return (data != null ? _i20.DesignRevisionEventRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i21.EngineeringReviewResultRow?>()) {
      return (data != null
              ? _i21.EngineeringReviewResultRow.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i22.HumanDecisionRow?>()) {
      return (data != null ? _i22.HumanDecisionRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i23.HumanDirectionRow?>()) {
      return (data != null ? _i23.HumanDirectionRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i24.JobRow?>()) {
      return (data != null ? _i24.JobRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i25.JobClaimRow?>()) {
      return (data != null ? _i25.JobClaimRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i26.ModelExecutionRecordRow?>()) {
      return (data != null ? _i26.ModelExecutionRecordRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i27.ModelPolicyRow?>()) {
      return (data != null ? _i27.ModelPolicyRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i28.OnboardingRecordRow?>()) {
      return (data != null ? _i28.OnboardingRecordRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i29.PlatformVerificationRow?>()) {
      return (data != null ? _i29.PlatformVerificationRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i30.ProductRow?>()) {
      return (data != null ? _i30.ProductRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i31.ProductBaselineRow?>()) {
      return (data != null ? _i31.ProductBaselineRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i32.ProductRegistryAuditRow?>()) {
      return (data != null ? _i32.ProductRegistryAuditRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i33.QAContractRow?>()) {
      return (data != null ? _i33.QAContractRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i34.QaReviewResultRow?>()) {
      return (data != null ? _i34.QaReviewResultRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i35.RepositoryCredentialRow?>()) {
      return (data != null ? _i35.RepositoryCredentialRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i36.RepositoryReferenceRow?>()) {
      return (data != null ? _i36.RepositoryReferenceRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i37.SchedulerEventRow?>()) {
      return (data != null ? _i37.SchedulerEventRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i38.StandingPolicyRow?>()) {
      return (data != null ? _i38.StandingPolicyRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i39.TriageResultRow?>()) {
      return (data != null ? _i39.TriageResultRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i40.WorkItemRow?>()) {
      return (data != null ? _i40.WorkItemRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i41.WorkItemTransitionRow?>()) {
      return (data != null ? _i41.WorkItemTransitionRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i42.WorkerEventRow?>()) {
      return (data != null ? _i42.WorkerEventRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i43.WorkerExecutionRow?>()) {
      return (data != null ? _i43.WorkerExecutionRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i44.WorkerRegistrationRow?>()) {
      return (data != null ? _i44.WorkerRegistrationRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i45.WorkerResultRow?>()) {
      return (data != null ? _i45.WorkerResultRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i46.DecisionContextView?>()) {
      return (data != null ? _i46.DecisionContextView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i47.DecisionOptionView?>()) {
      return (data != null ? _i47.DecisionOptionView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i48.DecisionView?>()) {
      return (data != null ? _i48.DecisionView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i49.FeatureRequestSummaryView?>()) {
      return (data != null
              ? _i49.FeatureRequestSummaryView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i50.HumanDirectionAttachmentView?>()) {
      return (data != null
              ? _i50.HumanDirectionAttachmentView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i51.HumanDirectionPayloadView?>()) {
      return (data != null
              ? _i51.HumanDirectionPayloadView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i52.HumanDirectionView?>()) {
      return (data != null ? _i52.HumanDirectionView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i53.JobSummaryView?>()) {
      return (data != null ? _i53.JobSummaryView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i54.MintedCredentialView?>()) {
      return (data != null ? _i54.MintedCredentialView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i55.Overview?>()) {
      return (data != null ? _i55.Overview.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i56.ProductBaselineView?>()) {
      return (data != null ? _i56.ProductBaselineView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i57.ProductContextView?>()) {
      return (data != null ? _i57.ProductContextView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i58.ProductDetailView?>()) {
      return (data != null ? _i58.ProductDetailView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i59.ProductSummaryView?>()) {
      return (data != null ? _i59.ProductSummaryView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i60.ProductView?>()) {
      return (data != null ? _i60.ProductView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i61.RepositoryCredentialView?>()) {
      return (data != null
              ? _i61.RepositoryCredentialView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i62.RepositoryReferenceView?>()) {
      return (data != null ? _i62.RepositoryReferenceView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i63.ResolveDecisionView?>()) {
      return (data != null ? _i63.ResolveDecisionView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i64.StandingPolicyView?>()) {
      return (data != null ? _i64.StandingPolicyView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i65.TransitionView?>()) {
      return (data != null ? _i65.TransitionView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i66.WorkItemDetailView?>()) {
      return (data != null ? _i66.WorkItemDetailView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i67.WorkItemView?>()) {
      return (data != null ? _i67.WorkItemView.fromJson(data) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_i47.DecisionOptionView>) {
      return (data as List)
              .map((e) => deserialize<_i47.DecisionOptionView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i47.DecisionOptionView>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i47.DecisionOptionView>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i3.ArtifactReferenceView>) {
      return (data as List)
              .map((e) => deserialize<_i3.ArtifactReferenceView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i3.ArtifactReferenceView>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i3.ArtifactReferenceView>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i50.HumanDirectionAttachmentView>) {
      return (data as List)
              .map((e) => deserialize<_i50.HumanDirectionAttachmentView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i50.HumanDirectionAttachmentView>?>()) {
      return (data != null
              ? (data as List)
                    .map(
                      (e) => deserialize<_i50.HumanDirectionAttachmentView>(e),
                    )
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i53.JobSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i53.JobSummaryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i4.BaselineFactView>) {
      return (data as List)
              .map((e) => deserialize<_i4.BaselineFactView>(e))
              .toList()
          as T;
    }
    if (t == List<_i62.RepositoryReferenceView>) {
      return (data as List)
              .map((e) => deserialize<_i62.RepositoryReferenceView>(e))
              .toList()
          as T;
    }
    if (t == List<_i56.ProductBaselineView>) {
      return (data as List)
              .map((e) => deserialize<_i56.ProductBaselineView>(e))
              .toList()
          as T;
    }
    if (t == List<_i5.ClarificationView>) {
      return (data as List)
              .map((e) => deserialize<_i5.ClarificationView>(e))
              .toList()
          as T;
    }
    if (t == List<_i61.RepositoryCredentialView>) {
      return (data as List)
              .map((e) => deserialize<_i61.RepositoryCredentialView>(e))
              .toList()
          as T;
    }
    if (t == List<_i64.StandingPolicyView>) {
      return (data as List)
              .map((e) => deserialize<_i64.StandingPolicyView>(e))
              .toList()
          as T;
    }
    if (t == List<_i65.TransitionView>) {
      return (data as List)
              .map((e) => deserialize<_i65.TransitionView>(e))
              .toList()
          as T;
    }
    if (t == Map<String, dynamic>) {
      return (data as Map).map(
            (k, v) => MapEntry(deserialize<String>(k), deserialize<dynamic>(v)),
          )
          as T;
    }
    if (t == List<_i68.WorkItemView>) {
      return (data as List)
              .map((e) => deserialize<_i68.WorkItemView>(e))
              .toList()
          as T;
    }
    if (t == List<_i69.DecisionView>) {
      return (data as List)
              .map((e) => deserialize<_i69.DecisionView>(e))
              .toList()
          as T;
    }
    if (t == List<_i70.HumanDirectionAttachmentView>) {
      return (data as List)
              .map((e) => deserialize<_i70.HumanDirectionAttachmentView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i70.HumanDirectionAttachmentView>?>()) {
      return (data != null
              ? (data as List)
                    .map(
                      (e) => deserialize<_i70.HumanDirectionAttachmentView>(e),
                    )
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i71.HumanDirectionView>) {
      return (data as List)
              .map((e) => deserialize<_i71.HumanDirectionView>(e))
              .toList()
          as T;
    }
    if (t == List<_i72.FeatureRequestSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i72.FeatureRequestSummaryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i73.ProductView>) {
      return (data as List)
              .map((e) => deserialize<_i73.ProductView>(e))
              .toList()
          as T;
    }
    if (t == List<_i74.ProductSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i74.ProductSummaryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i75.BaselineFact>) {
      return (data as List)
              .map((e) => deserialize<_i75.BaselineFact>(e))
              .toList()
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == _i1.getType<List<String>?>()) {
      return (data != null
              ? (data as List).map((e) => deserialize<String>(e)).toList()
              : null)
          as T;
    }
    if (t == List<_i76.JobSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i76.JobSummaryView>(e))
              .toList()
          as T;
    }
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i3.ArtifactReferenceView => 'ArtifactReferenceView',
      _i4.BaselineFactView => 'BaselineFactView',
      _i5.ClarificationView => 'ClarificationView',
      _i6.CredentialAccessVerificationView =>
        'CredentialAccessVerificationView',
      _i7.AgentEventRow => 'AgentEventRow',
      _i8.AgentExecutionRow => 'AgentExecutionRow',
      _i9.AgentExecutionRequestRow => 'AgentExecutionRequestRow',
      _i10.AgentResultRow => 'AgentResultRow',
      _i11.BaselineFactRow => 'BaselineFactRow',
      _i12.ClarificationRequestRow => 'ClarificationRequestRow',
      _i13.DefectRow => 'DefectRow',
      _i14.DefectClarificationRow => 'DefectClarificationRow',
      _i15.DefectEventRow => 'DefectEventRow',
      _i16.DefectEvidenceRow => 'DefectEvidenceRow',
      _i17.DesignFindingRow => 'DesignFindingRow',
      _i18.DesignReviewResultRow => 'DesignReviewResultRow',
      _i19.DesignRevisionRow => 'DesignRevisionRow',
      _i20.DesignRevisionEventRow => 'DesignRevisionEventRow',
      _i21.EngineeringReviewResultRow => 'EngineeringReviewResultRow',
      _i22.HumanDecisionRow => 'HumanDecisionRow',
      _i23.HumanDirectionRow => 'HumanDirectionRow',
      _i24.JobRow => 'JobRow',
      _i25.JobClaimRow => 'JobClaimRow',
      _i26.ModelExecutionRecordRow => 'ModelExecutionRecordRow',
      _i27.ModelPolicyRow => 'ModelPolicyRow',
      _i28.OnboardingRecordRow => 'OnboardingRecordRow',
      _i29.PlatformVerificationRow => 'PlatformVerificationRow',
      _i30.ProductRow => 'ProductRow',
      _i31.ProductBaselineRow => 'ProductBaselineRow',
      _i32.ProductRegistryAuditRow => 'ProductRegistryAuditRow',
      _i33.QAContractRow => 'QAContractRow',
      _i34.QaReviewResultRow => 'QaReviewResultRow',
      _i35.RepositoryCredentialRow => 'RepositoryCredentialRow',
      _i36.RepositoryReferenceRow => 'RepositoryReferenceRow',
      _i37.SchedulerEventRow => 'SchedulerEventRow',
      _i38.StandingPolicyRow => 'StandingPolicyRow',
      _i39.TriageResultRow => 'TriageResultRow',
      _i40.WorkItemRow => 'WorkItemRow',
      _i41.WorkItemTransitionRow => 'WorkItemTransitionRow',
      _i42.WorkerEventRow => 'WorkerEventRow',
      _i43.WorkerExecutionRow => 'WorkerExecutionRow',
      _i44.WorkerRegistrationRow => 'WorkerRegistrationRow',
      _i45.WorkerResultRow => 'WorkerResultRow',
      _i46.DecisionContextView => 'DecisionContextView',
      _i47.DecisionOptionView => 'DecisionOptionView',
      _i48.DecisionView => 'DecisionView',
      _i49.FeatureRequestSummaryView => 'FeatureRequestSummaryView',
      _i50.HumanDirectionAttachmentView => 'HumanDirectionAttachmentView',
      _i51.HumanDirectionPayloadView => 'HumanDirectionPayloadView',
      _i52.HumanDirectionView => 'HumanDirectionView',
      _i53.JobSummaryView => 'JobSummaryView',
      _i54.MintedCredentialView => 'MintedCredentialView',
      _i55.Overview => 'Overview',
      _i56.ProductBaselineView => 'ProductBaselineView',
      _i57.ProductContextView => 'ProductContextView',
      _i58.ProductDetailView => 'ProductDetailView',
      _i59.ProductSummaryView => 'ProductSummaryView',
      _i60.ProductView => 'ProductView',
      _i61.RepositoryCredentialView => 'RepositoryCredentialView',
      _i62.RepositoryReferenceView => 'RepositoryReferenceView',
      _i63.ResolveDecisionView => 'ResolveDecisionView',
      _i64.StandingPolicyView => 'StandingPolicyView',
      _i65.TransitionView => 'TransitionView',
      _i66.WorkItemDetailView => 'WorkItemDetailView',
      _i67.WorkItemView => 'WorkItemView',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst(
        'control_plane.',
        '',
      );
    }

    switch (data) {
      case _i3.ArtifactReferenceView():
        return 'ArtifactReferenceView';
      case _i4.BaselineFactView():
        return 'BaselineFactView';
      case _i5.ClarificationView():
        return 'ClarificationView';
      case _i6.CredentialAccessVerificationView():
        return 'CredentialAccessVerificationView';
      case _i7.AgentEventRow():
        return 'AgentEventRow';
      case _i8.AgentExecutionRow():
        return 'AgentExecutionRow';
      case _i9.AgentExecutionRequestRow():
        return 'AgentExecutionRequestRow';
      case _i10.AgentResultRow():
        return 'AgentResultRow';
      case _i11.BaselineFactRow():
        return 'BaselineFactRow';
      case _i12.ClarificationRequestRow():
        return 'ClarificationRequestRow';
      case _i13.DefectRow():
        return 'DefectRow';
      case _i14.DefectClarificationRow():
        return 'DefectClarificationRow';
      case _i15.DefectEventRow():
        return 'DefectEventRow';
      case _i16.DefectEvidenceRow():
        return 'DefectEvidenceRow';
      case _i17.DesignFindingRow():
        return 'DesignFindingRow';
      case _i18.DesignReviewResultRow():
        return 'DesignReviewResultRow';
      case _i19.DesignRevisionRow():
        return 'DesignRevisionRow';
      case _i20.DesignRevisionEventRow():
        return 'DesignRevisionEventRow';
      case _i21.EngineeringReviewResultRow():
        return 'EngineeringReviewResultRow';
      case _i22.HumanDecisionRow():
        return 'HumanDecisionRow';
      case _i23.HumanDirectionRow():
        return 'HumanDirectionRow';
      case _i24.JobRow():
        return 'JobRow';
      case _i25.JobClaimRow():
        return 'JobClaimRow';
      case _i26.ModelExecutionRecordRow():
        return 'ModelExecutionRecordRow';
      case _i27.ModelPolicyRow():
        return 'ModelPolicyRow';
      case _i28.OnboardingRecordRow():
        return 'OnboardingRecordRow';
      case _i29.PlatformVerificationRow():
        return 'PlatformVerificationRow';
      case _i30.ProductRow():
        return 'ProductRow';
      case _i31.ProductBaselineRow():
        return 'ProductBaselineRow';
      case _i32.ProductRegistryAuditRow():
        return 'ProductRegistryAuditRow';
      case _i33.QAContractRow():
        return 'QAContractRow';
      case _i34.QaReviewResultRow():
        return 'QaReviewResultRow';
      case _i35.RepositoryCredentialRow():
        return 'RepositoryCredentialRow';
      case _i36.RepositoryReferenceRow():
        return 'RepositoryReferenceRow';
      case _i37.SchedulerEventRow():
        return 'SchedulerEventRow';
      case _i38.StandingPolicyRow():
        return 'StandingPolicyRow';
      case _i39.TriageResultRow():
        return 'TriageResultRow';
      case _i40.WorkItemRow():
        return 'WorkItemRow';
      case _i41.WorkItemTransitionRow():
        return 'WorkItemTransitionRow';
      case _i42.WorkerEventRow():
        return 'WorkerEventRow';
      case _i43.WorkerExecutionRow():
        return 'WorkerExecutionRow';
      case _i44.WorkerRegistrationRow():
        return 'WorkerRegistrationRow';
      case _i45.WorkerResultRow():
        return 'WorkerResultRow';
      case _i46.DecisionContextView():
        return 'DecisionContextView';
      case _i47.DecisionOptionView():
        return 'DecisionOptionView';
      case _i48.DecisionView():
        return 'DecisionView';
      case _i49.FeatureRequestSummaryView():
        return 'FeatureRequestSummaryView';
      case _i50.HumanDirectionAttachmentView():
        return 'HumanDirectionAttachmentView';
      case _i51.HumanDirectionPayloadView():
        return 'HumanDirectionPayloadView';
      case _i52.HumanDirectionView():
        return 'HumanDirectionView';
      case _i53.JobSummaryView():
        return 'JobSummaryView';
      case _i54.MintedCredentialView():
        return 'MintedCredentialView';
      case _i55.Overview():
        return 'Overview';
      case _i56.ProductBaselineView():
        return 'ProductBaselineView';
      case _i57.ProductContextView():
        return 'ProductContextView';
      case _i58.ProductDetailView():
        return 'ProductDetailView';
      case _i59.ProductSummaryView():
        return 'ProductSummaryView';
      case _i60.ProductView():
        return 'ProductView';
      case _i61.RepositoryCredentialView():
        return 'RepositoryCredentialView';
      case _i62.RepositoryReferenceView():
        return 'RepositoryReferenceView';
      case _i63.ResolveDecisionView():
        return 'ResolveDecisionView';
      case _i64.StandingPolicyView():
        return 'StandingPolicyView';
      case _i65.TransitionView():
        return 'TransitionView';
      case _i66.WorkItemDetailView():
        return 'WorkItemDetailView';
      case _i67.WorkItemView():
        return 'WorkItemView';
    }
    className = _i2.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'ArtifactReferenceView') {
      return deserialize<_i3.ArtifactReferenceView>(data['data']);
    }
    if (dataClassName == 'BaselineFactView') {
      return deserialize<_i4.BaselineFactView>(data['data']);
    }
    if (dataClassName == 'ClarificationView') {
      return deserialize<_i5.ClarificationView>(data['data']);
    }
    if (dataClassName == 'CredentialAccessVerificationView') {
      return deserialize<_i6.CredentialAccessVerificationView>(data['data']);
    }
    if (dataClassName == 'AgentEventRow') {
      return deserialize<_i7.AgentEventRow>(data['data']);
    }
    if (dataClassName == 'AgentExecutionRow') {
      return deserialize<_i8.AgentExecutionRow>(data['data']);
    }
    if (dataClassName == 'AgentExecutionRequestRow') {
      return deserialize<_i9.AgentExecutionRequestRow>(data['data']);
    }
    if (dataClassName == 'AgentResultRow') {
      return deserialize<_i10.AgentResultRow>(data['data']);
    }
    if (dataClassName == 'BaselineFactRow') {
      return deserialize<_i11.BaselineFactRow>(data['data']);
    }
    if (dataClassName == 'ClarificationRequestRow') {
      return deserialize<_i12.ClarificationRequestRow>(data['data']);
    }
    if (dataClassName == 'DefectRow') {
      return deserialize<_i13.DefectRow>(data['data']);
    }
    if (dataClassName == 'DefectClarificationRow') {
      return deserialize<_i14.DefectClarificationRow>(data['data']);
    }
    if (dataClassName == 'DefectEventRow') {
      return deserialize<_i15.DefectEventRow>(data['data']);
    }
    if (dataClassName == 'DefectEvidenceRow') {
      return deserialize<_i16.DefectEvidenceRow>(data['data']);
    }
    if (dataClassName == 'DesignFindingRow') {
      return deserialize<_i17.DesignFindingRow>(data['data']);
    }
    if (dataClassName == 'DesignReviewResultRow') {
      return deserialize<_i18.DesignReviewResultRow>(data['data']);
    }
    if (dataClassName == 'DesignRevisionRow') {
      return deserialize<_i19.DesignRevisionRow>(data['data']);
    }
    if (dataClassName == 'DesignRevisionEventRow') {
      return deserialize<_i20.DesignRevisionEventRow>(data['data']);
    }
    if (dataClassName == 'EngineeringReviewResultRow') {
      return deserialize<_i21.EngineeringReviewResultRow>(data['data']);
    }
    if (dataClassName == 'HumanDecisionRow') {
      return deserialize<_i22.HumanDecisionRow>(data['data']);
    }
    if (dataClassName == 'HumanDirectionRow') {
      return deserialize<_i23.HumanDirectionRow>(data['data']);
    }
    if (dataClassName == 'JobRow') {
      return deserialize<_i24.JobRow>(data['data']);
    }
    if (dataClassName == 'JobClaimRow') {
      return deserialize<_i25.JobClaimRow>(data['data']);
    }
    if (dataClassName == 'ModelExecutionRecordRow') {
      return deserialize<_i26.ModelExecutionRecordRow>(data['data']);
    }
    if (dataClassName == 'ModelPolicyRow') {
      return deserialize<_i27.ModelPolicyRow>(data['data']);
    }
    if (dataClassName == 'OnboardingRecordRow') {
      return deserialize<_i28.OnboardingRecordRow>(data['data']);
    }
    if (dataClassName == 'PlatformVerificationRow') {
      return deserialize<_i29.PlatformVerificationRow>(data['data']);
    }
    if (dataClassName == 'ProductRow') {
      return deserialize<_i30.ProductRow>(data['data']);
    }
    if (dataClassName == 'ProductBaselineRow') {
      return deserialize<_i31.ProductBaselineRow>(data['data']);
    }
    if (dataClassName == 'ProductRegistryAuditRow') {
      return deserialize<_i32.ProductRegistryAuditRow>(data['data']);
    }
    if (dataClassName == 'QAContractRow') {
      return deserialize<_i33.QAContractRow>(data['data']);
    }
    if (dataClassName == 'QaReviewResultRow') {
      return deserialize<_i34.QaReviewResultRow>(data['data']);
    }
    if (dataClassName == 'RepositoryCredentialRow') {
      return deserialize<_i35.RepositoryCredentialRow>(data['data']);
    }
    if (dataClassName == 'RepositoryReferenceRow') {
      return deserialize<_i36.RepositoryReferenceRow>(data['data']);
    }
    if (dataClassName == 'SchedulerEventRow') {
      return deserialize<_i37.SchedulerEventRow>(data['data']);
    }
    if (dataClassName == 'StandingPolicyRow') {
      return deserialize<_i38.StandingPolicyRow>(data['data']);
    }
    if (dataClassName == 'TriageResultRow') {
      return deserialize<_i39.TriageResultRow>(data['data']);
    }
    if (dataClassName == 'WorkItemRow') {
      return deserialize<_i40.WorkItemRow>(data['data']);
    }
    if (dataClassName == 'WorkItemTransitionRow') {
      return deserialize<_i41.WorkItemTransitionRow>(data['data']);
    }
    if (dataClassName == 'WorkerEventRow') {
      return deserialize<_i42.WorkerEventRow>(data['data']);
    }
    if (dataClassName == 'WorkerExecutionRow') {
      return deserialize<_i43.WorkerExecutionRow>(data['data']);
    }
    if (dataClassName == 'WorkerRegistrationRow') {
      return deserialize<_i44.WorkerRegistrationRow>(data['data']);
    }
    if (dataClassName == 'WorkerResultRow') {
      return deserialize<_i45.WorkerResultRow>(data['data']);
    }
    if (dataClassName == 'DecisionContextView') {
      return deserialize<_i46.DecisionContextView>(data['data']);
    }
    if (dataClassName == 'DecisionOptionView') {
      return deserialize<_i47.DecisionOptionView>(data['data']);
    }
    if (dataClassName == 'DecisionView') {
      return deserialize<_i48.DecisionView>(data['data']);
    }
    if (dataClassName == 'FeatureRequestSummaryView') {
      return deserialize<_i49.FeatureRequestSummaryView>(data['data']);
    }
    if (dataClassName == 'HumanDirectionAttachmentView') {
      return deserialize<_i50.HumanDirectionAttachmentView>(data['data']);
    }
    if (dataClassName == 'HumanDirectionPayloadView') {
      return deserialize<_i51.HumanDirectionPayloadView>(data['data']);
    }
    if (dataClassName == 'HumanDirectionView') {
      return deserialize<_i52.HumanDirectionView>(data['data']);
    }
    if (dataClassName == 'JobSummaryView') {
      return deserialize<_i53.JobSummaryView>(data['data']);
    }
    if (dataClassName == 'MintedCredentialView') {
      return deserialize<_i54.MintedCredentialView>(data['data']);
    }
    if (dataClassName == 'Overview') {
      return deserialize<_i55.Overview>(data['data']);
    }
    if (dataClassName == 'ProductBaselineView') {
      return deserialize<_i56.ProductBaselineView>(data['data']);
    }
    if (dataClassName == 'ProductContextView') {
      return deserialize<_i57.ProductContextView>(data['data']);
    }
    if (dataClassName == 'ProductDetailView') {
      return deserialize<_i58.ProductDetailView>(data['data']);
    }
    if (dataClassName == 'ProductSummaryView') {
      return deserialize<_i59.ProductSummaryView>(data['data']);
    }
    if (dataClassName == 'ProductView') {
      return deserialize<_i60.ProductView>(data['data']);
    }
    if (dataClassName == 'RepositoryCredentialView') {
      return deserialize<_i61.RepositoryCredentialView>(data['data']);
    }
    if (dataClassName == 'RepositoryReferenceView') {
      return deserialize<_i62.RepositoryReferenceView>(data['data']);
    }
    if (dataClassName == 'ResolveDecisionView') {
      return deserialize<_i63.ResolveDecisionView>(data['data']);
    }
    if (dataClassName == 'StandingPolicyView') {
      return deserialize<_i64.StandingPolicyView>(data['data']);
    }
    if (dataClassName == 'TransitionView') {
      return deserialize<_i65.TransitionView>(data['data']);
    }
    if (dataClassName == 'WorkItemDetailView') {
      return deserialize<_i66.WorkItemDetailView>(data['data']);
    }
    if (dataClassName == 'WorkItemView') {
      return deserialize<_i67.WorkItemView>(data['data']);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _i2.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  @override
  _i1.Table? getTableForType(Type t) {
    {
      var table = _i2.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _i7.AgentEventRow:
        return _i7.AgentEventRow.t;
      case _i8.AgentExecutionRow:
        return _i8.AgentExecutionRow.t;
      case _i9.AgentExecutionRequestRow:
        return _i9.AgentExecutionRequestRow.t;
      case _i10.AgentResultRow:
        return _i10.AgentResultRow.t;
      case _i11.BaselineFactRow:
        return _i11.BaselineFactRow.t;
      case _i12.ClarificationRequestRow:
        return _i12.ClarificationRequestRow.t;
      case _i13.DefectRow:
        return _i13.DefectRow.t;
      case _i14.DefectClarificationRow:
        return _i14.DefectClarificationRow.t;
      case _i15.DefectEventRow:
        return _i15.DefectEventRow.t;
      case _i16.DefectEvidenceRow:
        return _i16.DefectEvidenceRow.t;
      case _i17.DesignFindingRow:
        return _i17.DesignFindingRow.t;
      case _i18.DesignReviewResultRow:
        return _i18.DesignReviewResultRow.t;
      case _i19.DesignRevisionRow:
        return _i19.DesignRevisionRow.t;
      case _i20.DesignRevisionEventRow:
        return _i20.DesignRevisionEventRow.t;
      case _i21.EngineeringReviewResultRow:
        return _i21.EngineeringReviewResultRow.t;
      case _i22.HumanDecisionRow:
        return _i22.HumanDecisionRow.t;
      case _i23.HumanDirectionRow:
        return _i23.HumanDirectionRow.t;
      case _i24.JobRow:
        return _i24.JobRow.t;
      case _i25.JobClaimRow:
        return _i25.JobClaimRow.t;
      case _i26.ModelExecutionRecordRow:
        return _i26.ModelExecutionRecordRow.t;
      case _i27.ModelPolicyRow:
        return _i27.ModelPolicyRow.t;
      case _i28.OnboardingRecordRow:
        return _i28.OnboardingRecordRow.t;
      case _i29.PlatformVerificationRow:
        return _i29.PlatformVerificationRow.t;
      case _i30.ProductRow:
        return _i30.ProductRow.t;
      case _i31.ProductBaselineRow:
        return _i31.ProductBaselineRow.t;
      case _i32.ProductRegistryAuditRow:
        return _i32.ProductRegistryAuditRow.t;
      case _i33.QAContractRow:
        return _i33.QAContractRow.t;
      case _i34.QaReviewResultRow:
        return _i34.QaReviewResultRow.t;
      case _i35.RepositoryCredentialRow:
        return _i35.RepositoryCredentialRow.t;
      case _i36.RepositoryReferenceRow:
        return _i36.RepositoryReferenceRow.t;
      case _i37.SchedulerEventRow:
        return _i37.SchedulerEventRow.t;
      case _i38.StandingPolicyRow:
        return _i38.StandingPolicyRow.t;
      case _i39.TriageResultRow:
        return _i39.TriageResultRow.t;
      case _i40.WorkItemRow:
        return _i40.WorkItemRow.t;
      case _i41.WorkItemTransitionRow:
        return _i41.WorkItemTransitionRow.t;
      case _i42.WorkerEventRow:
        return _i42.WorkerEventRow.t;
      case _i43.WorkerExecutionRow:
        return _i43.WorkerExecutionRow.t;
      case _i44.WorkerRegistrationRow:
        return _i44.WorkerRegistrationRow.t;
      case _i45.WorkerResultRow:
        return _i45.WorkerResultRow.t;
    }
    return null;
  }

  @override
  List<_i2.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'control_plane';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _i2.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
