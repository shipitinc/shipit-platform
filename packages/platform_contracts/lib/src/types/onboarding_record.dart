import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import 'workspace_descriptor.dart';

part 'onboarding_record.g.dart';

/// Durable onboarding progress for one Product.
///
/// Onboarding writes a bounded bootstrap record (checkpoint 006 §4.2/§18):
/// the Product lifecycle stays on the existing `ProductState` enum; this
/// record tracks the onboarding/progress itself and is what a restarted
/// execution resumes (same Product, same baseline lineage, same clarifications).
///
/// ## What this record is the home of
///
/// This is the ONE persisted, queryable home of a Product's pinned git
/// revision and its workspace. Neither half lives anywhere else:
///
///   * [pinnedRevision] is the full 40-hex commit SHA the Product is pinned to
///     — the answer to "which commit is this product at?", and
///   * [workspace] is the [WorkspaceDescriptor] of the workspace that commit
///     was materialised in — the answer to "where does this product's code
///     live on disk?".
///
/// Both are NULLABLE, and that is deliberate. A Product exists in the registry
/// long before anyone clones it, so "not yet pinned" is a real, common state
/// and not a defect; making the columns NOT NULL would force onboarding to
/// fabricate an answer it does not have. Read [hasDurableWorkspace] rather
/// than testing the fields for null — it is the single place that says whether
/// the full answer exists.
///
/// ## Why the pin is a String and not an extension of [currentBaselineRevision]
///
/// [currentBaselineRevision] is a MONOTONIC SEQUENCE COUNTER, and it stays
/// one. It orders revisions, it is produced by `nextBaselineRevision`
/// (max + 1), and `ProductRegistryEngine.approveBaseline` refuses a decision
/// against an "overtaken" revision by comparing those counters. A git SHA is
/// neither ordered nor comparable that way, and overwriting the counter with an
/// opaque content address would destroy every read that depends on the
/// ordering while looking like it added information. ADR 0012 already keeps the
/// two apart in its own model (`ArtifactManifest.gitCommit`, a full SHA, beside
/// `DeploymentArtifact.version`), so the record keeps them apart too.
///
/// [pinnedRevision] is stored in the same form ADR 0012 mandates for an
/// artifact's git identity and the same form
/// `schemas/workspace_descriptor.schema.json` mandates for
/// `WorkspaceDescriptor.startingRevision`: lowercase 40-hex. That is what makes
/// the pair self-checking — see [validate].
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class OnboardingRecord extends Equatable {
  const OnboardingRecord({
    required this.onboardingId,
    required this.productId,
    this.currentBaselineRevision = 0,
    this.pendingClarifications = 0,
    this.completed = false,
    this.pinnedRevision,
    this.workspace,
    this.completedBaselineId,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  final String onboardingId;
  final String productId;

  /// Highest baseline revision proposed/produced so far (0 = none yet).
  ///
  /// A SEQUENCE COUNTER, not a git revision. See the class doc.
  final int currentBaselineRevision;

  /// Number of clarifications awaiting a human answer right now.
  final int pendingClarifications;

  /// True once an exact baseline revision reached human acceptance.
  ///
  /// ## A consumer must not trust this flag on its own
  ///
  /// This is a BARE BOOL and carries no evidence of its own. It is set
  /// together with [completedBaselineId] by
  /// `ProductRegistryEngine.approveBaseline`, which is the only path that sets
  /// it, and that path also sets [currentBaselineRevision] to the accepted
  /// revision — so the three together name an artifact that a human accepted,
  /// which is checkable against `product_baseline` (`status = accepted`,
  /// `acceptedBy`, `acceptedDecisionId`).
  ///
  /// It is deliberately NOT enforced as `completed ⟹ completedBaselineId !=
  /// null`, because the store contract suite constructs a record with
  /// `completed: true` and no baseline pointer, and turning that into a
  /// `FormatException` would break a published contract test to enforce an
  /// invariant nothing needs. [hasCompletionEvidence] is the read that checks
  /// it without forbidding the weaker state.
  final bool completed;

  /// The full lowercase 40-hex commit SHA this Product is pinned to, or null
  /// when nothing has pinned it yet.
  ///
  /// Immutable once set by a real decision; a re-pin is a new onboarding run,
  /// and the audit log is where the history of pins lives — not this column,
  /// which answers "where is it NOW".
  final String? pinnedRevision;

  /// The workspace [pinnedRevision] was materialised in, or null when no
  /// workspace has been recorded.
  ///
  /// Embedded as a value object rather than normalised into a table of its
  /// own, for reasons that are recorded in full on the class: it is already a
  /// value object, it already has a JSON Schema, it is already stored as a
  /// JSON blob wherever else it is persisted (`agent_execution.workspaceJson`),
  /// and a third home for the same descriptor is the thing this lane exists to
  /// prevent.
  ///
  /// A DELETED workspace is recorded here as [WorkspaceDescriptor.isCleaned],
  /// not by nulling this field — [WorkspaceDescriptor.markCleaned] exists for
  /// exactly that transition. That is why "the record names a workspace" and
  /// "the record names a workspace that still exists on disk" are two
  /// different reads; see [hasLiveWorkspace].
  final WorkspaceDescriptor? workspace;

  /// The `ProductBaseline.baselineId` whose human acceptance set [completed].
  ///
  /// The EVIDENCE POINTER for [completed]. Null on a record that is not
  /// completed, and also null on the weaker completed-without-evidence state
  /// the store contract permits; [hasCompletionEvidence] distinguishes them.
  final String? completedBaselineId;

  final DateTime createdAt;
  final DateTime updatedAt;

  final int version;

  /// The full lowercase 40-hex form a git revision must take to be stored here.
  ///
  /// The same pattern `schemas/workspace_descriptor.schema.json` applies to
  /// `WorkspaceDescriptor.startingRevision`, and the same form ADR 0012's
  /// `ArtifactManifest.gitCommit` documents. Abbreviated SHAs, `HEAD`, branch
  /// names and uppercase hex are all rejected: a pin that cannot be resolved
  /// to exactly one commit is not a pin.
  static final RegExp gitRevisionPattern = RegExp(r'^[0-9a-f]{40}$');

  /// True when a workspace is recorded AND it has not been cleaned.
  ///
  /// False for a record with no workspace and equally false for one whose
  /// workspace was deleted — the two cases need different handling and must not
  /// be read as one, which is why this is not simply `workspace != null`.
  bool get hasLiveWorkspace => workspace != null && !workspace!.isCleaned;

  /// True when the record carries BOTH halves of the durable answer: a commit
  /// to pin to and a workspace that still exists to materialise it in.
  ///
  /// This — not a null check on either field — is what "which commit is this
  /// product at, and where does it live?" should be read against.
  bool get hasDurableWorkspace => pinnedRevision != null && hasLiveWorkspace;

  /// True when [completed] is accompanied by the baseline that earned it.
  ///
  /// The completion read a consumer should use in place of [completed] alone.
  bool get hasCompletionEvidence =>
      completed && completedBaselineId != null && currentBaselineRevision > 0;

  OnboardingRecord copyWith({
    int? currentBaselineRevision,
    int? pendingClarifications,
    bool? completed,
    String? pinnedRevision,
    WorkspaceDescriptor? workspace,
    String? completedBaselineId,
    DateTime? updatedAt,
    int? version,
  }) => OnboardingRecord(
    onboardingId: onboardingId,
    productId: productId,
    currentBaselineRevision:
        currentBaselineRevision ?? this.currentBaselineRevision,
    pendingClarifications: pendingClarifications ?? this.pendingClarifications,
    completed: completed ?? this.completed,
    pinnedRevision: pinnedRevision ?? this.pinnedRevision,
    workspace: workspace ?? this.workspace,
    completedBaselineId: completedBaselineId ?? this.completedBaselineId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
  );

  factory OnboardingRecord.fromJson(Map<String, dynamic> json) =>
      _$OnboardingRecordFromJson(json);

  Map<String, dynamic> toJson() => _$OnboardingRecordToJson(this);

  /// Checks the invariants this record's two new halves depend on, and throws
  /// [FormatException] naming the offender.
  ///
  /// ## Why the two stored revisions must agree
  ///
  /// [pinnedRevision] and `WorkspaceDescriptor.startingRevision` are the same
  /// commit by construction — the workspace is created FROM the pin — so a
  /// record carrying two different SHAs is not a record with two answers, it
  /// is a record whose answers contradict, and every later reader has to pick
  /// one. Nothing downstream could detect that: both are well-formed 40-hex
  /// strings, so each field passes a shape check on its own. Checking them
  /// together is the only place the contradiction is visible.
  ///
  /// ## Why this is a store concern and not a constructor one
  ///
  /// The constructor is `const`, and a `const` constructor cannot validate
  /// without ceasing to be one — which every existing `const OnboardingRecord`
  /// in the repository depends on. Both store tiers therefore call this before
  /// writing, which puts the check on the boundary where a malformed pin would
  /// actually enter the database, once, with one definition.
  ///
  /// ## What is deliberately NOT checked here
  ///
  /// [completed] against [completedBaselineId]. Enforcing it would reject the
  /// completed-without-evidence record the published store contract suite
  /// writes. See [hasCompletionEvidence].
  void validate() {
    final pin = pinnedRevision;
    if (pin != null && !gitRevisionPattern.hasMatch(pin)) {
      throw FormatException(
        'OnboardingRecord $onboardingId has pinnedRevision "$pin", which is '
        'not a full lowercase 40-hex git commit SHA',
        pin,
      );
    }
    final ws = workspace;
    if (ws != null && !gitRevisionPattern.hasMatch(ws.startingRevision)) {
      throw FormatException(
        'OnboardingRecord $onboardingId has a workspace whose '
        'startingRevision "${ws.startingRevision}" is not a full lowercase '
        '40-hex git commit SHA',
        ws.startingRevision,
      );
    }
    if (pin != null && ws != null && pin != ws.startingRevision) {
      throw FormatException(
        'OnboardingRecord $onboardingId is pinned to $pin but its workspace '
        'starts at ${ws.startingRevision}; the pin and the workspace must '
        'name the same commit',
      );
    }
  }

  @override
  List<Object?> get props => [
    onboardingId,
    productId,
    currentBaselineRevision,
    pendingClarifications,
    completed,
    pinnedRevision,
    workspace,
    completedBaselineId,
    createdAt,
    updatedAt,
    version,
  ];
}
