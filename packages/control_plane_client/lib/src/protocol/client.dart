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
import 'package:control_plane_client/src/protocol/worker_list_view.dart'
    as _i36;
import 'package:control_plane_client/src/protocol/worker_execution_list_view.dart'
    as _i37;
import 'package:control_plane_client/src/protocol/worker_execution_inspection_view.dart'
    as _i38;
import 'package:control_plane_client/src/protocol/job_summary_view.dart'
    as _i39;
import 'package:control_plane_client/src/protocol/work_item_detail_view.dart'
    as _i40;
import 'package:control_plane_client/src/protocol/resolve_decision_view.dart'
    as _i41;
import 'protocol.dart' as _i42;

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

  /// Records platform-verified evidence against a proposed baseline.
  _i2.Future<_i23.ProductDetailView> verifyBaseline({
    required String productId,
    required String baselineId,
    required String verifiedBy,
    required String kind,
  }) => caller.callServerEndpoint<_i23.ProductDetailView>(
    'productRegistryEndpoints',
    'verifyBaseline',
    {
      'productId': productId,
      'baselineId': baselineId,
      'verifiedBy': verifiedBy,
      'kind': kind,
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
  _i2.Future<_i36.WorkerListView> listWorkers() =>
      caller.callServerEndpoint<_i36.WorkerListView>(
        'workerEndpoints',
        'listWorkers',
        {},
      );

  /// Lists worker executions, newest first. Reads only.
  _i2.Future<_i37.WorkerExecutionListView> listExecutions({
    String? workItemId,
  }) => caller.callServerEndpoint<_i37.WorkerExecutionListView>(
    'workerEndpoints',
    'listExecutions',
    {'workItemId': workItemId},
  );

  /// Returns one execution, its events and (if present) its result. Reads only.
  _i2.Future<_i38.WorkerExecutionInspectionView> inspect({
    required String workerExecutionId,
  }) => caller.callServerEndpoint<_i38.WorkerExecutionInspectionView>(
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
  _i2.Future<List<_i39.JobSummaryView>> jobsForWorkItem({
    required String workItemId,
  }) => caller.callServerEndpoint<List<_i39.JobSummaryView>>(
    'workflowEndpoints',
    'jobsForWorkItem',
    {'workItemId': workItemId},
  );

  /// Returns the current work item and its transition history. Never mutates
  /// state; `WorkItem.state` on the wire is always reported, never written.
  _i2.Future<_i40.WorkItemDetailView> inspect({required String workItemId}) =>
      caller.callServerEndpoint<_i40.WorkItemDetailView>(
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
  /// This is the only legal request-side state transition. The decision,
  /// its resolution, and the resulting work item move are persisted
  /// transactionally; a repeated call is an idempotent replay, so retries
  /// after a network failure never double-apply the transition.
  _i2.Future<_i41.ResolveDecisionView> resolveDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String algorithm,
    required String publicKey,
    required String signature,
    required DateTime signedAt,
  }) => caller.callServerEndpoint<_i41.ResolveDecisionView>(
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
         _i42.Protocol(),
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
    'workerEndpoints': workerEndpoints,
    'workflowEndpoints': workflowEndpoints,
  };

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {};
}
