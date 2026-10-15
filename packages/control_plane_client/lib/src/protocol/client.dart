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
import 'package:control_plane_client/src/protocol/minted_credential_view.dart'
    as _i3;
import 'package:control_plane_client/src/protocol/credential_access_verification_view.dart'
    as _i4;
import 'package:control_plane_client/src/protocol/defect_created_view.dart'
    as _i5;
import 'package:control_plane_client/src/protocol/defect_list_view.dart' as _i6;
import 'package:control_plane_client/src/protocol/defect_inspection_view.dart'
    as _i7;
import 'package:control_plane_client/src/protocol/defect_evidence_view.dart'
    as _i8;
import 'package:control_plane_client/src/protocol/defect_clarification_view.dart'
    as _i9;
import 'package:control_plane_client/src/protocol/fix_verification_view.dart'
    as _i10;
import 'package:control_plane_client/src/protocol/agent_execution_list_view.dart'
    as _i11;
import 'package:control_plane_client/src/protocol/agent_execution_inspection_view.dart'
    as _i12;
import 'package:control_plane_client/src/protocol/health_status_view.dart'
    as _i13;
import 'package:control_plane_client/src/protocol/overview.dart' as _i14;
import 'package:control_plane_client/src/protocol/work_item_view.dart' as _i15;
import 'package:control_plane_client/src/protocol/decision_view.dart' as _i16;
import 'package:control_plane_client/src/protocol/human_direction_view.dart'
    as _i17;
import 'package:control_plane_client/src/protocol/human_direction_attachment_view.dart'
    as _i18;
import 'package:control_plane_client/src/protocol/feature_request_created_view.dart'
    as _i19;
import 'package:control_plane_client/src/protocol/feature_request_summary_view.dart'
    as _i20;
import 'package:control_plane_client/src/protocol/product_view.dart' as _i21;
import 'package:control_plane_client/src/protocol/product_summary_view.dart'
    as _i22;
import 'package:control_plane_client/src/protocol/product_detail_view.dart'
    as _i23;
import 'package:control_plane_client/src/protocol/product_context_view.dart'
    as _i24;
import 'package:platform_contracts/src/types/baseline_fact.dart' as _i25;
import 'package:control_plane_client/src/protocol/standing_policy_view.dart'
    as _i26;
import 'package:control_plane_client/src/protocol/clarification_view.dart'
    as _i27;
import 'package:control_plane_client/src/protocol/repository_reference_added_view.dart'
    as _i28;
import 'package:control_plane_client/src/protocol/provider_health_view.dart'
    as _i29;
import 'package:control_plane_client/src/protocol/model_policy_list_view.dart'
    as _i30;
import 'package:control_plane_client/src/protocol/model_policy_view.dart'
    as _i31;
import 'package:control_plane_client/src/protocol/model_execution_list_view.dart'
    as _i32;
import 'package:control_plane_client/src/protocol/model_stats_view.dart'
    as _i33;
import 'package:control_plane_client/src/protocol/job_list_view.dart' as _i34;
import 'package:control_plane_client/src/protocol/job_inspection_view.dart'
    as _i35;
import 'package:control_plane_client/src/protocol/work_item_action_context_view.dart'
    as _i36;
import 'package:control_plane_client/src/protocol/work_item_action_result.dart'
    as _i37;
import 'package:control_plane_client/src/protocol/review_repair_result.dart'
    as _i38;
import 'package:control_plane_client/src/protocol/worker_list_view.dart'
    as _i39;
import 'package:control_plane_client/src/protocol/worker_execution_list_view.dart'
    as _i40;
import 'package:control_plane_client/src/protocol/worker_execution_inspection_view.dart'
    as _i41;
import 'package:control_plane_client/src/protocol/job_summary_view.dart'
    as _i42;
import 'package:control_plane_client/src/protocol/work_item_detail_view.dart'
    as _i43;
import 'package:control_plane_client/src/protocol/resolve_decision_view.dart'
    as _i44;
import 'protocol.dart' as _i45;

/// Server half of Add Product: mints repository deploy keys and proves they can
/// reach the repository (ADR 0018 §A2 / §A3).
///
/// WHY A SEPARATE ENDPOINT rather than more methods on `ProductRegistryEndpoints`.
/// Custody is a security boundary and it should be auditable as one. The methods
/// here are the only ones in the server that can cause a private key to be
/// fetched, written to disk, or offered to a transport, and keeping them in a
/// single small file means a reviewer checking "can key material leave the
/// process?" reads one file rather than hunting through a 600-line product
/// endpoint. `ProductRegistryEndpoints` keeps the product, baseline and
/// repository-reference surface, none of which touches a key.
///
/// Both methods return a TYPED Serverpod model — [MintedCredentialView] and
/// [CredentialAccessVerificationView] — rather than a `Map<String, dynamic>`.
/// That is a wire-contract requirement, not a style choice, and the reason is
/// worth stating because it cost two review cycles to find: the generated
/// client mirrors the declared return type, so a map return type generates
/// `callServerEndpoint<Map<String, dynamic>>`, whose
/// `Protocol.deserialize<Map<String, dynamic>>` recurses into
/// `deserialize<dynamic>(v)`. The framework has no deserializer registered for
/// `dynamic`, so the client threw `DeserializationTypeNotFoundException: No
/// deserialization found for type dynamic` before it read a single field — the
/// mint succeeded on the server and the browser showed a failure. Every gate
/// passed, because a map IS valid Dart and DOES generate cleanly; nothing
/// exercised the browser→server hop.
///
/// The typed return type also keeps the leak whitelist structural. The key set
/// is now the FIELD LIST of a generated serialisable class, so a field that
/// could carry the private half cannot be added without the generator, the
/// client's deserializer, and this file's review all seeing it — `SecretBytes`
/// has no serialisable representation and cannot become a field here by
/// accident.
///
/// Both delegate: the durable engine owns credential identity, scope and status;
/// this endpoint only wires the request to it and shapes the response.
///
/// THE FAILURE PATH IS THE ONE THAT MATTERS, and it is built so that no exception
/// message can reach a durable record. `StructuredLogger` writes to the Serverpod
/// session log, and `apps/server/config/test.yaml` sets
/// `sessionLogs.persistentEnabled: true` — so a line logged here is a row in
/// Postgres. This class therefore never formats `error.toString()`; it formats
/// [secretlessText], which renders only the fields of an explicitly audited
/// failure type and **suppresses the message of anything else**. See
/// `credentials/secretless_error.dart` for why `SecretBytes` was not enough on
/// its own.
/// {@category Endpoint}
class EndpointCredentialEndpoints extends _i1.EndpointRef {
  EndpointCredentialEndpoints(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'credentialEndpoints';

  /// Generates a real ed25519 deploy keypair for one repository.
  ///
  /// The private half is handed to the configured [SecretProvider] and is never
  /// returned, logged, or written to a column. The response carries the public
  /// authorized-keys line for the operator to install, the fingerprint, the
  /// algorithm, and the reference the private half is held under.
  ///
  /// Returns `status: "generated"`, never `verified` — access is not proved
  /// until [verifyAccess] runs a real clone.
  _i2.Future<_i3.MintedCredentialView> generate({
    required String productId,
    required String repositoryId,
    String? credentialId,
  }) => caller.callServerEndpoint<_i3.MintedCredentialView>(
    'credentialEndpoints',
    'generate',
    {
      'productId': productId,
      'repositoryId': repositoryId,
      'credentialId': credentialId,
    },
  );

  /// Proves the credential reaches the repository, with a real SSH clone.
  ///
  /// [hostKeyFingerprint] is REQUIRED and is the human trust-on-first-use
  /// confirmation ADR 0018 §Decision demands: "ShipIt refuses to connect to an
  /// unrecognised host. The operator is shown the host, key type and fingerprint
  /// and must confirm it." There is deliberately no optional form — an endpoint
  /// that could clone against an unconfirmed host is the transport gap ADR 0018
  /// §Accepted risks (A2) records.
  ///
  /// IT IS ALSO, PLAINLY, CLIENT-SUPPLIED AND UNAUTHENTICATED (M-5). The server
  /// independently obtains the host key and refuses to clone unless the
  /// fingerprint it computes equals the value supplied here — a real enforcer over
  /// an input the server did not produce. [confirmedBy] is free text from the same
  /// unauthenticated caller. The response carries
  /// [kHostKeyConfirmationProvenance] so no consumer of it can mistake either for
  /// something the server verified. Binding the confirmation to something the
  /// server obtained is a product decision and is not made here.
  ///
  /// This is the call that lets the client set `accessStatus = verified`, and it
  /// sets `status: "verified"` only when `git clone` actually completed.
  _i2.Future<_i4.CredentialAccessVerificationView> verifyAccess({
    required String productId,
    required String repositoryId,
    required String hostKeyFingerprint,
    required String confirmedBy,
    String? checkedBy,
  }) => caller.callServerEndpoint<_i4.CredentialAccessVerificationView>(
    'credentialEndpoints',
    'verifyAccess',
    {
      'productId': productId,
      'repositoryId': repositoryId,
      'hostKeyFingerprint': hostKeyFingerprint,
      'confirmedBy': confirmedBy,
      'checkedBy': checkedBy,
    },
  );
}

/// Endpoints for durable Human Bug Reporting (S-2).
///
/// Every defect-scoped read takes an explicit `defectId` or `productId`.
/// Endpoints never set state directly — they observe or raise gates that
/// the platform's durable engines resolve.
/// {@category Endpoint}
class EndpointDefectEndpoints extends _i1.EndpointRef {
  EndpointDefectEndpoints(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'defectEndpoints';

  /// Reports a new defect.
  ///
  /// Creates the Defect, initial evidence (text + diagnostic bundle),
  /// and the initial 'created' event. Enqueues a triage job.
  _i2.Future<_i5.DefectCreatedView> create({
    required String title,
    required String description,
    String? expectedBehavior,
    String? reproductionSteps,
    required String severity,
    String? intakeCategory,
    required String productId,
    String? affectedWorkItemId,
    String? affectedRunId,
    String? clientContextJson,
    required String reporter,
  }) => caller.callServerEndpoint<_i5.DefectCreatedView>(
    'defectEndpoints',
    'create',
    {
      'title': title,
      'description': description,
      'expectedBehavior': expectedBehavior,
      'reproductionSteps': reproductionSteps,
      'severity': severity,
      'intakeCategory': intakeCategory,
      'productId': productId,
      'affectedWorkItemId': affectedWorkItemId,
      'affectedRunId': affectedRunId,
      'clientContextJson': clientContextJson,
      'reporter': reporter,
    },
  );

  /// Lists defects with optional filters.
  _i2.Future<_i6.DefectListView> list({
    String? productId,
    String? status,
    String? classification,
    int? limit,
    int? offset,
  }) => caller.callServerEndpoint<_i6.DefectListView>(
    'defectEndpoints',
    'list',
    {
      'productId': productId,
      'status': status,
      'classification': classification,
      'limit': limit,
      'offset': offset,
    },
  );

  /// Reads full defect detail including evidence, clarifications, events,
  /// triage result, and remediation work item.
  _i2.Future<_i7.DefectInspectionView> inspect({required String defectId}) =>
      caller.callServerEndpoint<_i7.DefectInspectionView>(
        'defectEndpoints',
        'inspect',
        {'defectId': defectId},
      );

  /// Adds evidence to an existing defect.
  _i2.Future<_i8.DefectEvidenceView> addEvidence({
    required String defectId,
    required String kind,
    String? description,
    String? artifactId,
    String? contentHash,
    String? sourceRef,
  }) => caller.callServerEndpoint<_i8.DefectEvidenceView>(
    'defectEndpoints',
    'addEvidence',
    {
      'defectId': defectId,
      'kind': kind,
      'description': description,
      'artifactId': artifactId,
      'contentHash': contentHash,
      'sourceRef': sourceRef,
    },
  );

  /// AI requests clarification (internal use — typically called by triage agent).
  _i2.Future<_i9.DefectClarificationView> requestClarification({
    required String defectId,
    required String question,
    required String reason,
    required String triageJobId,
  }) => caller.callServerEndpoint<_i9.DefectClarificationView>(
    'defectEndpoints',
    'requestClarification',
    {
      'defectId': defectId,
      'question': question,
      'reason': reason,
      'triageJobId': triageJobId,
    },
  );

  /// Human answers a clarification.
  _i2.Future<_i9.DefectClarificationView> answerClarification({
    required String clarificationId,
    required String answer,
    required String answeredBy,
  }) => caller.callServerEndpoint<_i9.DefectClarificationView>(
    'defectEndpoints',
    'answerClarification',
    {
      'clarificationId': clarificationId,
      'answer': answer,
      'answeredBy': answeredBy,
    },
  );

  /// Human verifies a fix for a defect.
  _i2.Future<_i10.FixVerificationView> verifyFix({
    required String defectId,
    required String choice,
    String? rationale,
    required String decider,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
  }) => caller.callServerEndpoint<_i10.FixVerificationView>(
    'defectEndpoints',
    'verifyFix',
    {
      'defectId': defectId,
      'choice': choice,
      'rationale': rationale,
      'decider': decider,
      'signature': signature,
      'publicKey': publicKey,
      'algorithm': algorithm,
      'signedAt': signedAt,
    },
  );
}

/// Read endpoints for execution_coordinator durable state (agent executions,
/// events, results, verifications).
/// {@category Endpoint}
class EndpointExecutionEndpoints extends _i1.EndpointRef {
  EndpointExecutionEndpoints(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'executionEndpoints';

  /// Lists agent executions, optionally filtered by work item. Reads only.
  _i2.Future<_i11.AgentExecutionListView> list({String? workItemId}) =>
      caller.callServerEndpoint<_i11.AgentExecutionListView>(
        'executionEndpoints',
        'list',
        {'workItemId': workItemId},
      );

  /// Returns one execution, its events, result and verifications. Reads only.
  _i2.Future<_i12.AgentExecutionInspectionView> inspect({
    required String executionId,
  }) => caller.callServerEndpoint<_i12.AgentExecutionInspectionView>(
    'executionEndpoints',
    'inspect',
    {'executionId': executionId},
  );
}

/// Simple health check endpoint for load balancers and monitoring.
/// {@category Endpoint}
class EndpointHealthEndpoints extends _i1.EndpointRef {
  EndpointHealthEndpoints(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'healthEndpoints';

  /// Returns a simple health check response.
  ///
  /// Was `Future<Map<String, dynamic>>`, so the generated client could not read
  /// it: `deserialize<dynamic>` has no entry in Serverpod's serialization
  /// manager. The `timestamp` therefore travels as a real `DateTime` rather than
  /// a pre-formatted string, which is what every other view in this directory
  /// does and what makes the type worth having.
  _i2.Future<_i13.HealthStatusView> health() =>
      caller.callServerEndpoint<_i13.HealthStatusView>(
        'healthEndpoints',
        'health',
        {},
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
  _i2.Future<_i14.Overview> overview() =>
      caller.callServerEndpoint<_i14.Overview>(
        'homeEndpoints',
        'overview',
        {},
      );

  /// Lists work items with optional filters.
  ///
  /// [productId] narrows the list to one product's work, which is how the
  /// report-a-bug form keeps "affected work item" short enough to pick from
  /// once a product has been chosen.
  _i2.Future<List<_i15.WorkItemView>> listWorkItems({
    String? state,
    String? productId,
    int? limit,
  }) => caller.callServerEndpoint<List<_i15.WorkItemView>>(
    'homeEndpoints',
    'listWorkItems',
    {
      'state': state,
      'productId': productId,
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
  _i2.Future<List<_i16.DecisionView>> recentDecisions({
    int? limit,
    int? offset,
  }) => caller.callServerEndpoint<List<_i16.DecisionView>>(
    'homeEndpoints',
    'recentDecisions',
    {
      'limit': limit,
      'offset': offset,
    },
  );

  /// Lists pending blocking human decisions.
  _i2.Future<List<_i16.DecisionView>> pendingDecisions({int? limit}) =>
      caller.callServerEndpoint<List<_i16.DecisionView>>(
        'homeEndpoints',
        'pendingDecisions',
        {'limit': limit},
      );
}

/// Endpoints for durable HumanDirection inbox.
///
/// Directions are created by operators and consumed by workers in the next
/// bounded job — never injected mid-execution. The lifecycle is:
/// created → acked → working → completed | rejected | superseded.
/// {@category Endpoint}
class EndpointHumanDirectionEndpoints extends _i1.EndpointRef {
  EndpointHumanDirectionEndpoints(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'humanDirectionEndpoints';

  /// Creates a new direction.
  _i2.Future<_i17.HumanDirectionView> createDirection({
    required String directionType,
    required String targetType,
    String? targetId,
    required String title,
    required String description,
    String? contextJson,
    List<_i18.HumanDirectionAttachmentView>? attachments,
    String? createdBy,
    String? assignedTo,
  }) => caller.callServerEndpoint<_i17.HumanDirectionView>(
    'humanDirectionEndpoints',
    'createDirection',
    {
      'directionType': directionType,
      'targetType': targetType,
      'targetId': targetId,
      'title': title,
      'description': description,
      'contextJson': contextJson,
      'attachments': attachments,
      'createdBy': createdBy,
      'assignedTo': assignedTo,
    },
  );

  /// Lists directions for a specific target.
  _i2.Future<List<_i17.HumanDirectionView>> listDirectionsForTarget({
    required String targetType,
    required String targetId,
    String? status,
    int? limit,
    int? offset,
  }) => caller.callServerEndpoint<List<_i17.HumanDirectionView>>(
    'humanDirectionEndpoints',
    'listDirectionsForTarget',
    {
      'targetType': targetType,
      'targetId': targetId,
      'status': status,
      'limit': limit,
      'offset': offset,
    },
  );

  /// Lists directions filtered by status.
  _i2.Future<List<_i17.HumanDirectionView>> listDirectionsByStatus({
    required String status,
    String? directionType,
    String? targetType,
    int? limit,
    int? offset,
  }) => caller.callServerEndpoint<List<_i17.HumanDirectionView>>(
    'humanDirectionEndpoints',
    'listDirectionsByStatus',
    {
      'status': status,
      'directionType': directionType,
      'targetType': targetType,
      'limit': limit,
      'offset': offset,
    },
  );

  /// Reads a single direction by ID.
  _i2.Future<_i17.HumanDirectionView> readDirection({
    required String directionId,
  }) => caller.callServerEndpoint<_i17.HumanDirectionView>(
    'humanDirectionEndpoints',
    'readDirection',
    {'directionId': directionId},
  );

  /// Acknowledges a direction (created → acked).
  _i2.Future<_i17.HumanDirectionView> acknowledgeDirection({
    required String directionId,
    required String acknowledgedBy,
  }) => caller.callServerEndpoint<_i17.HumanDirectionView>(
    'humanDirectionEndpoints',
    'acknowledgeDirection',
    {
      'directionId': directionId,
      'acknowledgedBy': acknowledgedBy,
    },
  );

  /// Starts working on a direction (acked → working).
  _i2.Future<_i17.HumanDirectionView> startWorkingDirection({
    required String directionId,
    required String startedBy,
  }) => caller.callServerEndpoint<_i17.HumanDirectionView>(
    'humanDirectionEndpoints',
    'startWorkingDirection',
    {
      'directionId': directionId,
      'startedBy': startedBy,
    },
  );

  /// Completes a direction (working → completed).
  _i2.Future<_i17.HumanDirectionView> completeDirection({
    required String directionId,
    required String completedBy,
    required String completionSummary,
  }) => caller.callServerEndpoint<_i17.HumanDirectionView>(
    'humanDirectionEndpoints',
    'completeDirection',
    {
      'directionId': directionId,
      'completedBy': completedBy,
      'completionSummary': completionSummary,
    },
  );

  /// Rejects a direction (working → rejected).
  _i2.Future<_i17.HumanDirectionView> rejectDirection({
    required String directionId,
    required String rejectedBy,
    required String rejectionReason,
  }) => caller.callServerEndpoint<_i17.HumanDirectionView>(
    'humanDirectionEndpoints',
    'rejectDirection',
    {
      'directionId': directionId,
      'rejectedBy': rejectedBy,
      'rejectionReason': rejectionReason,
    },
  );

  /// Supersedes a direction (any active → superseded).
  _i2.Future<_i17.HumanDirectionView> supersedeDirection({
    required String directionId,
    required String supersededByDirectionId,
    required String supersededBy,
  }) => caller.callServerEndpoint<_i17.HumanDirectionView>(
    'humanDirectionEndpoints',
    'supersedeDirection',
    {
      'directionId': directionId,
      'supersededByDirectionId': supersededByDirectionId,
      'supersededBy': supersededBy,
    },
  );
}

/// Endpoints for unified human work intake (S-2 Feature Requests, etc.).
/// {@category Endpoint}
class EndpointIntakeEndpoints extends _i1.EndpointRef {
  EndpointIntakeEndpoints(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'intakeEndpoints';

  /// Creates a new Feature Request.
  ///
  /// Instantiates a WorkItem with category: feature, and a corresponding
  /// HumanDirection to surface it in the inbox.
  ///
  /// Was `Future<Map<String, dynamic>>`. The Reports screen's Feature tab calls
  /// it, so it threw `No deserialization found for type dynamic` the first time
  /// anybody filed a request.
  _i2.Future<_i19.FeatureRequestCreatedView> createFeatureRequest({
    required String title,
    required String description,
    required String productId,
    required String reporter,
  }) => caller.callServerEndpoint<_i19.FeatureRequestCreatedView>(
    'intakeEndpoints',
    'createFeatureRequest',
    {
      'title': title,
      'description': description,
      'productId': productId,
      'reporter': reporter,
    },
  );

  /// Lists feature requests for the Reports screen's `Feature requests` tab.
  ///
  /// Read-only and product-scoped like every other list on this surface: a
  /// caller that names no [productId] gets the whole register, and one that
  /// names an unregistered product gets nothing rather than a fabricated row.
  /// The envelope mirrors `defectEndpoints.list` so the client can read both
  /// tabs with the same shape.
  _i2.Future<List<_i20.FeatureRequestSummaryView>> listFeatureRequests({
    String? productId,
    String? state,
    int? limit,
  }) => caller.callServerEndpoint<List<_i20.FeatureRequestSummaryView>>(
    'intakeEndpoints',
    'listFeatureRequests',
    {
      'productId': productId,
      'state': state,
      'limit': limit,
    },
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
  _i2.Future<List<_i21.ProductView>> listProducts() =>
      caller.callServerEndpoint<List<_i21.ProductView>>(
        'productRegistryEndpoints',
        'listProducts',
        {},
      );

  /// One row per product for the Products list, with the baseline,
  /// clarification and credential-reachability counts already resolved.
  _i2.Future<List<_i22.ProductSummaryView>> listProductSummaries() =>
      caller.callServerEndpoint<List<_i22.ProductSummaryView>>(
        'productRegistryEndpoints',
        'listProductSummaries',
        {},
      );

  /// Everything the Product Detail screen reads, in one call.
  _i2.Future<_i23.ProductDetailView> productDetail({
    required String productId,
  }) => caller.callServerEndpoint<_i23.ProductDetailView>(
    'productRegistryEndpoints',
    'productDetail',
    {'productId': productId},
  );

  /// Loads the bounded `ProductContext(productId)`: exactly that Product and
  /// everything scoped to it. A scope mismatch is a fault, not a filter.
  _i2.Future<_i24.ProductContextView> productContext({
    required String productId,
  }) => caller.callServerEndpoint<_i24.ProductContextView>(
    'productRegistryEndpoints',
    'productContext',
    {'productId': productId},
  );

  /// Creates a durable baseline-approval decision bound to the exact current
  /// revision + contentHash. Returns the decision for the client to present to
  /// the human approver.
  _i2.Future<_i16.DecisionView> proposeBaseline({
    required String productId,
    required List<_i25.BaselineFact> facts,
  }) => caller.callServerEndpoint<_i16.DecisionView>(
    'productRegistryEndpoints',
    'proposeBaseline',
    {
      'productId': productId,
      'facts': facts,
    },
  );

  /// Creates a durable baseline-approval decision bound to the exact current
  /// revision + contentHash. Returns the decision for the client to present to
  /// the human approver.
  _i2.Future<_i16.DecisionView> requestBaselineApproval({
    required String productId,
    required String baselineId,
    String? decisionId,
  }) => caller.callServerEndpoint<_i16.DecisionView>(
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
  _i2.Future<_i16.DecisionView> requestLifecycleDecision({
    required String productId,
    required String action,
    required bool drainInFlight,
  }) => caller.callServerEndpoint<_i16.DecisionView>(
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
  _i2.Future<_i16.DecisionView> resolveLifecycleDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
    required bool noWorkInFlight,
  }) => caller.callServerEndpoint<_i16.DecisionView>(
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
  _i2.Future<_i16.DecisionView> requestPolicyAuthorisation({
    required String productId,
    required List<String> actions,
  }) => caller.callServerEndpoint<_i16.DecisionView>(
    'productRegistryEndpoints',
    'requestPolicyAuthorisation',
    {
      'productId': productId,
      'actions': actions,
    },
  );

  /// Resolves a policy gate. On approve a [StandingPolicy] is created citing
  /// this decision; any policy already live over the same scope is superseded.
  _i2.Future<_i26.StandingPolicyView?> resolvePolicyAuthorisation({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
  }) => caller.callServerEndpoint<_i26.StandingPolicyView?>(
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
  _i2.Future<_i26.StandingPolicyView> revokeStandingPolicy({
    required String productId,
    required String policyId,
    required String revokedBy,
  }) => caller.callServerEndpoint<_i26.StandingPolicyView>(
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
  _i2.Future<_i16.DecisionView> resolveBaselineApproval({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
  }) => caller.callServerEndpoint<_i16.DecisionView>(
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
  _i2.Future<_i16.DecisionView> baselineApproval({
    required String productId,
    required String baselineId,
  }) => caller.callServerEndpoint<_i16.DecisionView>(
    'productRegistryEndpoints',
    'baselineApproval',
    {
      'productId': productId,
      'baselineId': baselineId,
    },
  );

  /// Answers a durable clarification, resuming the same onboarding lineage.
  _i2.Future<_i27.ClarificationView> answerClarification({
    required String clarificationId,
    required String answer,
    required String answeredBy,
  }) => caller.callServerEndpoint<_i27.ClarificationView>(
    'productRegistryEndpoints',
    'answerClarification',
    {
      'clarificationId': clarificationId,
      'answer': answer,
      'answeredBy': answeredBy,
    },
  );

  /// Creates a new product with its manifest.
  _i2.Future<_i23.ProductDetailView> createProduct({
    required String productId,
    required String name,
    String? description,
    String? manifestJson,
    String? manifestVersion,
  }) => caller.callServerEndpoint<_i23.ProductDetailView>(
    'productRegistryEndpoints',
    'createProduct',
    {
      'productId': productId,
      'name': name,
      'description': description,
      'manifestJson': manifestJson,
      'manifestVersion': manifestVersion,
    },
  );

  /// Adds a repository reference to a product.
  ///
  /// THIS RETURN TYPE IS LOAD-BEARING, and it used to be
  /// `Future<Map<String, dynamic>>`.
  ///
  /// The Add Product flow calls this through
  /// `AddProductBloc._ensureProductAndRepository` immediately BEFORE
  /// `credentialEndpoints.generate`, in the same press of the same control
  /// (`add_product_page.dart:143` then `:147`). The old body was the NON-EMPTY
  /// map `{'success': true, 'repositoryId': …}`, and the generated client's
  /// `Protocol.deserialize<Map<String, dynamic>>` reads every value with
  /// `deserialize<dynamic>`, for which Serverpod registers nothing. So the
  /// request went out, the server answered 200, and the browser died in
  /// `parseData` at THIS call — the deploy key was never minted.
  ///
  /// An EMPTY map deserialises fine, which is the whole reason this defect class
  /// presents as intermittent and gets blamed on whichever endpoint happened to
  /// be nearest the symptom.
  _i2.Future<_i28.RepositoryReferenceAddedView> addRepositoryReference({
    required String productId,
    required String repositoryId,
    required String uri,
    required String kind,
    required String provider,
  }) => caller.callServerEndpoint<_i28.RepositoryReferenceAddedView>(
    'productRegistryEndpoints',
    'addRepositoryReference',
    {
      'productId': productId,
      'repositoryId': repositoryId,
      'uri': uri,
      'kind': kind,
      'provider': provider,
    },
  );

  /// Adds an operator-authored claim to a **proposed** baseline. Amending a
  /// baseline cancels any unresolved approval decision (new hash binding), so
  /// the client must request approval again against the new revision.
  _i2.Future<_i23.ProductDetailView> addHumanBaselineClaim({
    required String productId,
    required String baselineId,
    required String section,
    required String claim,
    required String author,
    List<String>? evidenceRefs,
    String? maturity,
  }) => caller.callServerEndpoint<_i23.ProductDetailView>(
    'productRegistryEndpoints',
    'addHumanBaselineClaim',
    {
      'productId': productId,
      'baselineId': baselineId,
      'section': section,
      'claim': claim,
      'author': author,
      'evidenceRefs': evidenceRefs,
      'maturity': maturity,
    },
  );
}

/// Provider health and model policy management endpoints.
/// {@category Endpoint}
class EndpointProviderHealthEndpoints extends _i1.EndpointRef {
  EndpointProviderHealthEndpoints(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'providerHealthEndpoints';

  /// Returns the health status of all known providers.
  ///
  /// Was `Future<Map<String, dynamic>>`. Every method on this endpoint class was
  /// reachable from the live Flutter client and every one of them threw
  /// `No deserialization found for type dynamic` on first use.
  _i2.Future<_i29.ProviderHealthView> getProviderHealth() =>
      caller.callServerEndpoint<_i29.ProviderHealthView>(
        'providerHealthEndpoints',
        'getProviderHealth',
        {},
      );

  /// Lists all model policies.
  _i2.Future<_i30.ModelPolicyListView> listModelPolicies() =>
      caller.callServerEndpoint<_i30.ModelPolicyListView>(
        'providerHealthEndpoints',
        'listModelPolicies',
        {},
      );

  /// Updates a model policy chain (requires admin).
  ///
  /// Returns the policy as written, not `{'success': true}`. The old
  /// acknowledgement could not satisfy this client method's declared return
  /// type — `ModelPolicyResponse.fromJson` read a `role` that was never sent —
  /// so the pair only worked because the one caller discarded the result. The
  /// endpoint now publishes the thing it just persisted.
  _i2.Future<_i31.ModelPolicyView> updateModelPolicy({
    required String role,
    required String chainJson,
    required int version,
    required String updatedByDecisionId,
  }) => caller.callServerEndpoint<_i31.ModelPolicyView>(
    'providerHealthEndpoints',
    'updateModelPolicy',
    {
      'role': role,
      'chainJson': chainJson,
      'version': version,
      'updatedByDecisionId': updatedByDecisionId,
    },
  );

  /// Returns paginated model execution records with filters.
  _i2.Future<_i32.ModelExecutionListView> listModelExecutions({
    String? workItemId,
    String? provider,
    String? modelId,
    DateTime? from,
    DateTime? to,
    required int limit,
    required int offset,
  }) => caller.callServerEndpoint<_i32.ModelExecutionListView>(
    'providerHealthEndpoints',
    'listModelExecutions',
    {
      'workItemId': workItemId,
      'provider': provider,
      'modelId': modelId,
      'from': from,
      'to': to,
      'limit': limit,
      'offset': offset,
    },
  );

  /// Returns aggregated model execution statistics.
  _i2.Future<_i33.ModelStatsView> getModelStats({
    DateTime? from,
    DateTime? to,
    String? groupBy,
  }) => caller.callServerEndpoint<_i33.ModelStatsView>(
    'providerHealthEndpoints',
    'getModelStats',
    {
      'from': from,
      'to': to,
      'groupBy': groupBy,
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
  ///
  /// Was `Future<Map<String, dynamic>>`, so the generated client could not read
  /// it at all.
  _i2.Future<_i34.JobListView> listJobs({String? workItemId}) =>
      caller.callServerEndpoint<_i34.JobListView>(
        'schedulerEndpoints',
        'listJobs',
        {'workItemId': workItemId},
      );

  /// Returns one job, its claim, and its full event history. Reads only.
  _i2.Future<_i35.JobInspectionView> inspect({required String jobId}) =>
      caller.callServerEndpoint<_i35.JobInspectionView>(
        'schedulerEndpoints',
        'inspect',
        {'jobId': jobId},
      );
}

/// Operator actions on a work item parked in a failure state.
///
/// The SECOND legal request-side write path, after
/// `WorkflowEndpoints.resolveDecision`, and deliberately a separate class: the
/// existing class's doc comment claims resolveDecision is the only one, and
/// widening it in place would have left that comment false.
///
/// ## The retry is ONE durable write, and it deliberately does nothing else
///
/// `retryFailedWorkItem` performs exactly one durable transaction — the state
/// change, the transition record, the `operator_action` audit row and the
/// attempt marker — through [DurableWorkflowEngine.operatorRetry]. It does NOT
/// enqueue a job, does NOT claim one, does NOT dispatch one, and does NOT
/// consult the capacity guard.
///
/// The item lands in `designNotRequired`, a triage entry state the scheduler
/// already treats as runnable, so the ordinary tick does the rest on the
/// ordinary path. That is why there is no dispatch path here to get wrong, and
/// why a capacity denial is the scheduler's ordinary behaviour rather than an
/// outcome this method has to design.
///
/// **It does not pre-check capacity either, and must never be given one.** A
/// pre-check is a time-of-check/time-of-use race and would produce a button
/// that says "go" and then does nothing — the dead-button class this design has
/// been burned by three times. The item simply stays runnable until a slot
/// frees (§7.1, N1).
/// {@category Endpoint}
class EndpointWorkItemActionEndpoints extends _i1.EndpointRef {
  EndpointWorkItemActionEndpoints(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'workItemActionEndpoints';

  /// READ. The legal action set for this work item, computed server-side from
  /// [WorkItemTransitions], plus the failure record and the capacity snapshot.
  ///
  /// An empty [WorkItemActionContextView.actions] is the whole signal the page
  /// uses to keep today's existing right-column text instead of the action
  /// panel, so it must be empty for exactly the right reason and not merely
  /// because a lookup failed.
  _i2.Future<_i36.WorkItemActionContextView> actionContext({
    required String workItemId,
  }) => caller.callServerEndpoint<_i36.WorkItemActionContextView>(
    'workItemActionEndpoints',
    'actionContext',
    {'workItemId': workItemId},
  );

  /// WRITE. `agentFailed -> designNotRequired` through
  /// [DurableWorkflowEngine.operatorRetry].
  ///
  /// One durable transaction, no enqueue, no dispatch, no capacity check. The
  /// ordering below is §6.4's, and each step's position is load-bearing:
  ///
  ///  1. **Replay.** The `operator_action` row is unique on
  ///     `(workItemId, requestId)`, so it is the authoritative idempotency
  ///     record. A client that retries one operator intent — a lost response, a
  ///     double-click — finds its own row and returns the current item without
  ///     writing again. This is what makes a network retry mint no second job:
  ///     no second write means no second `triageAttempt`, so no second dedupe
  ///     key.
  ///  2. **State.** Not `agent_failed` ⇒ `notApplicable`, nothing written.
  ///  3. **Edge legality**, asked of the real table.
  ///  4. **The bound.** Reached ⇒ `notConfigured`, nothing written. Switched
  ///     off by an explicit `0` ⇒ `notConfigured`, nothing written. Unset ⇒
  ///     **no bound and no refusal** — this step does not stop it (reversed
  ///     2026-10-12; see [operatorRetryLimitEnvVar]).
  ///  5. **The reason.** Blank ⇒ `invalidRequest`, nothing written. The record
  ///     must say why, not just what (§6.4 step 1, §6.3).
  ///  6. **`alreadyRunning`.** Any non-terminal job for this item means a
  ///     second operator action could be layered on top of a live attempt.
  ///  7. **The write.** One transaction.
  ///
  /// Steps 1, 2, 3, 5, 6 and 7 are UNCHANGED by the 2026-10-12 reversal, and
  /// that is the point worth stating: an uncounted retry is still one
  /// deliberate, reasoned, non-double-spending, non-concurrent action per
  /// invocation. Only step 4 changed.
  ///
  /// ## HOW OFTEN THIS MAY BE CALLED
  ///
  /// Unbounded, by a human, one deliberate confirm-and-reason at a time. What
  /// bounds it is not a counter but the guards above: an item must be parked
  /// in `agent_failed`, must not already be running, and each call writes one
  /// audit row. What bounds AUTOMATIC re-running is a different mechanism
  /// entirely — the job's own `maxAttempts` — and this method does not consult
  /// it (nor could it: it never enqueues or claims a job).
  ///
  /// `requestId` is minted by the client ONCE per operator intent — on confirm,
  /// not on load and not per HTTP attempt — and reused for every network retry
  /// of that intent.
  _i2.Future<_i37.WorkItemActionResult> retryFailedWorkItem({
    required String workItemId,
    required String requestId,
    required String requestedBy,
    required String reason,
  }) => caller.callServerEndpoint<_i37.WorkItemActionResult>(
    'workItemActionEndpoints',
    'retryFailedWorkItem',
    {
      'workItemId': workItemId,
      'requestId': requestId,
      'requestedBy': requestedBy,
      'reason': reason,
    },
  );

  /// WRITE. `agentFailed -> cancelled` through [DurableWorkflowEngine].
  ///
  /// The generic non-terminal escape and nothing synthesised: `stop` writes
  /// exactly the edge `WorkItemTransitions` already permits, under the same
  /// actor the retry uses, and records the human and their reason on the same
  /// durable write. A stop is terminal and irreversible — there is no edge back
  /// from `cancelled` — which is why it is offered as an `OutlinedButton` with
  /// a `negative` panel edge and the SAME confirmation strip as the retry, and
  /// why it is never styled as the safe option (§10 N11, §9 A6).
  ///
  /// Unlike the retry, this does NOT refuse while a job is running: stopping is
  /// precisely what an operator reaches for when work is already in flight, and
  /// the brief withholds `alreadyRunning` from the stop path (design-brief.md
  /// §6.4 step 1, §7.3 — "offers no retry button while it holds").
  _i2.Future<_i37.WorkItemActionResult> stopFailedWorkItem({
    required String workItemId,
    required String requestId,
    required String requestedBy,
    required String reason,
  }) => caller.callServerEndpoint<_i37.WorkItemActionResult>(
    'workItemActionEndpoints',
    'stopFailedWorkItem',
    {
      'workItemId': workItemId,
      'requestId': requestId,
      'requestedBy': requestedBy,
      'reason': reason,
    },
  );

  /// WRITE. Returns a work item parked behind a fabricated engineering-review
  /// decision to `agentCompleted` — retryable and dispatchable — and retires the
  /// decision without destroying it.
  ///
  /// ## WHY THIS IS NOT A TRANSITION
  ///
  /// `waitingForHumanDecision -> agentCompleted` has no edge in
  /// `WorkItemTransitions`, exactly as `agentCompleted ->
  /// waitingForHumanDecision` never had one (`engineering_review_gate.dart`
  /// reaches the gate by entering `reviewInProgress` first). Nothing in the
  /// state machine models "a question was asked that nobody asked", so this
  /// writes the item directly inside one transaction, and says in its audit row
  /// that no edge was taken. The same is true of every repair migration in this
  /// repository, and the reason is the same: there is no edge to take.
  ///
  /// ## WHAT IT IS PROVABLY SCOPED TO
  ///
  /// [readReviewVerdictProvenance] decides, and it decides from the REVIEWER'S
  /// OWN durable result. The decision's `metadata` is read only for the
  /// execution id it names; its `reviewVerdict` is never taken as evidence that
  /// anyone reviewed anything. Only [ReviewAssessment.noReviewerOutput] — no
  /// result at all, or a result with neither a structured payload nor a
  /// summary — reaches the write.
  ///
  /// ## WHAT IT REFUSES, AND WHY EACH REFUSAL IS THE SAFE SIDE
  ///
  ///  * [ReviewAssessment.assessed] → `reviewerProducedVerdict`. A reviewer
  ///    really returned this verdict. Discarding it would destroy a real review.
  ///    This is the guardrail, and it is the whole reason the provenance is
  ///    RE-DERIVED rather than read off the decision.
  ///  * [ReviewAssessment.reviewerProseOnly] → `reviewerProducedProse`. A real
  ///    reviewer wrote a real assessment that the machine channel failed to
  ///    capture and the operator has never seen. Measured live in QA on
  ///    2026-10-14: one such reviewer wrote
  ///    *"**Verdict: `APPROVE_WITH_NON_BLOCKING_FOLLOWUP`**"* while the decision
  ///    it produced claimed `changes_required`. Refusing here is deliberate and
  ///    is the conservative side of the choice — an operator-triggered path that
  ///    can throw away a genuine review is worse than the bug it repairs. The
  ///    operator's safe answer on one of these is to RESOLVE the decision
  ///    (reject routes to `reviewRejected`, a triage entry state), which keeps
  ///    the reviewer's prose on the execution record.
  ///  * [ReviewAssessment.unreadable] → `reviewerOutputUnreadable`. "I could not
  ///    check" is not "there was nothing there".
  ///  * a decision a human has already RESOLVED → `alreadyDecided`. Someone
  ///    answered the question. Overwriting that answer is not a repair, it is
  ///    discarding a real human decision — and QA has one on record: an operator
  ///    approved `dec-hn7h7daum6-2atjhe`, whose reviewer had in fact timed out,
  ///    and the work item moved to `reviewApproved`. This refusal is what stops
  ///    this method being the thing that did that.
  ///
  ///    THE OPERATOR HAS SINCE GONE THE OTHER WAY ON THAT ONE, and the two
  ///    positions are deliberately not the same. Voiding a human approval is
  ///    `HUMAN_DECISION_REQUIRED` by construction: migration
  ///    `20261014210000000` did it for all five fabricated decisions under
  ///    recorded decision `8f1ed5bf-4147-449a-a221-558aac2303a9`, after being
  ///    shown that one of them had an approval resting on nothing. THIS method
  ///    still refuses, because an operator clicking a button on one item is not
  ///    that: the consent was given for five named rows with a stated reason,
  ///    and generalising it to an ad-hoc action would hand the one authority
  ///    nobody granted it. The two decisions disagree on purpose.
  ///  * a decision that is not the item's blocking one, or an item not at
  ///    `waitingForHumanDecision` → `notApplicable`. There is nothing parked.
  ///  * a non-terminal job → `alreadyRunning`. A second operator action must not
  ///    be layered on a live attempt.
  ///  * a blank reason or a blank requester → `invalidRequest`. The record must
  ///    say who and why.
  ///
  /// EVERY refusal returns before the transaction opens, so every refusal writes
  /// NOTHING — no audit row, no decision change, no version bump.
  ///
  /// ## THE FRESH DEDUPE KEY IS AN ARITHMETIC BORROW, NOT A RE-DERIVATION
  ///
  /// `engineeringReviewDedupeKey` (packages/scheduler/lib/src/scheduler.dart)
  /// builds `'<workItemId>:engineering_review'` plus `':a<n>'` when
  /// `metadata.triageAttempt` is readable — and the terminal job that stranded
  /// the item already holds its key, so the item is inert without a bump. The
  /// bump reuses [DurableWorkflowEngine.nextTriageAttempt] with the HIGHEST
  /// attempt this item's own `engineering_review` jobs have consumed as the
  /// floor, which is the same second-watermark rule
  /// `20261014093000000` used for the triage key and the same one
  /// `operatorRetry` uses. The arithmetic is not restated here; only the floor
  /// is computed, and it is computed from the item's own job rows so the key it
  /// writes is provably unheld.
  ///
  /// ## REPLAY
  ///
  /// `requestId` is minted by the caller once per operator intent. A repeat
  /// finds its own audit row by idempotency key and returns what that request
  /// DID, without writing again — so a double-click cannot mint a second
  /// discriminator bump, which would queue a second review.
  ///
  /// ## ON THE WIRE
  ///
  /// Serverpod dispatches methods from the GENERATED connector table
  /// (`lib/src/generated/endpoints.dart`), and the matching client method lives
  /// in `packages/control_plane_client/lib/src/protocol/client.dart`. This
  /// method used to carry `@doNotGenerate` and to return a hand-written Dart
  /// class, which made it unreachable from any control-plane client: the
  /// generator emits an import for a file it never writes, and a type declared
  /// outside `lib/src/models/` appears ZERO times in `protocol.dart`, so the
  /// `SerializationManager` cannot decode the return value in either direction.
  /// A green `dart analyze` on the server proved nothing about that, because
  /// nothing exercised it.
  ///
  /// [ReviewRepairResult] is therefore a YAML model
  /// (`lib/src/models/review_repair_result.yaml`) and the connector row, the
  /// client method, the serialization entry and both generated copies all come
  /// from `serverpod generate`. The evidence that closed it is in
  /// docs/engineering/learning/a-generated-client-can-reference-a-file-it-never-emitted.md
  /// and the wire proof is `apps/server/test/integration/review_repair_wire_e2e_test.dart`,
  /// which drives this method through the REAL generated client over HTTP.
  _i2.Future<_i38.ReviewRepairResult> repairUnreviewedReview({
    required String workItemId,
    required String requestId,
    required String requestedBy,
    required String reason,
    String? decisionId,
  }) => caller.callServerEndpoint<_i38.ReviewRepairResult>(
    'workItemActionEndpoints',
    'repairUnreviewedReview',
    {
      'workItemId': workItemId,
      'requestId': requestId,
      'requestedBy': requestedBy,
      'reason': reason,
      'decisionId': decisionId,
    },
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
  ///
  /// Was `Future<Map<String, dynamic>>`. It published
  /// `WorkerRegistrationCodec.toJson(...)` verbatim, whose nested `capabilities`
  /// and `artifactCache` objects are `Map<String, dynamic>`; those are now typed
  /// views keyed by their wire names.
  _i2.Future<_i39.WorkerListView> listWorkers() =>
      caller.callServerEndpoint<_i39.WorkerListView>(
        'workerEndpoints',
        'listWorkers',
        {},
      );

  /// Lists worker executions, newest first. Reads only.
  _i2.Future<_i40.WorkerExecutionListView> listExecutions({
    String? workItemId,
  }) => caller.callServerEndpoint<_i40.WorkerExecutionListView>(
    'workerEndpoints',
    'listExecutions',
    {'workItemId': workItemId},
  );

  /// Returns one execution, its events and (if present) its result. Reads only.
  _i2.Future<_i41.WorkerExecutionInspectionView> inspect({
    required String workerExecutionId,
  }) => caller.callServerEndpoint<_i41.WorkerExecutionInspectionView>(
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
  _i2.Future<List<_i42.JobSummaryView>> jobsForWorkItem({
    required String workItemId,
  }) => caller.callServerEndpoint<List<_i42.JobSummaryView>>(
    'workflowEndpoints',
    'jobsForWorkItem',
    {'workItemId': workItemId},
  );

  /// Returns the current work item and its transition history. Never mutates
  /// state; `WorkItem.state` on the wire is always reported, never written.
  _i2.Future<_i43.WorkItemDetailView> inspect({required String workItemId}) =>
      caller.callServerEndpoint<_i43.WorkItemDetailView>(
        'workflowEndpoints',
        'inspect',
        {'workItemId': workItemId},
      );

  /// Lists every decision attached to a work item, most recent first.
  _i2.Future<List<_i16.DecisionView>> listDecisions({
    required String workItemId,
  }) => caller.callServerEndpoint<List<_i16.DecisionView>>(
    'workflowEndpoints',
    'listDecisions',
    {'workItemId': workItemId},
  );

  /// Resolves a human decision through the durable engine.
  ///
  /// This was, until `WorkItemActionEndpoints` landed, the only legal
  /// request-side state transition. It is now the FIRST of two: the second is
  /// the operator action surface on a work item parked in a failure state
  /// (`work_item_action_endpoints.dart` — `retryFailedWorkItem` /
  /// `stopFailedWorkItem`), which is deliberately a separate endpoint class so
  /// this comment and `ControlPlaneService`'s had to be amended rather than
  /// left quietly false.
  ///
  /// What still holds is the part that matters: there is still no third path,
  /// and neither of these writes SQL or sets `WorkItem.state` directly. Both go
  /// through `DurableWorkflowEngine` under the injected policy, both are
  /// idempotent under a client-minted key, and a repeated call replays the
  /// prior outcome instead of re-applying the transition.
  _i2.Future<_i44.ResolveDecisionView> resolveDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String algorithm,
    required String publicKey,
    required String signature,
    required DateTime signedAt,
  }) => caller.callServerEndpoint<_i44.ResolveDecisionView>(
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
         _i45.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
       ) {
    credentialEndpoints = EndpointCredentialEndpoints(this);
    defectEndpoints = EndpointDefectEndpoints(this);
    executionEndpoints = EndpointExecutionEndpoints(this);
    healthEndpoints = EndpointHealthEndpoints(this);
    homeEndpoints = EndpointHomeEndpoints(this);
    humanDirectionEndpoints = EndpointHumanDirectionEndpoints(this);
    intakeEndpoints = EndpointIntakeEndpoints(this);
    productRegistryEndpoints = EndpointProductRegistryEndpoints(this);
    providerHealthEndpoints = EndpointProviderHealthEndpoints(this);
    schedulerEndpoints = EndpointSchedulerEndpoints(this);
    workItemActionEndpoints = EndpointWorkItemActionEndpoints(this);
    workerEndpoints = EndpointWorkerEndpoints(this);
    workflowEndpoints = EndpointWorkflowEndpoints(this);
  }

  late final EndpointCredentialEndpoints credentialEndpoints;

  late final EndpointDefectEndpoints defectEndpoints;

  late final EndpointExecutionEndpoints executionEndpoints;

  late final EndpointHealthEndpoints healthEndpoints;

  late final EndpointHomeEndpoints homeEndpoints;

  late final EndpointHumanDirectionEndpoints humanDirectionEndpoints;

  late final EndpointIntakeEndpoints intakeEndpoints;

  late final EndpointProductRegistryEndpoints productRegistryEndpoints;

  late final EndpointProviderHealthEndpoints providerHealthEndpoints;

  late final EndpointSchedulerEndpoints schedulerEndpoints;

  late final EndpointWorkItemActionEndpoints workItemActionEndpoints;

  late final EndpointWorkerEndpoints workerEndpoints;

  late final EndpointWorkflowEndpoints workflowEndpoints;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {
    'credentialEndpoints': credentialEndpoints,
    'defectEndpoints': defectEndpoints,
    'executionEndpoints': executionEndpoints,
    'healthEndpoints': healthEndpoints,
    'homeEndpoints': homeEndpoints,
    'humanDirectionEndpoints': humanDirectionEndpoints,
    'intakeEndpoints': intakeEndpoints,
    'productRegistryEndpoints': productRegistryEndpoints,
    'providerHealthEndpoints': providerHealthEndpoints,
    'schedulerEndpoints': schedulerEndpoints,
    'workItemActionEndpoints': workItemActionEndpoints,
    'workerEndpoints': workerEndpoints,
    'workflowEndpoints': workflowEndpoints,
  };

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {};
}
