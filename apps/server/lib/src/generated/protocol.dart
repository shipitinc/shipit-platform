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
import 'agent_artifact_view.dart' as _i3;
import 'agent_claimed_check_view.dart' as _i4;
import 'agent_diagnostics_view.dart' as _i5;
import 'agent_event_view.dart' as _i6;
import 'agent_execution_inspection_view.dart' as _i7;
import 'agent_execution_list_view.dart' as _i8;
import 'agent_execution_record_view.dart' as _i9;
import 'agent_result_view.dart' as _i10;
import 'agent_workspace_view.dart' as _i11;
import 'artifact_cache_entry_view.dart' as _i12;
import 'artifact_reference_view.dart' as _i13;
import 'baseline_fact_view.dart' as _i14;
import 'capability_spec_view.dart' as _i15;
import 'changed_file_view.dart' as _i16;
import 'clarification_view.dart' as _i17;
import 'credential_access_verification_view.dart' as _i18;
import 'database/agent_event.dart' as _i19;
import 'database/agent_execution.dart' as _i20;
import 'database/agent_execution_request.dart' as _i21;
import 'database/agent_result.dart' as _i22;
import 'database/baseline_fact.dart' as _i23;
import 'database/clarification_request.dart' as _i24;
import 'database/defect.dart' as _i25;
import 'database/defect_clarification.dart' as _i26;
import 'database/defect_event.dart' as _i27;
import 'database/defect_evidence.dart' as _i28;
import 'database/design_finding.dart' as _i29;
import 'database/design_review_result.dart' as _i30;
import 'database/design_revision.dart' as _i31;
import 'database/design_revision_event.dart' as _i32;
import 'database/engineering_review_result.dart' as _i33;
import 'database/human_decision.dart' as _i34;
import 'database/human_direction.dart' as _i35;
import 'database/job.dart' as _i36;
import 'database/job_claim.dart' as _i37;
import 'database/model_execution_record.dart' as _i38;
import 'database/model_policy.dart' as _i39;
import 'database/onboarding_record.dart' as _i40;
import 'database/platform_verification.dart' as _i41;
import 'database/product.dart' as _i42;
import 'database/product_baseline.dart' as _i43;
import 'database/product_registry_audit.dart' as _i44;
import 'database/qa_contract.dart' as _i45;
import 'database/qa_review_result.dart' as _i46;
import 'database/repository_credential.dart' as _i47;
import 'database/repository_reference.dart' as _i48;
import 'database/scheduler_event.dart' as _i49;
import 'database/standing_policy.dart' as _i50;
import 'database/triage_result.dart' as _i51;
import 'database/work_item.dart' as _i52;
import 'database/work_item_transition.dart' as _i53;
import 'database/worker_event.dart' as _i54;
import 'database/worker_execution.dart' as _i55;
import 'database/worker_registration.dart' as _i56;
import 'database/worker_result.dart' as _i57;
import 'decision_context_view.dart' as _i58;
import 'decision_option_view.dart' as _i59;
import 'decision_view.dart' as _i60;
import 'defect_clarification_request_view.dart' as _i61;
import 'defect_clarification_view.dart' as _i62;
import 'defect_created_view.dart' as _i63;
import 'defect_detail_view.dart' as _i64;
import 'defect_event_view.dart' as _i65;
import 'defect_evidence_view.dart' as _i66;
import 'defect_inspection_view.dart' as _i67;
import 'defect_list_view.dart' as _i68;
import 'defect_summary_view.dart' as _i69;
import 'diagnostic_entry_view.dart' as _i70;
import 'feature_request_created_view.dart' as _i71;
import 'feature_request_summary_view.dart' as _i72;
import 'fix_verification_view.dart' as _i73;
import 'health_status_view.dart' as _i74;
import 'human_direction_attachment_view.dart' as _i75;
import 'human_direction_payload_view.dart' as _i76;
import 'human_direction_view.dart' as _i77;
import 'job_claim_view.dart' as _i78;
import 'job_inspection_view.dart' as _i79;
import 'job_list_view.dart' as _i80;
import 'job_record_view.dart' as _i81;
import 'job_summary_view.dart' as _i82;
import 'minted_credential_view.dart' as _i83;
import 'model_execution_list_view.dart' as _i84;
import 'model_execution_record_view.dart' as _i85;
import 'model_policy_list_view.dart' as _i86;
import 'model_policy_view.dart' as _i87;
import 'model_stats_group_view.dart' as _i88;
import 'model_stats_view.dart' as _i89;
import 'model_step_view.dart' as _i90;
import 'overview.dart' as _i91;
import 'platform_verification_view.dart' as _i92;
import 'product_baseline_view.dart' as _i93;
import 'product_context_view.dart' as _i94;
import 'product_detail_view.dart' as _i95;
import 'product_summary_view.dart' as _i96;
import 'product_view.dart' as _i97;
import 'provider_health_view.dart' as _i98;
import 'provider_status_view.dart' as _i99;
import 'repository_credential_view.dart' as _i100;
import 'repository_reference_added_view.dart' as _i101;
import 'repository_reference_view.dart' as _i102;
import 'resolve_decision_view.dart' as _i103;
import 'resource_usage_view.dart' as _i104;
import 'scheduler_event_view.dart' as _i105;
import 'standing_policy_view.dart' as _i106;
import 'transition_view.dart' as _i107;
import 'triage_result_view.dart' as _i108;
import 'work_item_detail_view.dart' as _i109;
import 'work_item_view.dart' as _i110;
import 'worker_event_view.dart' as _i111;
import 'worker_execution_inspection_view.dart' as _i112;
import 'worker_execution_list_view.dart' as _i113;
import 'worker_execution_result_view.dart' as _i114;
import 'worker_execution_view.dart' as _i115;
import 'worker_list_view.dart' as _i116;
import 'worker_registration_view.dart' as _i117;
import 'package:control_plane_server/src/generated/work_item_view.dart'
    as _i118;
import 'package:control_plane_server/src/generated/decision_view.dart' as _i119;
import 'package:control_plane_server/src/generated/human_direction_attachment_view.dart'
    as _i120;
import 'package:control_plane_server/src/generated/human_direction_view.dart'
    as _i121;
import 'package:control_plane_server/src/generated/feature_request_summary_view.dart'
    as _i122;
import 'package:control_plane_server/src/generated/product_view.dart' as _i123;
import 'package:control_plane_server/src/generated/product_summary_view.dart'
    as _i124;
import 'package:platform_contracts/src/types/baseline_fact.dart' as _i125;
import 'package:control_plane_server/src/generated/job_summary_view.dart'
    as _i126;
export 'agent_artifact_view.dart';
export 'agent_claimed_check_view.dart';
export 'agent_diagnostics_view.dart';
export 'agent_event_view.dart';
export 'agent_execution_inspection_view.dart';
export 'agent_execution_list_view.dart';
export 'agent_execution_record_view.dart';
export 'agent_result_view.dart';
export 'agent_workspace_view.dart';
export 'artifact_cache_entry_view.dart';
export 'artifact_reference_view.dart';
export 'baseline_fact_view.dart';
export 'capability_spec_view.dart';
export 'changed_file_view.dart';
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
export 'defect_clarification_request_view.dart';
export 'defect_clarification_view.dart';
export 'defect_created_view.dart';
export 'defect_detail_view.dart';
export 'defect_event_view.dart';
export 'defect_evidence_view.dart';
export 'defect_inspection_view.dart';
export 'defect_list_view.dart';
export 'defect_summary_view.dart';
export 'diagnostic_entry_view.dart';
export 'feature_request_created_view.dart';
export 'feature_request_summary_view.dart';
export 'fix_verification_view.dart';
export 'health_status_view.dart';
export 'human_direction_attachment_view.dart';
export 'human_direction_payload_view.dart';
export 'human_direction_view.dart';
export 'job_claim_view.dart';
export 'job_inspection_view.dart';
export 'job_list_view.dart';
export 'job_record_view.dart';
export 'job_summary_view.dart';
export 'minted_credential_view.dart';
export 'model_execution_list_view.dart';
export 'model_execution_record_view.dart';
export 'model_policy_list_view.dart';
export 'model_policy_view.dart';
export 'model_stats_group_view.dart';
export 'model_stats_view.dart';
export 'model_step_view.dart';
export 'overview.dart';
export 'platform_verification_view.dart';
export 'product_baseline_view.dart';
export 'product_context_view.dart';
export 'product_detail_view.dart';
export 'product_summary_view.dart';
export 'product_view.dart';
export 'provider_health_view.dart';
export 'provider_status_view.dart';
export 'repository_credential_view.dart';
export 'repository_reference_added_view.dart';
export 'repository_reference_view.dart';
export 'resolve_decision_view.dart';
export 'resource_usage_view.dart';
export 'scheduler_event_view.dart';
export 'standing_policy_view.dart';
export 'transition_view.dart';
export 'triage_result_view.dart';
export 'work_item_detail_view.dart';
export 'work_item_view.dart';
export 'worker_event_view.dart';
export 'worker_execution_inspection_view.dart';
export 'worker_execution_list_view.dart';
export 'worker_execution_result_view.dart';
export 'worker_execution_view.dart';
export 'worker_list_view.dart';
export 'worker_registration_view.dart';

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

    if (t == _i3.AgentArtifactView) {
      return _i3.AgentArtifactView.fromJson(data) as T;
    }
    if (t == _i4.AgentClaimedCheckView) {
      return _i4.AgentClaimedCheckView.fromJson(data) as T;
    }
    if (t == _i5.AgentDiagnosticsView) {
      return _i5.AgentDiagnosticsView.fromJson(data) as T;
    }
    if (t == _i6.AgentEventView) {
      return _i6.AgentEventView.fromJson(data) as T;
    }
    if (t == _i7.AgentExecutionInspectionView) {
      return _i7.AgentExecutionInspectionView.fromJson(data) as T;
    }
    if (t == _i8.AgentExecutionListView) {
      return _i8.AgentExecutionListView.fromJson(data) as T;
    }
    if (t == _i9.AgentExecutionRecordView) {
      return _i9.AgentExecutionRecordView.fromJson(data) as T;
    }
    if (t == _i10.AgentResultView) {
      return _i10.AgentResultView.fromJson(data) as T;
    }
    if (t == _i11.AgentWorkspaceView) {
      return _i11.AgentWorkspaceView.fromJson(data) as T;
    }
    if (t == _i12.ArtifactCacheEntryView) {
      return _i12.ArtifactCacheEntryView.fromJson(data) as T;
    }
    if (t == _i13.ArtifactReferenceView) {
      return _i13.ArtifactReferenceView.fromJson(data) as T;
    }
    if (t == _i14.BaselineFactView) {
      return _i14.BaselineFactView.fromJson(data) as T;
    }
    if (t == _i15.CapabilitySpecView) {
      return _i15.CapabilitySpecView.fromJson(data) as T;
    }
    if (t == _i16.ChangedFileView) {
      return _i16.ChangedFileView.fromJson(data) as T;
    }
    if (t == _i17.ClarificationView) {
      return _i17.ClarificationView.fromJson(data) as T;
    }
    if (t == _i18.CredentialAccessVerificationView) {
      return _i18.CredentialAccessVerificationView.fromJson(data) as T;
    }
    if (t == _i19.AgentEventRow) {
      return _i19.AgentEventRow.fromJson(data) as T;
    }
    if (t == _i20.AgentExecutionRow) {
      return _i20.AgentExecutionRow.fromJson(data) as T;
    }
    if (t == _i21.AgentExecutionRequestRow) {
      return _i21.AgentExecutionRequestRow.fromJson(data) as T;
    }
    if (t == _i22.AgentResultRow) {
      return _i22.AgentResultRow.fromJson(data) as T;
    }
    if (t == _i23.BaselineFactRow) {
      return _i23.BaselineFactRow.fromJson(data) as T;
    }
    if (t == _i24.ClarificationRequestRow) {
      return _i24.ClarificationRequestRow.fromJson(data) as T;
    }
    if (t == _i25.DefectRow) {
      return _i25.DefectRow.fromJson(data) as T;
    }
    if (t == _i26.DefectClarificationRow) {
      return _i26.DefectClarificationRow.fromJson(data) as T;
    }
    if (t == _i27.DefectEventRow) {
      return _i27.DefectEventRow.fromJson(data) as T;
    }
    if (t == _i28.DefectEvidenceRow) {
      return _i28.DefectEvidenceRow.fromJson(data) as T;
    }
    if (t == _i29.DesignFindingRow) {
      return _i29.DesignFindingRow.fromJson(data) as T;
    }
    if (t == _i30.DesignReviewResultRow) {
      return _i30.DesignReviewResultRow.fromJson(data) as T;
    }
    if (t == _i31.DesignRevisionRow) {
      return _i31.DesignRevisionRow.fromJson(data) as T;
    }
    if (t == _i32.DesignRevisionEventRow) {
      return _i32.DesignRevisionEventRow.fromJson(data) as T;
    }
    if (t == _i33.EngineeringReviewResultRow) {
      return _i33.EngineeringReviewResultRow.fromJson(data) as T;
    }
    if (t == _i34.HumanDecisionRow) {
      return _i34.HumanDecisionRow.fromJson(data) as T;
    }
    if (t == _i35.HumanDirectionRow) {
      return _i35.HumanDirectionRow.fromJson(data) as T;
    }
    if (t == _i36.JobRow) {
      return _i36.JobRow.fromJson(data) as T;
    }
    if (t == _i37.JobClaimRow) {
      return _i37.JobClaimRow.fromJson(data) as T;
    }
    if (t == _i38.ModelExecutionRecordRow) {
      return _i38.ModelExecutionRecordRow.fromJson(data) as T;
    }
    if (t == _i39.ModelPolicyRow) {
      return _i39.ModelPolicyRow.fromJson(data) as T;
    }
    if (t == _i40.OnboardingRecordRow) {
      return _i40.OnboardingRecordRow.fromJson(data) as T;
    }
    if (t == _i41.PlatformVerificationRow) {
      return _i41.PlatformVerificationRow.fromJson(data) as T;
    }
    if (t == _i42.ProductRow) {
      return _i42.ProductRow.fromJson(data) as T;
    }
    if (t == _i43.ProductBaselineRow) {
      return _i43.ProductBaselineRow.fromJson(data) as T;
    }
    if (t == _i44.ProductRegistryAuditRow) {
      return _i44.ProductRegistryAuditRow.fromJson(data) as T;
    }
    if (t == _i45.QAContractRow) {
      return _i45.QAContractRow.fromJson(data) as T;
    }
    if (t == _i46.QaReviewResultRow) {
      return _i46.QaReviewResultRow.fromJson(data) as T;
    }
    if (t == _i47.RepositoryCredentialRow) {
      return _i47.RepositoryCredentialRow.fromJson(data) as T;
    }
    if (t == _i48.RepositoryReferenceRow) {
      return _i48.RepositoryReferenceRow.fromJson(data) as T;
    }
    if (t == _i49.SchedulerEventRow) {
      return _i49.SchedulerEventRow.fromJson(data) as T;
    }
    if (t == _i50.StandingPolicyRow) {
      return _i50.StandingPolicyRow.fromJson(data) as T;
    }
    if (t == _i51.TriageResultRow) {
      return _i51.TriageResultRow.fromJson(data) as T;
    }
    if (t == _i52.WorkItemRow) {
      return _i52.WorkItemRow.fromJson(data) as T;
    }
    if (t == _i53.WorkItemTransitionRow) {
      return _i53.WorkItemTransitionRow.fromJson(data) as T;
    }
    if (t == _i54.WorkerEventRow) {
      return _i54.WorkerEventRow.fromJson(data) as T;
    }
    if (t == _i55.WorkerExecutionRow) {
      return _i55.WorkerExecutionRow.fromJson(data) as T;
    }
    if (t == _i56.WorkerRegistrationRow) {
      return _i56.WorkerRegistrationRow.fromJson(data) as T;
    }
    if (t == _i57.WorkerResultRow) {
      return _i57.WorkerResultRow.fromJson(data) as T;
    }
    if (t == _i58.DecisionContextView) {
      return _i58.DecisionContextView.fromJson(data) as T;
    }
    if (t == _i59.DecisionOptionView) {
      return _i59.DecisionOptionView.fromJson(data) as T;
    }
    if (t == _i60.DecisionView) {
      return _i60.DecisionView.fromJson(data) as T;
    }
    if (t == _i61.DefectClarificationRequestView) {
      return _i61.DefectClarificationRequestView.fromJson(data) as T;
    }
    if (t == _i62.DefectClarificationView) {
      return _i62.DefectClarificationView.fromJson(data) as T;
    }
    if (t == _i63.DefectCreatedView) {
      return _i63.DefectCreatedView.fromJson(data) as T;
    }
    if (t == _i64.DefectDetailView) {
      return _i64.DefectDetailView.fromJson(data) as T;
    }
    if (t == _i65.DefectEventView) {
      return _i65.DefectEventView.fromJson(data) as T;
    }
    if (t == _i66.DefectEvidenceView) {
      return _i66.DefectEvidenceView.fromJson(data) as T;
    }
    if (t == _i67.DefectInspectionView) {
      return _i67.DefectInspectionView.fromJson(data) as T;
    }
    if (t == _i68.DefectListView) {
      return _i68.DefectListView.fromJson(data) as T;
    }
    if (t == _i69.DefectSummaryView) {
      return _i69.DefectSummaryView.fromJson(data) as T;
    }
    if (t == _i70.DiagnosticEntryView) {
      return _i70.DiagnosticEntryView.fromJson(data) as T;
    }
    if (t == _i71.FeatureRequestCreatedView) {
      return _i71.FeatureRequestCreatedView.fromJson(data) as T;
    }
    if (t == _i72.FeatureRequestSummaryView) {
      return _i72.FeatureRequestSummaryView.fromJson(data) as T;
    }
    if (t == _i73.FixVerificationView) {
      return _i73.FixVerificationView.fromJson(data) as T;
    }
    if (t == _i74.HealthStatusView) {
      return _i74.HealthStatusView.fromJson(data) as T;
    }
    if (t == _i75.HumanDirectionAttachmentView) {
      return _i75.HumanDirectionAttachmentView.fromJson(data) as T;
    }
    if (t == _i76.HumanDirectionPayloadView) {
      return _i76.HumanDirectionPayloadView.fromJson(data) as T;
    }
    if (t == _i77.HumanDirectionView) {
      return _i77.HumanDirectionView.fromJson(data) as T;
    }
    if (t == _i78.JobClaimView) {
      return _i78.JobClaimView.fromJson(data) as T;
    }
    if (t == _i79.JobInspectionView) {
      return _i79.JobInspectionView.fromJson(data) as T;
    }
    if (t == _i80.JobListView) {
      return _i80.JobListView.fromJson(data) as T;
    }
    if (t == _i81.JobRecordView) {
      return _i81.JobRecordView.fromJson(data) as T;
    }
    if (t == _i82.JobSummaryView) {
      return _i82.JobSummaryView.fromJson(data) as T;
    }
    if (t == _i83.MintedCredentialView) {
      return _i83.MintedCredentialView.fromJson(data) as T;
    }
    if (t == _i84.ModelExecutionListView) {
      return _i84.ModelExecutionListView.fromJson(data) as T;
    }
    if (t == _i85.ModelExecutionRecordView) {
      return _i85.ModelExecutionRecordView.fromJson(data) as T;
    }
    if (t == _i86.ModelPolicyListView) {
      return _i86.ModelPolicyListView.fromJson(data) as T;
    }
    if (t == _i87.ModelPolicyView) {
      return _i87.ModelPolicyView.fromJson(data) as T;
    }
    if (t == _i88.ModelStatsGroupView) {
      return _i88.ModelStatsGroupView.fromJson(data) as T;
    }
    if (t == _i89.ModelStatsView) {
      return _i89.ModelStatsView.fromJson(data) as T;
    }
    if (t == _i90.ModelStepView) {
      return _i90.ModelStepView.fromJson(data) as T;
    }
    if (t == _i91.Overview) {
      return _i91.Overview.fromJson(data) as T;
    }
    if (t == _i92.PlatformVerificationView) {
      return _i92.PlatformVerificationView.fromJson(data) as T;
    }
    if (t == _i93.ProductBaselineView) {
      return _i93.ProductBaselineView.fromJson(data) as T;
    }
    if (t == _i94.ProductContextView) {
      return _i94.ProductContextView.fromJson(data) as T;
    }
    if (t == _i95.ProductDetailView) {
      return _i95.ProductDetailView.fromJson(data) as T;
    }
    if (t == _i96.ProductSummaryView) {
      return _i96.ProductSummaryView.fromJson(data) as T;
    }
    if (t == _i97.ProductView) {
      return _i97.ProductView.fromJson(data) as T;
    }
    if (t == _i98.ProviderHealthView) {
      return _i98.ProviderHealthView.fromJson(data) as T;
    }
    if (t == _i99.ProviderStatusView) {
      return _i99.ProviderStatusView.fromJson(data) as T;
    }
    if (t == _i100.RepositoryCredentialView) {
      return _i100.RepositoryCredentialView.fromJson(data) as T;
    }
    if (t == _i101.RepositoryReferenceAddedView) {
      return _i101.RepositoryReferenceAddedView.fromJson(data) as T;
    }
    if (t == _i102.RepositoryReferenceView) {
      return _i102.RepositoryReferenceView.fromJson(data) as T;
    }
    if (t == _i103.ResolveDecisionView) {
      return _i103.ResolveDecisionView.fromJson(data) as T;
    }
    if (t == _i104.ResourceUsageView) {
      return _i104.ResourceUsageView.fromJson(data) as T;
    }
    if (t == _i105.SchedulerEventView) {
      return _i105.SchedulerEventView.fromJson(data) as T;
    }
    if (t == _i106.StandingPolicyView) {
      return _i106.StandingPolicyView.fromJson(data) as T;
    }
    if (t == _i107.TransitionView) {
      return _i107.TransitionView.fromJson(data) as T;
    }
    if (t == _i108.TriageResultView) {
      return _i108.TriageResultView.fromJson(data) as T;
    }
    if (t == _i109.WorkItemDetailView) {
      return _i109.WorkItemDetailView.fromJson(data) as T;
    }
    if (t == _i110.WorkItemView) {
      return _i110.WorkItemView.fromJson(data) as T;
    }
    if (t == _i111.WorkerEventView) {
      return _i111.WorkerEventView.fromJson(data) as T;
    }
    if (t == _i112.WorkerExecutionInspectionView) {
      return _i112.WorkerExecutionInspectionView.fromJson(data) as T;
    }
    if (t == _i113.WorkerExecutionListView) {
      return _i113.WorkerExecutionListView.fromJson(data) as T;
    }
    if (t == _i114.WorkerExecutionResultView) {
      return _i114.WorkerExecutionResultView.fromJson(data) as T;
    }
    if (t == _i115.WorkerExecutionView) {
      return _i115.WorkerExecutionView.fromJson(data) as T;
    }
    if (t == _i116.WorkerListView) {
      return _i116.WorkerListView.fromJson(data) as T;
    }
    if (t == _i117.WorkerRegistrationView) {
      return _i117.WorkerRegistrationView.fromJson(data) as T;
    }
    if (t == _i1.getType<_i3.AgentArtifactView?>()) {
      return (data != null ? _i3.AgentArtifactView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.AgentClaimedCheckView?>()) {
      return (data != null ? _i4.AgentClaimedCheckView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i5.AgentDiagnosticsView?>()) {
      return (data != null ? _i5.AgentDiagnosticsView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i6.AgentEventView?>()) {
      return (data != null ? _i6.AgentEventView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.AgentExecutionInspectionView?>()) {
      return (data != null
              ? _i7.AgentExecutionInspectionView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i8.AgentExecutionListView?>()) {
      return (data != null ? _i8.AgentExecutionListView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i9.AgentExecutionRecordView?>()) {
      return (data != null ? _i9.AgentExecutionRecordView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i10.AgentResultView?>()) {
      return (data != null ? _i10.AgentResultView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i11.AgentWorkspaceView?>()) {
      return (data != null ? _i11.AgentWorkspaceView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i12.ArtifactCacheEntryView?>()) {
      return (data != null ? _i12.ArtifactCacheEntryView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i13.ArtifactReferenceView?>()) {
      return (data != null ? _i13.ArtifactReferenceView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i14.BaselineFactView?>()) {
      return (data != null ? _i14.BaselineFactView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i15.CapabilitySpecView?>()) {
      return (data != null ? _i15.CapabilitySpecView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i16.ChangedFileView?>()) {
      return (data != null ? _i16.ChangedFileView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i17.ClarificationView?>()) {
      return (data != null ? _i17.ClarificationView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i18.CredentialAccessVerificationView?>()) {
      return (data != null
              ? _i18.CredentialAccessVerificationView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i19.AgentEventRow?>()) {
      return (data != null ? _i19.AgentEventRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i20.AgentExecutionRow?>()) {
      return (data != null ? _i20.AgentExecutionRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i21.AgentExecutionRequestRow?>()) {
      return (data != null
              ? _i21.AgentExecutionRequestRow.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i22.AgentResultRow?>()) {
      return (data != null ? _i22.AgentResultRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i23.BaselineFactRow?>()) {
      return (data != null ? _i23.BaselineFactRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i24.ClarificationRequestRow?>()) {
      return (data != null ? _i24.ClarificationRequestRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i25.DefectRow?>()) {
      return (data != null ? _i25.DefectRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i26.DefectClarificationRow?>()) {
      return (data != null ? _i26.DefectClarificationRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i27.DefectEventRow?>()) {
      return (data != null ? _i27.DefectEventRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i28.DefectEvidenceRow?>()) {
      return (data != null ? _i28.DefectEvidenceRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i29.DesignFindingRow?>()) {
      return (data != null ? _i29.DesignFindingRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i30.DesignReviewResultRow?>()) {
      return (data != null ? _i30.DesignReviewResultRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i31.DesignRevisionRow?>()) {
      return (data != null ? _i31.DesignRevisionRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i32.DesignRevisionEventRow?>()) {
      return (data != null ? _i32.DesignRevisionEventRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i33.EngineeringReviewResultRow?>()) {
      return (data != null
              ? _i33.EngineeringReviewResultRow.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i34.HumanDecisionRow?>()) {
      return (data != null ? _i34.HumanDecisionRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i35.HumanDirectionRow?>()) {
      return (data != null ? _i35.HumanDirectionRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i36.JobRow?>()) {
      return (data != null ? _i36.JobRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i37.JobClaimRow?>()) {
      return (data != null ? _i37.JobClaimRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i38.ModelExecutionRecordRow?>()) {
      return (data != null ? _i38.ModelExecutionRecordRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i39.ModelPolicyRow?>()) {
      return (data != null ? _i39.ModelPolicyRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i40.OnboardingRecordRow?>()) {
      return (data != null ? _i40.OnboardingRecordRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i41.PlatformVerificationRow?>()) {
      return (data != null ? _i41.PlatformVerificationRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i42.ProductRow?>()) {
      return (data != null ? _i42.ProductRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i43.ProductBaselineRow?>()) {
      return (data != null ? _i43.ProductBaselineRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i44.ProductRegistryAuditRow?>()) {
      return (data != null ? _i44.ProductRegistryAuditRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i45.QAContractRow?>()) {
      return (data != null ? _i45.QAContractRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i46.QaReviewResultRow?>()) {
      return (data != null ? _i46.QaReviewResultRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i47.RepositoryCredentialRow?>()) {
      return (data != null ? _i47.RepositoryCredentialRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i48.RepositoryReferenceRow?>()) {
      return (data != null ? _i48.RepositoryReferenceRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i49.SchedulerEventRow?>()) {
      return (data != null ? _i49.SchedulerEventRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i50.StandingPolicyRow?>()) {
      return (data != null ? _i50.StandingPolicyRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i51.TriageResultRow?>()) {
      return (data != null ? _i51.TriageResultRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i52.WorkItemRow?>()) {
      return (data != null ? _i52.WorkItemRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i53.WorkItemTransitionRow?>()) {
      return (data != null ? _i53.WorkItemTransitionRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i54.WorkerEventRow?>()) {
      return (data != null ? _i54.WorkerEventRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i55.WorkerExecutionRow?>()) {
      return (data != null ? _i55.WorkerExecutionRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i56.WorkerRegistrationRow?>()) {
      return (data != null ? _i56.WorkerRegistrationRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i57.WorkerResultRow?>()) {
      return (data != null ? _i57.WorkerResultRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i58.DecisionContextView?>()) {
      return (data != null ? _i58.DecisionContextView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i59.DecisionOptionView?>()) {
      return (data != null ? _i59.DecisionOptionView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i60.DecisionView?>()) {
      return (data != null ? _i60.DecisionView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i61.DefectClarificationRequestView?>()) {
      return (data != null
              ? _i61.DefectClarificationRequestView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i62.DefectClarificationView?>()) {
      return (data != null ? _i62.DefectClarificationView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i63.DefectCreatedView?>()) {
      return (data != null ? _i63.DefectCreatedView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i64.DefectDetailView?>()) {
      return (data != null ? _i64.DefectDetailView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i65.DefectEventView?>()) {
      return (data != null ? _i65.DefectEventView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i66.DefectEvidenceView?>()) {
      return (data != null ? _i66.DefectEvidenceView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i67.DefectInspectionView?>()) {
      return (data != null ? _i67.DefectInspectionView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i68.DefectListView?>()) {
      return (data != null ? _i68.DefectListView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i69.DefectSummaryView?>()) {
      return (data != null ? _i69.DefectSummaryView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i70.DiagnosticEntryView?>()) {
      return (data != null ? _i70.DiagnosticEntryView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i71.FeatureRequestCreatedView?>()) {
      return (data != null
              ? _i71.FeatureRequestCreatedView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i72.FeatureRequestSummaryView?>()) {
      return (data != null
              ? _i72.FeatureRequestSummaryView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i73.FixVerificationView?>()) {
      return (data != null ? _i73.FixVerificationView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i74.HealthStatusView?>()) {
      return (data != null ? _i74.HealthStatusView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i75.HumanDirectionAttachmentView?>()) {
      return (data != null
              ? _i75.HumanDirectionAttachmentView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i76.HumanDirectionPayloadView?>()) {
      return (data != null
              ? _i76.HumanDirectionPayloadView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i77.HumanDirectionView?>()) {
      return (data != null ? _i77.HumanDirectionView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i78.JobClaimView?>()) {
      return (data != null ? _i78.JobClaimView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i79.JobInspectionView?>()) {
      return (data != null ? _i79.JobInspectionView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i80.JobListView?>()) {
      return (data != null ? _i80.JobListView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i81.JobRecordView?>()) {
      return (data != null ? _i81.JobRecordView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i82.JobSummaryView?>()) {
      return (data != null ? _i82.JobSummaryView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i83.MintedCredentialView?>()) {
      return (data != null ? _i83.MintedCredentialView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i84.ModelExecutionListView?>()) {
      return (data != null ? _i84.ModelExecutionListView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i85.ModelExecutionRecordView?>()) {
      return (data != null
              ? _i85.ModelExecutionRecordView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i86.ModelPolicyListView?>()) {
      return (data != null ? _i86.ModelPolicyListView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i87.ModelPolicyView?>()) {
      return (data != null ? _i87.ModelPolicyView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i88.ModelStatsGroupView?>()) {
      return (data != null ? _i88.ModelStatsGroupView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i89.ModelStatsView?>()) {
      return (data != null ? _i89.ModelStatsView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i90.ModelStepView?>()) {
      return (data != null ? _i90.ModelStepView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i91.Overview?>()) {
      return (data != null ? _i91.Overview.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i92.PlatformVerificationView?>()) {
      return (data != null
              ? _i92.PlatformVerificationView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i93.ProductBaselineView?>()) {
      return (data != null ? _i93.ProductBaselineView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i94.ProductContextView?>()) {
      return (data != null ? _i94.ProductContextView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i95.ProductDetailView?>()) {
      return (data != null ? _i95.ProductDetailView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i96.ProductSummaryView?>()) {
      return (data != null ? _i96.ProductSummaryView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i97.ProductView?>()) {
      return (data != null ? _i97.ProductView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i98.ProviderHealthView?>()) {
      return (data != null ? _i98.ProviderHealthView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i99.ProviderStatusView?>()) {
      return (data != null ? _i99.ProviderStatusView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i100.RepositoryCredentialView?>()) {
      return (data != null
              ? _i100.RepositoryCredentialView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i101.RepositoryReferenceAddedView?>()) {
      return (data != null
              ? _i101.RepositoryReferenceAddedView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i102.RepositoryReferenceView?>()) {
      return (data != null
              ? _i102.RepositoryReferenceView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i103.ResolveDecisionView?>()) {
      return (data != null ? _i103.ResolveDecisionView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i104.ResourceUsageView?>()) {
      return (data != null ? _i104.ResourceUsageView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i105.SchedulerEventView?>()) {
      return (data != null ? _i105.SchedulerEventView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i106.StandingPolicyView?>()) {
      return (data != null ? _i106.StandingPolicyView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i107.TransitionView?>()) {
      return (data != null ? _i107.TransitionView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i108.TriageResultView?>()) {
      return (data != null ? _i108.TriageResultView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i109.WorkItemDetailView?>()) {
      return (data != null ? _i109.WorkItemDetailView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i110.WorkItemView?>()) {
      return (data != null ? _i110.WorkItemView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i111.WorkerEventView?>()) {
      return (data != null ? _i111.WorkerEventView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i112.WorkerExecutionInspectionView?>()) {
      return (data != null
              ? _i112.WorkerExecutionInspectionView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i113.WorkerExecutionListView?>()) {
      return (data != null
              ? _i113.WorkerExecutionListView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i114.WorkerExecutionResultView?>()) {
      return (data != null
              ? _i114.WorkerExecutionResultView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i115.WorkerExecutionView?>()) {
      return (data != null ? _i115.WorkerExecutionView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i116.WorkerListView?>()) {
      return (data != null ? _i116.WorkerListView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i117.WorkerRegistrationView?>()) {
      return (data != null ? _i117.WorkerRegistrationView.fromJson(data) : null)
          as T;
    }
    if (t == List<_i70.DiagnosticEntryView>) {
      return (data as List)
              .map((e) => deserialize<_i70.DiagnosticEntryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i6.AgentEventView>) {
      return (data as List)
              .map((e) => deserialize<_i6.AgentEventView>(e))
              .toList()
          as T;
    }
    if (t == List<_i92.PlatformVerificationView>) {
      return (data as List)
              .map((e) => deserialize<_i92.PlatformVerificationView>(e))
              .toList()
          as T;
    }
    if (t == List<_i9.AgentExecutionRecordView>) {
      return (data as List)
              .map((e) => deserialize<_i9.AgentExecutionRecordView>(e))
              .toList()
          as T;
    }
    if (t == List<_i3.AgentArtifactView>) {
      return (data as List)
              .map((e) => deserialize<_i3.AgentArtifactView>(e))
              .toList()
          as T;
    }
    if (t == List<_i16.ChangedFileView>) {
      return (data as List)
              .map((e) => deserialize<_i16.ChangedFileView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i16.ChangedFileView>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i16.ChangedFileView>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i4.AgentClaimedCheckView>) {
      return (data as List)
              .map((e) => deserialize<_i4.AgentClaimedCheckView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i4.AgentClaimedCheckView>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i4.AgentClaimedCheckView>(e))
                    .toList()
              : null)
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
    if (t == Map<String, String>) {
      return (data as Map).map(
            (k, v) => MapEntry(deserialize<String>(k), deserialize<String>(v)),
          )
          as T;
    }
    if (t == _i1.getType<Map<String, String>?>()) {
      return (data != null
              ? (data as Map).map(
                  (k, v) =>
                      MapEntry(deserialize<String>(k), deserialize<String>(v)),
                )
              : null)
          as T;
    }
    if (t == List<_i59.DecisionOptionView>) {
      return (data as List)
              .map((e) => deserialize<_i59.DecisionOptionView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i59.DecisionOptionView>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i59.DecisionOptionView>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i13.ArtifactReferenceView>) {
      return (data as List)
              .map((e) => deserialize<_i13.ArtifactReferenceView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i13.ArtifactReferenceView>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i13.ArtifactReferenceView>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i66.DefectEvidenceView>) {
      return (data as List)
              .map((e) => deserialize<_i66.DefectEvidenceView>(e))
              .toList()
          as T;
    }
    if (t == List<_i62.DefectClarificationView>) {
      return (data as List)
              .map((e) => deserialize<_i62.DefectClarificationView>(e))
              .toList()
          as T;
    }
    if (t == List<_i65.DefectEventView>) {
      return (data as List)
              .map((e) => deserialize<_i65.DefectEventView>(e))
              .toList()
          as T;
    }
    if (t == List<_i69.DefectSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i69.DefectSummaryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i75.HumanDirectionAttachmentView>) {
      return (data as List)
              .map((e) => deserialize<_i75.HumanDirectionAttachmentView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i75.HumanDirectionAttachmentView>?>()) {
      return (data != null
              ? (data as List)
                    .map(
                      (e) => deserialize<_i75.HumanDirectionAttachmentView>(e),
                    )
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i105.SchedulerEventView>) {
      return (data as List)
              .map((e) => deserialize<_i105.SchedulerEventView>(e))
              .toList()
          as T;
    }
    if (t == List<_i81.JobRecordView>) {
      return (data as List)
              .map((e) => deserialize<_i81.JobRecordView>(e))
              .toList()
          as T;
    }
    if (t == List<_i85.ModelExecutionRecordView>) {
      return (data as List)
              .map((e) => deserialize<_i85.ModelExecutionRecordView>(e))
              .toList()
          as T;
    }
    if (t == List<_i87.ModelPolicyView>) {
      return (data as List)
              .map((e) => deserialize<_i87.ModelPolicyView>(e))
              .toList()
          as T;
    }
    if (t == List<_i90.ModelStepView>) {
      return (data as List)
              .map((e) => deserialize<_i90.ModelStepView>(e))
              .toList()
          as T;
    }
    if (t == List<_i88.ModelStatsGroupView>) {
      return (data as List)
              .map((e) => deserialize<_i88.ModelStatsGroupView>(e))
              .toList()
          as T;
    }
    if (t == List<_i82.JobSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i82.JobSummaryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i14.BaselineFactView>) {
      return (data as List)
              .map((e) => deserialize<_i14.BaselineFactView>(e))
              .toList()
          as T;
    }
    if (t == List<_i102.RepositoryReferenceView>) {
      return (data as List)
              .map((e) => deserialize<_i102.RepositoryReferenceView>(e))
              .toList()
          as T;
    }
    if (t == List<_i93.ProductBaselineView>) {
      return (data as List)
              .map((e) => deserialize<_i93.ProductBaselineView>(e))
              .toList()
          as T;
    }
    if (t == List<_i17.ClarificationView>) {
      return (data as List)
              .map((e) => deserialize<_i17.ClarificationView>(e))
              .toList()
          as T;
    }
    if (t == List<_i100.RepositoryCredentialView>) {
      return (data as List)
              .map((e) => deserialize<_i100.RepositoryCredentialView>(e))
              .toList()
          as T;
    }
    if (t == List<_i106.StandingPolicyView>) {
      return (data as List)
              .map((e) => deserialize<_i106.StandingPolicyView>(e))
              .toList()
          as T;
    }
    if (t == List<_i99.ProviderStatusView>) {
      return (data as List)
              .map((e) => deserialize<_i99.ProviderStatusView>(e))
              .toList()
          as T;
    }
    if (t == List<_i61.DefectClarificationRequestView>) {
      return (data as List)
              .map((e) => deserialize<_i61.DefectClarificationRequestView>(e))
              .toList()
          as T;
    }
    if (t == List<_i107.TransitionView>) {
      return (data as List)
              .map((e) => deserialize<_i107.TransitionView>(e))
              .toList()
          as T;
    }
    if (t == List<_i111.WorkerEventView>) {
      return (data as List)
              .map((e) => deserialize<_i111.WorkerEventView>(e))
              .toList()
          as T;
    }
    if (t == List<_i115.WorkerExecutionView>) {
      return (data as List)
              .map((e) => deserialize<_i115.WorkerExecutionView>(e))
              .toList()
          as T;
    }
    if (t == List<_i117.WorkerRegistrationView>) {
      return (data as List)
              .map((e) => deserialize<_i117.WorkerRegistrationView>(e))
              .toList()
          as T;
    }
    if (t == Map<String, _i15.CapabilitySpecView>) {
      return (data as Map).map(
            (k, v) => MapEntry(
              deserialize<String>(k),
              deserialize<_i15.CapabilitySpecView>(v),
            ),
          )
          as T;
    }
    if (t == Map<String, _i12.ArtifactCacheEntryView>) {
      return (data as Map).map(
            (k, v) => MapEntry(
              deserialize<String>(k),
              deserialize<_i12.ArtifactCacheEntryView>(v),
            ),
          )
          as T;
    }
    if (t == _i1.getType<Map<String, _i12.ArtifactCacheEntryView>?>()) {
      return (data != null
              ? (data as Map).map(
                  (k, v) => MapEntry(
                    deserialize<String>(k),
                    deserialize<_i12.ArtifactCacheEntryView>(v),
                  ),
                )
              : null)
          as T;
    }
    if (t == List<_i118.WorkItemView>) {
      return (data as List)
              .map((e) => deserialize<_i118.WorkItemView>(e))
              .toList()
          as T;
    }
    if (t == List<_i119.DecisionView>) {
      return (data as List)
              .map((e) => deserialize<_i119.DecisionView>(e))
              .toList()
          as T;
    }
    if (t == List<_i120.HumanDirectionAttachmentView>) {
      return (data as List)
              .map((e) => deserialize<_i120.HumanDirectionAttachmentView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i120.HumanDirectionAttachmentView>?>()) {
      return (data != null
              ? (data as List)
                    .map(
                      (e) => deserialize<_i120.HumanDirectionAttachmentView>(e),
                    )
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i121.HumanDirectionView>) {
      return (data as List)
              .map((e) => deserialize<_i121.HumanDirectionView>(e))
              .toList()
          as T;
    }
    if (t == List<_i122.FeatureRequestSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i122.FeatureRequestSummaryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i123.ProductView>) {
      return (data as List)
              .map((e) => deserialize<_i123.ProductView>(e))
              .toList()
          as T;
    }
    if (t == List<_i124.ProductSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i124.ProductSummaryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i125.BaselineFact>) {
      return (data as List)
              .map((e) => deserialize<_i125.BaselineFact>(e))
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
    if (t == List<_i126.JobSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i126.JobSummaryView>(e))
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
      _i3.AgentArtifactView => 'AgentArtifactView',
      _i4.AgentClaimedCheckView => 'AgentClaimedCheckView',
      _i5.AgentDiagnosticsView => 'AgentDiagnosticsView',
      _i6.AgentEventView => 'AgentEventView',
      _i7.AgentExecutionInspectionView => 'AgentExecutionInspectionView',
      _i8.AgentExecutionListView => 'AgentExecutionListView',
      _i9.AgentExecutionRecordView => 'AgentExecutionRecordView',
      _i10.AgentResultView => 'AgentResultView',
      _i11.AgentWorkspaceView => 'AgentWorkspaceView',
      _i12.ArtifactCacheEntryView => 'ArtifactCacheEntryView',
      _i13.ArtifactReferenceView => 'ArtifactReferenceView',
      _i14.BaselineFactView => 'BaselineFactView',
      _i15.CapabilitySpecView => 'CapabilitySpecView',
      _i16.ChangedFileView => 'ChangedFileView',
      _i17.ClarificationView => 'ClarificationView',
      _i18.CredentialAccessVerificationView =>
        'CredentialAccessVerificationView',
      _i19.AgentEventRow => 'AgentEventRow',
      _i20.AgentExecutionRow => 'AgentExecutionRow',
      _i21.AgentExecutionRequestRow => 'AgentExecutionRequestRow',
      _i22.AgentResultRow => 'AgentResultRow',
      _i23.BaselineFactRow => 'BaselineFactRow',
      _i24.ClarificationRequestRow => 'ClarificationRequestRow',
      _i25.DefectRow => 'DefectRow',
      _i26.DefectClarificationRow => 'DefectClarificationRow',
      _i27.DefectEventRow => 'DefectEventRow',
      _i28.DefectEvidenceRow => 'DefectEvidenceRow',
      _i29.DesignFindingRow => 'DesignFindingRow',
      _i30.DesignReviewResultRow => 'DesignReviewResultRow',
      _i31.DesignRevisionRow => 'DesignRevisionRow',
      _i32.DesignRevisionEventRow => 'DesignRevisionEventRow',
      _i33.EngineeringReviewResultRow => 'EngineeringReviewResultRow',
      _i34.HumanDecisionRow => 'HumanDecisionRow',
      _i35.HumanDirectionRow => 'HumanDirectionRow',
      _i36.JobRow => 'JobRow',
      _i37.JobClaimRow => 'JobClaimRow',
      _i38.ModelExecutionRecordRow => 'ModelExecutionRecordRow',
      _i39.ModelPolicyRow => 'ModelPolicyRow',
      _i40.OnboardingRecordRow => 'OnboardingRecordRow',
      _i41.PlatformVerificationRow => 'PlatformVerificationRow',
      _i42.ProductRow => 'ProductRow',
      _i43.ProductBaselineRow => 'ProductBaselineRow',
      _i44.ProductRegistryAuditRow => 'ProductRegistryAuditRow',
      _i45.QAContractRow => 'QAContractRow',
      _i46.QaReviewResultRow => 'QaReviewResultRow',
      _i47.RepositoryCredentialRow => 'RepositoryCredentialRow',
      _i48.RepositoryReferenceRow => 'RepositoryReferenceRow',
      _i49.SchedulerEventRow => 'SchedulerEventRow',
      _i50.StandingPolicyRow => 'StandingPolicyRow',
      _i51.TriageResultRow => 'TriageResultRow',
      _i52.WorkItemRow => 'WorkItemRow',
      _i53.WorkItemTransitionRow => 'WorkItemTransitionRow',
      _i54.WorkerEventRow => 'WorkerEventRow',
      _i55.WorkerExecutionRow => 'WorkerExecutionRow',
      _i56.WorkerRegistrationRow => 'WorkerRegistrationRow',
      _i57.WorkerResultRow => 'WorkerResultRow',
      _i58.DecisionContextView => 'DecisionContextView',
      _i59.DecisionOptionView => 'DecisionOptionView',
      _i60.DecisionView => 'DecisionView',
      _i61.DefectClarificationRequestView => 'DefectClarificationRequestView',
      _i62.DefectClarificationView => 'DefectClarificationView',
      _i63.DefectCreatedView => 'DefectCreatedView',
      _i64.DefectDetailView => 'DefectDetailView',
      _i65.DefectEventView => 'DefectEventView',
      _i66.DefectEvidenceView => 'DefectEvidenceView',
      _i67.DefectInspectionView => 'DefectInspectionView',
      _i68.DefectListView => 'DefectListView',
      _i69.DefectSummaryView => 'DefectSummaryView',
      _i70.DiagnosticEntryView => 'DiagnosticEntryView',
      _i71.FeatureRequestCreatedView => 'FeatureRequestCreatedView',
      _i72.FeatureRequestSummaryView => 'FeatureRequestSummaryView',
      _i73.FixVerificationView => 'FixVerificationView',
      _i74.HealthStatusView => 'HealthStatusView',
      _i75.HumanDirectionAttachmentView => 'HumanDirectionAttachmentView',
      _i76.HumanDirectionPayloadView => 'HumanDirectionPayloadView',
      _i77.HumanDirectionView => 'HumanDirectionView',
      _i78.JobClaimView => 'JobClaimView',
      _i79.JobInspectionView => 'JobInspectionView',
      _i80.JobListView => 'JobListView',
      _i81.JobRecordView => 'JobRecordView',
      _i82.JobSummaryView => 'JobSummaryView',
      _i83.MintedCredentialView => 'MintedCredentialView',
      _i84.ModelExecutionListView => 'ModelExecutionListView',
      _i85.ModelExecutionRecordView => 'ModelExecutionRecordView',
      _i86.ModelPolicyListView => 'ModelPolicyListView',
      _i87.ModelPolicyView => 'ModelPolicyView',
      _i88.ModelStatsGroupView => 'ModelStatsGroupView',
      _i89.ModelStatsView => 'ModelStatsView',
      _i90.ModelStepView => 'ModelStepView',
      _i91.Overview => 'Overview',
      _i92.PlatformVerificationView => 'PlatformVerificationView',
      _i93.ProductBaselineView => 'ProductBaselineView',
      _i94.ProductContextView => 'ProductContextView',
      _i95.ProductDetailView => 'ProductDetailView',
      _i96.ProductSummaryView => 'ProductSummaryView',
      _i97.ProductView => 'ProductView',
      _i98.ProviderHealthView => 'ProviderHealthView',
      _i99.ProviderStatusView => 'ProviderStatusView',
      _i100.RepositoryCredentialView => 'RepositoryCredentialView',
      _i101.RepositoryReferenceAddedView => 'RepositoryReferenceAddedView',
      _i102.RepositoryReferenceView => 'RepositoryReferenceView',
      _i103.ResolveDecisionView => 'ResolveDecisionView',
      _i104.ResourceUsageView => 'ResourceUsageView',
      _i105.SchedulerEventView => 'SchedulerEventView',
      _i106.StandingPolicyView => 'StandingPolicyView',
      _i107.TransitionView => 'TransitionView',
      _i108.TriageResultView => 'TriageResultView',
      _i109.WorkItemDetailView => 'WorkItemDetailView',
      _i110.WorkItemView => 'WorkItemView',
      _i111.WorkerEventView => 'WorkerEventView',
      _i112.WorkerExecutionInspectionView => 'WorkerExecutionInspectionView',
      _i113.WorkerExecutionListView => 'WorkerExecutionListView',
      _i114.WorkerExecutionResultView => 'WorkerExecutionResultView',
      _i115.WorkerExecutionView => 'WorkerExecutionView',
      _i116.WorkerListView => 'WorkerListView',
      _i117.WorkerRegistrationView => 'WorkerRegistrationView',
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
      case _i3.AgentArtifactView():
        return 'AgentArtifactView';
      case _i4.AgentClaimedCheckView():
        return 'AgentClaimedCheckView';
      case _i5.AgentDiagnosticsView():
        return 'AgentDiagnosticsView';
      case _i6.AgentEventView():
        return 'AgentEventView';
      case _i7.AgentExecutionInspectionView():
        return 'AgentExecutionInspectionView';
      case _i8.AgentExecutionListView():
        return 'AgentExecutionListView';
      case _i9.AgentExecutionRecordView():
        return 'AgentExecutionRecordView';
      case _i10.AgentResultView():
        return 'AgentResultView';
      case _i11.AgentWorkspaceView():
        return 'AgentWorkspaceView';
      case _i12.ArtifactCacheEntryView():
        return 'ArtifactCacheEntryView';
      case _i13.ArtifactReferenceView():
        return 'ArtifactReferenceView';
      case _i14.BaselineFactView():
        return 'BaselineFactView';
      case _i15.CapabilitySpecView():
        return 'CapabilitySpecView';
      case _i16.ChangedFileView():
        return 'ChangedFileView';
      case _i17.ClarificationView():
        return 'ClarificationView';
      case _i18.CredentialAccessVerificationView():
        return 'CredentialAccessVerificationView';
      case _i19.AgentEventRow():
        return 'AgentEventRow';
      case _i20.AgentExecutionRow():
        return 'AgentExecutionRow';
      case _i21.AgentExecutionRequestRow():
        return 'AgentExecutionRequestRow';
      case _i22.AgentResultRow():
        return 'AgentResultRow';
      case _i23.BaselineFactRow():
        return 'BaselineFactRow';
      case _i24.ClarificationRequestRow():
        return 'ClarificationRequestRow';
      case _i25.DefectRow():
        return 'DefectRow';
      case _i26.DefectClarificationRow():
        return 'DefectClarificationRow';
      case _i27.DefectEventRow():
        return 'DefectEventRow';
      case _i28.DefectEvidenceRow():
        return 'DefectEvidenceRow';
      case _i29.DesignFindingRow():
        return 'DesignFindingRow';
      case _i30.DesignReviewResultRow():
        return 'DesignReviewResultRow';
      case _i31.DesignRevisionRow():
        return 'DesignRevisionRow';
      case _i32.DesignRevisionEventRow():
        return 'DesignRevisionEventRow';
      case _i33.EngineeringReviewResultRow():
        return 'EngineeringReviewResultRow';
      case _i34.HumanDecisionRow():
        return 'HumanDecisionRow';
      case _i35.HumanDirectionRow():
        return 'HumanDirectionRow';
      case _i36.JobRow():
        return 'JobRow';
      case _i37.JobClaimRow():
        return 'JobClaimRow';
      case _i38.ModelExecutionRecordRow():
        return 'ModelExecutionRecordRow';
      case _i39.ModelPolicyRow():
        return 'ModelPolicyRow';
      case _i40.OnboardingRecordRow():
        return 'OnboardingRecordRow';
      case _i41.PlatformVerificationRow():
        return 'PlatformVerificationRow';
      case _i42.ProductRow():
        return 'ProductRow';
      case _i43.ProductBaselineRow():
        return 'ProductBaselineRow';
      case _i44.ProductRegistryAuditRow():
        return 'ProductRegistryAuditRow';
      case _i45.QAContractRow():
        return 'QAContractRow';
      case _i46.QaReviewResultRow():
        return 'QaReviewResultRow';
      case _i47.RepositoryCredentialRow():
        return 'RepositoryCredentialRow';
      case _i48.RepositoryReferenceRow():
        return 'RepositoryReferenceRow';
      case _i49.SchedulerEventRow():
        return 'SchedulerEventRow';
      case _i50.StandingPolicyRow():
        return 'StandingPolicyRow';
      case _i51.TriageResultRow():
        return 'TriageResultRow';
      case _i52.WorkItemRow():
        return 'WorkItemRow';
      case _i53.WorkItemTransitionRow():
        return 'WorkItemTransitionRow';
      case _i54.WorkerEventRow():
        return 'WorkerEventRow';
      case _i55.WorkerExecutionRow():
        return 'WorkerExecutionRow';
      case _i56.WorkerRegistrationRow():
        return 'WorkerRegistrationRow';
      case _i57.WorkerResultRow():
        return 'WorkerResultRow';
      case _i58.DecisionContextView():
        return 'DecisionContextView';
      case _i59.DecisionOptionView():
        return 'DecisionOptionView';
      case _i60.DecisionView():
        return 'DecisionView';
      case _i61.DefectClarificationRequestView():
        return 'DefectClarificationRequestView';
      case _i62.DefectClarificationView():
        return 'DefectClarificationView';
      case _i63.DefectCreatedView():
        return 'DefectCreatedView';
      case _i64.DefectDetailView():
        return 'DefectDetailView';
      case _i65.DefectEventView():
        return 'DefectEventView';
      case _i66.DefectEvidenceView():
        return 'DefectEvidenceView';
      case _i67.DefectInspectionView():
        return 'DefectInspectionView';
      case _i68.DefectListView():
        return 'DefectListView';
      case _i69.DefectSummaryView():
        return 'DefectSummaryView';
      case _i70.DiagnosticEntryView():
        return 'DiagnosticEntryView';
      case _i71.FeatureRequestCreatedView():
        return 'FeatureRequestCreatedView';
      case _i72.FeatureRequestSummaryView():
        return 'FeatureRequestSummaryView';
      case _i73.FixVerificationView():
        return 'FixVerificationView';
      case _i74.HealthStatusView():
        return 'HealthStatusView';
      case _i75.HumanDirectionAttachmentView():
        return 'HumanDirectionAttachmentView';
      case _i76.HumanDirectionPayloadView():
        return 'HumanDirectionPayloadView';
      case _i77.HumanDirectionView():
        return 'HumanDirectionView';
      case _i78.JobClaimView():
        return 'JobClaimView';
      case _i79.JobInspectionView():
        return 'JobInspectionView';
      case _i80.JobListView():
        return 'JobListView';
      case _i81.JobRecordView():
        return 'JobRecordView';
      case _i82.JobSummaryView():
        return 'JobSummaryView';
      case _i83.MintedCredentialView():
        return 'MintedCredentialView';
      case _i84.ModelExecutionListView():
        return 'ModelExecutionListView';
      case _i85.ModelExecutionRecordView():
        return 'ModelExecutionRecordView';
      case _i86.ModelPolicyListView():
        return 'ModelPolicyListView';
      case _i87.ModelPolicyView():
        return 'ModelPolicyView';
      case _i88.ModelStatsGroupView():
        return 'ModelStatsGroupView';
      case _i89.ModelStatsView():
        return 'ModelStatsView';
      case _i90.ModelStepView():
        return 'ModelStepView';
      case _i91.Overview():
        return 'Overview';
      case _i92.PlatformVerificationView():
        return 'PlatformVerificationView';
      case _i93.ProductBaselineView():
        return 'ProductBaselineView';
      case _i94.ProductContextView():
        return 'ProductContextView';
      case _i95.ProductDetailView():
        return 'ProductDetailView';
      case _i96.ProductSummaryView():
        return 'ProductSummaryView';
      case _i97.ProductView():
        return 'ProductView';
      case _i98.ProviderHealthView():
        return 'ProviderHealthView';
      case _i99.ProviderStatusView():
        return 'ProviderStatusView';
      case _i100.RepositoryCredentialView():
        return 'RepositoryCredentialView';
      case _i101.RepositoryReferenceAddedView():
        return 'RepositoryReferenceAddedView';
      case _i102.RepositoryReferenceView():
        return 'RepositoryReferenceView';
      case _i103.ResolveDecisionView():
        return 'ResolveDecisionView';
      case _i104.ResourceUsageView():
        return 'ResourceUsageView';
      case _i105.SchedulerEventView():
        return 'SchedulerEventView';
      case _i106.StandingPolicyView():
        return 'StandingPolicyView';
      case _i107.TransitionView():
        return 'TransitionView';
      case _i108.TriageResultView():
        return 'TriageResultView';
      case _i109.WorkItemDetailView():
        return 'WorkItemDetailView';
      case _i110.WorkItemView():
        return 'WorkItemView';
      case _i111.WorkerEventView():
        return 'WorkerEventView';
      case _i112.WorkerExecutionInspectionView():
        return 'WorkerExecutionInspectionView';
      case _i113.WorkerExecutionListView():
        return 'WorkerExecutionListView';
      case _i114.WorkerExecutionResultView():
        return 'WorkerExecutionResultView';
      case _i115.WorkerExecutionView():
        return 'WorkerExecutionView';
      case _i116.WorkerListView():
        return 'WorkerListView';
      case _i117.WorkerRegistrationView():
        return 'WorkerRegistrationView';
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
    if (dataClassName == 'AgentArtifactView') {
      return deserialize<_i3.AgentArtifactView>(data['data']);
    }
    if (dataClassName == 'AgentClaimedCheckView') {
      return deserialize<_i4.AgentClaimedCheckView>(data['data']);
    }
    if (dataClassName == 'AgentDiagnosticsView') {
      return deserialize<_i5.AgentDiagnosticsView>(data['data']);
    }
    if (dataClassName == 'AgentEventView') {
      return deserialize<_i6.AgentEventView>(data['data']);
    }
    if (dataClassName == 'AgentExecutionInspectionView') {
      return deserialize<_i7.AgentExecutionInspectionView>(data['data']);
    }
    if (dataClassName == 'AgentExecutionListView') {
      return deserialize<_i8.AgentExecutionListView>(data['data']);
    }
    if (dataClassName == 'AgentExecutionRecordView') {
      return deserialize<_i9.AgentExecutionRecordView>(data['data']);
    }
    if (dataClassName == 'AgentResultView') {
      return deserialize<_i10.AgentResultView>(data['data']);
    }
    if (dataClassName == 'AgentWorkspaceView') {
      return deserialize<_i11.AgentWorkspaceView>(data['data']);
    }
    if (dataClassName == 'ArtifactCacheEntryView') {
      return deserialize<_i12.ArtifactCacheEntryView>(data['data']);
    }
    if (dataClassName == 'ArtifactReferenceView') {
      return deserialize<_i13.ArtifactReferenceView>(data['data']);
    }
    if (dataClassName == 'BaselineFactView') {
      return deserialize<_i14.BaselineFactView>(data['data']);
    }
    if (dataClassName == 'CapabilitySpecView') {
      return deserialize<_i15.CapabilitySpecView>(data['data']);
    }
    if (dataClassName == 'ChangedFileView') {
      return deserialize<_i16.ChangedFileView>(data['data']);
    }
    if (dataClassName == 'ClarificationView') {
      return deserialize<_i17.ClarificationView>(data['data']);
    }
    if (dataClassName == 'CredentialAccessVerificationView') {
      return deserialize<_i18.CredentialAccessVerificationView>(data['data']);
    }
    if (dataClassName == 'AgentEventRow') {
      return deserialize<_i19.AgentEventRow>(data['data']);
    }
    if (dataClassName == 'AgentExecutionRow') {
      return deserialize<_i20.AgentExecutionRow>(data['data']);
    }
    if (dataClassName == 'AgentExecutionRequestRow') {
      return deserialize<_i21.AgentExecutionRequestRow>(data['data']);
    }
    if (dataClassName == 'AgentResultRow') {
      return deserialize<_i22.AgentResultRow>(data['data']);
    }
    if (dataClassName == 'BaselineFactRow') {
      return deserialize<_i23.BaselineFactRow>(data['data']);
    }
    if (dataClassName == 'ClarificationRequestRow') {
      return deserialize<_i24.ClarificationRequestRow>(data['data']);
    }
    if (dataClassName == 'DefectRow') {
      return deserialize<_i25.DefectRow>(data['data']);
    }
    if (dataClassName == 'DefectClarificationRow') {
      return deserialize<_i26.DefectClarificationRow>(data['data']);
    }
    if (dataClassName == 'DefectEventRow') {
      return deserialize<_i27.DefectEventRow>(data['data']);
    }
    if (dataClassName == 'DefectEvidenceRow') {
      return deserialize<_i28.DefectEvidenceRow>(data['data']);
    }
    if (dataClassName == 'DesignFindingRow') {
      return deserialize<_i29.DesignFindingRow>(data['data']);
    }
    if (dataClassName == 'DesignReviewResultRow') {
      return deserialize<_i30.DesignReviewResultRow>(data['data']);
    }
    if (dataClassName == 'DesignRevisionRow') {
      return deserialize<_i31.DesignRevisionRow>(data['data']);
    }
    if (dataClassName == 'DesignRevisionEventRow') {
      return deserialize<_i32.DesignRevisionEventRow>(data['data']);
    }
    if (dataClassName == 'EngineeringReviewResultRow') {
      return deserialize<_i33.EngineeringReviewResultRow>(data['data']);
    }
    if (dataClassName == 'HumanDecisionRow') {
      return deserialize<_i34.HumanDecisionRow>(data['data']);
    }
    if (dataClassName == 'HumanDirectionRow') {
      return deserialize<_i35.HumanDirectionRow>(data['data']);
    }
    if (dataClassName == 'JobRow') {
      return deserialize<_i36.JobRow>(data['data']);
    }
    if (dataClassName == 'JobClaimRow') {
      return deserialize<_i37.JobClaimRow>(data['data']);
    }
    if (dataClassName == 'ModelExecutionRecordRow') {
      return deserialize<_i38.ModelExecutionRecordRow>(data['data']);
    }
    if (dataClassName == 'ModelPolicyRow') {
      return deserialize<_i39.ModelPolicyRow>(data['data']);
    }
    if (dataClassName == 'OnboardingRecordRow') {
      return deserialize<_i40.OnboardingRecordRow>(data['data']);
    }
    if (dataClassName == 'PlatformVerificationRow') {
      return deserialize<_i41.PlatformVerificationRow>(data['data']);
    }
    if (dataClassName == 'ProductRow') {
      return deserialize<_i42.ProductRow>(data['data']);
    }
    if (dataClassName == 'ProductBaselineRow') {
      return deserialize<_i43.ProductBaselineRow>(data['data']);
    }
    if (dataClassName == 'ProductRegistryAuditRow') {
      return deserialize<_i44.ProductRegistryAuditRow>(data['data']);
    }
    if (dataClassName == 'QAContractRow') {
      return deserialize<_i45.QAContractRow>(data['data']);
    }
    if (dataClassName == 'QaReviewResultRow') {
      return deserialize<_i46.QaReviewResultRow>(data['data']);
    }
    if (dataClassName == 'RepositoryCredentialRow') {
      return deserialize<_i47.RepositoryCredentialRow>(data['data']);
    }
    if (dataClassName == 'RepositoryReferenceRow') {
      return deserialize<_i48.RepositoryReferenceRow>(data['data']);
    }
    if (dataClassName == 'SchedulerEventRow') {
      return deserialize<_i49.SchedulerEventRow>(data['data']);
    }
    if (dataClassName == 'StandingPolicyRow') {
      return deserialize<_i50.StandingPolicyRow>(data['data']);
    }
    if (dataClassName == 'TriageResultRow') {
      return deserialize<_i51.TriageResultRow>(data['data']);
    }
    if (dataClassName == 'WorkItemRow') {
      return deserialize<_i52.WorkItemRow>(data['data']);
    }
    if (dataClassName == 'WorkItemTransitionRow') {
      return deserialize<_i53.WorkItemTransitionRow>(data['data']);
    }
    if (dataClassName == 'WorkerEventRow') {
      return deserialize<_i54.WorkerEventRow>(data['data']);
    }
    if (dataClassName == 'WorkerExecutionRow') {
      return deserialize<_i55.WorkerExecutionRow>(data['data']);
    }
    if (dataClassName == 'WorkerRegistrationRow') {
      return deserialize<_i56.WorkerRegistrationRow>(data['data']);
    }
    if (dataClassName == 'WorkerResultRow') {
      return deserialize<_i57.WorkerResultRow>(data['data']);
    }
    if (dataClassName == 'DecisionContextView') {
      return deserialize<_i58.DecisionContextView>(data['data']);
    }
    if (dataClassName == 'DecisionOptionView') {
      return deserialize<_i59.DecisionOptionView>(data['data']);
    }
    if (dataClassName == 'DecisionView') {
      return deserialize<_i60.DecisionView>(data['data']);
    }
    if (dataClassName == 'DefectClarificationRequestView') {
      return deserialize<_i61.DefectClarificationRequestView>(data['data']);
    }
    if (dataClassName == 'DefectClarificationView') {
      return deserialize<_i62.DefectClarificationView>(data['data']);
    }
    if (dataClassName == 'DefectCreatedView') {
      return deserialize<_i63.DefectCreatedView>(data['data']);
    }
    if (dataClassName == 'DefectDetailView') {
      return deserialize<_i64.DefectDetailView>(data['data']);
    }
    if (dataClassName == 'DefectEventView') {
      return deserialize<_i65.DefectEventView>(data['data']);
    }
    if (dataClassName == 'DefectEvidenceView') {
      return deserialize<_i66.DefectEvidenceView>(data['data']);
    }
    if (dataClassName == 'DefectInspectionView') {
      return deserialize<_i67.DefectInspectionView>(data['data']);
    }
    if (dataClassName == 'DefectListView') {
      return deserialize<_i68.DefectListView>(data['data']);
    }
    if (dataClassName == 'DefectSummaryView') {
      return deserialize<_i69.DefectSummaryView>(data['data']);
    }
    if (dataClassName == 'DiagnosticEntryView') {
      return deserialize<_i70.DiagnosticEntryView>(data['data']);
    }
    if (dataClassName == 'FeatureRequestCreatedView') {
      return deserialize<_i71.FeatureRequestCreatedView>(data['data']);
    }
    if (dataClassName == 'FeatureRequestSummaryView') {
      return deserialize<_i72.FeatureRequestSummaryView>(data['data']);
    }
    if (dataClassName == 'FixVerificationView') {
      return deserialize<_i73.FixVerificationView>(data['data']);
    }
    if (dataClassName == 'HealthStatusView') {
      return deserialize<_i74.HealthStatusView>(data['data']);
    }
    if (dataClassName == 'HumanDirectionAttachmentView') {
      return deserialize<_i75.HumanDirectionAttachmentView>(data['data']);
    }
    if (dataClassName == 'HumanDirectionPayloadView') {
      return deserialize<_i76.HumanDirectionPayloadView>(data['data']);
    }
    if (dataClassName == 'HumanDirectionView') {
      return deserialize<_i77.HumanDirectionView>(data['data']);
    }
    if (dataClassName == 'JobClaimView') {
      return deserialize<_i78.JobClaimView>(data['data']);
    }
    if (dataClassName == 'JobInspectionView') {
      return deserialize<_i79.JobInspectionView>(data['data']);
    }
    if (dataClassName == 'JobListView') {
      return deserialize<_i80.JobListView>(data['data']);
    }
    if (dataClassName == 'JobRecordView') {
      return deserialize<_i81.JobRecordView>(data['data']);
    }
    if (dataClassName == 'JobSummaryView') {
      return deserialize<_i82.JobSummaryView>(data['data']);
    }
    if (dataClassName == 'MintedCredentialView') {
      return deserialize<_i83.MintedCredentialView>(data['data']);
    }
    if (dataClassName == 'ModelExecutionListView') {
      return deserialize<_i84.ModelExecutionListView>(data['data']);
    }
    if (dataClassName == 'ModelExecutionRecordView') {
      return deserialize<_i85.ModelExecutionRecordView>(data['data']);
    }
    if (dataClassName == 'ModelPolicyListView') {
      return deserialize<_i86.ModelPolicyListView>(data['data']);
    }
    if (dataClassName == 'ModelPolicyView') {
      return deserialize<_i87.ModelPolicyView>(data['data']);
    }
    if (dataClassName == 'ModelStatsGroupView') {
      return deserialize<_i88.ModelStatsGroupView>(data['data']);
    }
    if (dataClassName == 'ModelStatsView') {
      return deserialize<_i89.ModelStatsView>(data['data']);
    }
    if (dataClassName == 'ModelStepView') {
      return deserialize<_i90.ModelStepView>(data['data']);
    }
    if (dataClassName == 'Overview') {
      return deserialize<_i91.Overview>(data['data']);
    }
    if (dataClassName == 'PlatformVerificationView') {
      return deserialize<_i92.PlatformVerificationView>(data['data']);
    }
    if (dataClassName == 'ProductBaselineView') {
      return deserialize<_i93.ProductBaselineView>(data['data']);
    }
    if (dataClassName == 'ProductContextView') {
      return deserialize<_i94.ProductContextView>(data['data']);
    }
    if (dataClassName == 'ProductDetailView') {
      return deserialize<_i95.ProductDetailView>(data['data']);
    }
    if (dataClassName == 'ProductSummaryView') {
      return deserialize<_i96.ProductSummaryView>(data['data']);
    }
    if (dataClassName == 'ProductView') {
      return deserialize<_i97.ProductView>(data['data']);
    }
    if (dataClassName == 'ProviderHealthView') {
      return deserialize<_i98.ProviderHealthView>(data['data']);
    }
    if (dataClassName == 'ProviderStatusView') {
      return deserialize<_i99.ProviderStatusView>(data['data']);
    }
    if (dataClassName == 'RepositoryCredentialView') {
      return deserialize<_i100.RepositoryCredentialView>(data['data']);
    }
    if (dataClassName == 'RepositoryReferenceAddedView') {
      return deserialize<_i101.RepositoryReferenceAddedView>(data['data']);
    }
    if (dataClassName == 'RepositoryReferenceView') {
      return deserialize<_i102.RepositoryReferenceView>(data['data']);
    }
    if (dataClassName == 'ResolveDecisionView') {
      return deserialize<_i103.ResolveDecisionView>(data['data']);
    }
    if (dataClassName == 'ResourceUsageView') {
      return deserialize<_i104.ResourceUsageView>(data['data']);
    }
    if (dataClassName == 'SchedulerEventView') {
      return deserialize<_i105.SchedulerEventView>(data['data']);
    }
    if (dataClassName == 'StandingPolicyView') {
      return deserialize<_i106.StandingPolicyView>(data['data']);
    }
    if (dataClassName == 'TransitionView') {
      return deserialize<_i107.TransitionView>(data['data']);
    }
    if (dataClassName == 'TriageResultView') {
      return deserialize<_i108.TriageResultView>(data['data']);
    }
    if (dataClassName == 'WorkItemDetailView') {
      return deserialize<_i109.WorkItemDetailView>(data['data']);
    }
    if (dataClassName == 'WorkItemView') {
      return deserialize<_i110.WorkItemView>(data['data']);
    }
    if (dataClassName == 'WorkerEventView') {
      return deserialize<_i111.WorkerEventView>(data['data']);
    }
    if (dataClassName == 'WorkerExecutionInspectionView') {
      return deserialize<_i112.WorkerExecutionInspectionView>(data['data']);
    }
    if (dataClassName == 'WorkerExecutionListView') {
      return deserialize<_i113.WorkerExecutionListView>(data['data']);
    }
    if (dataClassName == 'WorkerExecutionResultView') {
      return deserialize<_i114.WorkerExecutionResultView>(data['data']);
    }
    if (dataClassName == 'WorkerExecutionView') {
      return deserialize<_i115.WorkerExecutionView>(data['data']);
    }
    if (dataClassName == 'WorkerListView') {
      return deserialize<_i116.WorkerListView>(data['data']);
    }
    if (dataClassName == 'WorkerRegistrationView') {
      return deserialize<_i117.WorkerRegistrationView>(data['data']);
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
      case _i19.AgentEventRow:
        return _i19.AgentEventRow.t;
      case _i20.AgentExecutionRow:
        return _i20.AgentExecutionRow.t;
      case _i21.AgentExecutionRequestRow:
        return _i21.AgentExecutionRequestRow.t;
      case _i22.AgentResultRow:
        return _i22.AgentResultRow.t;
      case _i23.BaselineFactRow:
        return _i23.BaselineFactRow.t;
      case _i24.ClarificationRequestRow:
        return _i24.ClarificationRequestRow.t;
      case _i25.DefectRow:
        return _i25.DefectRow.t;
      case _i26.DefectClarificationRow:
        return _i26.DefectClarificationRow.t;
      case _i27.DefectEventRow:
        return _i27.DefectEventRow.t;
      case _i28.DefectEvidenceRow:
        return _i28.DefectEvidenceRow.t;
      case _i29.DesignFindingRow:
        return _i29.DesignFindingRow.t;
      case _i30.DesignReviewResultRow:
        return _i30.DesignReviewResultRow.t;
      case _i31.DesignRevisionRow:
        return _i31.DesignRevisionRow.t;
      case _i32.DesignRevisionEventRow:
        return _i32.DesignRevisionEventRow.t;
      case _i33.EngineeringReviewResultRow:
        return _i33.EngineeringReviewResultRow.t;
      case _i34.HumanDecisionRow:
        return _i34.HumanDecisionRow.t;
      case _i35.HumanDirectionRow:
        return _i35.HumanDirectionRow.t;
      case _i36.JobRow:
        return _i36.JobRow.t;
      case _i37.JobClaimRow:
        return _i37.JobClaimRow.t;
      case _i38.ModelExecutionRecordRow:
        return _i38.ModelExecutionRecordRow.t;
      case _i39.ModelPolicyRow:
        return _i39.ModelPolicyRow.t;
      case _i40.OnboardingRecordRow:
        return _i40.OnboardingRecordRow.t;
      case _i41.PlatformVerificationRow:
        return _i41.PlatformVerificationRow.t;
      case _i42.ProductRow:
        return _i42.ProductRow.t;
      case _i43.ProductBaselineRow:
        return _i43.ProductBaselineRow.t;
      case _i44.ProductRegistryAuditRow:
        return _i44.ProductRegistryAuditRow.t;
      case _i45.QAContractRow:
        return _i45.QAContractRow.t;
      case _i46.QaReviewResultRow:
        return _i46.QaReviewResultRow.t;
      case _i47.RepositoryCredentialRow:
        return _i47.RepositoryCredentialRow.t;
      case _i48.RepositoryReferenceRow:
        return _i48.RepositoryReferenceRow.t;
      case _i49.SchedulerEventRow:
        return _i49.SchedulerEventRow.t;
      case _i50.StandingPolicyRow:
        return _i50.StandingPolicyRow.t;
      case _i51.TriageResultRow:
        return _i51.TriageResultRow.t;
      case _i52.WorkItemRow:
        return _i52.WorkItemRow.t;
      case _i53.WorkItemTransitionRow:
        return _i53.WorkItemTransitionRow.t;
      case _i54.WorkerEventRow:
        return _i54.WorkerEventRow.t;
      case _i55.WorkerExecutionRow:
        return _i55.WorkerExecutionRow.t;
      case _i56.WorkerRegistrationRow:
        return _i56.WorkerRegistrationRow.t;
      case _i57.WorkerResultRow:
        return _i57.WorkerResultRow.t;
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
