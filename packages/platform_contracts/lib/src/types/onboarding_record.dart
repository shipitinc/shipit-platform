import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import 'durable_workspace_descriptor.dart';
import 'workspace_descriptor.dart';

// Re-exported rather than added to `platform_contracts.dart`: a consumer that
// imports the barrel already reaches `DurableWorkspaceDescriptor` through this
// file, and the barrel itself is outside this change's ownership.
export 'durable_workspace_descriptor.dart';

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
///   * [workspace] names the checkout that commit was materialised in — the
///     answer to "where does this product's code live on disk?". It is an
///     [OnboardingWorkspace] holding **exactly one** of a per-execution
///     [WorkspaceDescriptor] or a product-scoped
///     [DurableWorkspaceDescriptor]; see the field's own docs for the `kind`
///     discriminator that tells them apart.
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
  OnboardingRecord({
    required this.onboardingId,
    required this.productId,
    this.currentBaselineRevision = 0,
    this.pendingClarifications = 0,
    this.completed = false,
    this.pinnedRevision,
    Object? workspace,
    this.completedBaselineId,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  }) : workspace = OnboardingWorkspace.normalise(workspace);

  /// Why this constructor is no longer `const`.
  ///
  /// It was, and nothing in the repository constructs a `const OnboardingRecord`
  /// — verified by search, so the capability was never used. It could not
  /// survive this change anyway: normalising [workspace] into an
  /// [OnboardingWorkspace] is work a `const` constructor may not do, and the
  /// alternative (leaving the parameter as the raw union and normalising at the
  /// read) would put the `kind` discrimination outside the one place that can
  /// refuse it. The decision is taken here rather than silently, and
  /// [validate]'s note about `const` has been corrected to match.

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
  /// ## One column, two shapes, and an explicit discriminator
  ///
  /// This field holds an [OnboardingWorkspace], which is **exactly one** of:
  ///
  ///   * a per-execution [WorkspaceDescriptor] — the shape this column had
  ///     before, unchanged and still writable, and
  ///   * a product-scoped [DurableWorkspaceDescriptor] — a clone that survives
  ///     container restarts and is read back by every later execution.
  ///
  /// The two are distinguished by [DurableWorkspaceDescriptor.kind], a constant
  /// literal. A reader MUST discriminate on it and refuse the other shape
  /// rather than coerce between them: a record naming the wrong kind is a
  /// fail-closed error, not a fallback. See [OnboardingWorkspace.requireDurable]
  /// and [OnboardingWorkspace.requireExecution].
  ///
  /// Embedded as a value object rather than normalised into a table of its own,
  /// for reasons that are recorded in full on the class: it is already a value
  /// object, it already has JSON Schemas, and it is already stored as a JSON
  /// blob wherever else it is persisted. A second home for the same descriptor
  /// is the thing this lane exists to prevent.
  ///
  /// ## Why the constructor takes `Object?` and this field does not
  ///
  /// The constructor and [copyWith] accept a [WorkspaceDescriptor], a
  /// [DurableWorkspaceDescriptor] or an [OnboardingWorkspace], and normalise
  /// through [OnboardingWorkspace.normalise], which refuses everything else
  /// with an [ArgumentError]. A typed union parameter is not available in Dart,
  /// and the alternative — `WorkspaceDescriptor` and `DurableWorkspaceDescriptor`
  /// sharing a supertype — would require adding `implements` to
  /// `WorkspaceDescriptor`, which decision `c04f6a8d` binds READ-ONLY for
  /// every unit. So the WIDE type is at the write boundary and the NARROW one
  /// is everywhere it is read, which is the direction the safety of this
  /// column actually runs: what matters is that no reader can receive a shape it
  /// did not discriminate for.
  ///
  /// A DELETED per-execution workspace is recorded as
  /// [WorkspaceDescriptor.isCleaned], not by nulling this field —
  /// [WorkspaceDescriptor.markCleaned] exists for exactly that transition. A
  /// durable clone has no cleaned state at all yet ([DurableWorkspaceDescriptor]
  /// explains why), so "the record names a workspace" and "the record names a
  /// workspace that still exists on disk" are two different reads; see
  /// [hasLiveWorkspace].
  ///
  /// The decoder is named on the FIELD rather than on the constructor parameter
  /// because that is where `json_serializable` reads `@JsonKey` from, and
  /// because the field — not the parameter — is what the generated factory
  /// produces. Without it the generated `fromJson` hands the raw JSON document
  /// straight to the constructor, and every decode of a stored record would
  /// fail on a shape it had never been told how to identify.
  @JsonKey(fromJson: decodeOnboardingWorkspace)
  final OnboardingWorkspace? workspace;

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
    Object? workspace,
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
  /// The constructor used to be `const`, and a `const` constructor cannot
  /// validate without ceasing to be one. It no longer is `const` — normalising
  /// [workspace] is not a const expression — so validating here is no longer
  /// forced, it is **chosen**: the check stays where both store tiers can call
  /// it before a malformed pin enters the database, once, with one definition.
  /// Moving it into the constructor instead would fire on every intermediate
  /// build of a record, including the ones a store assembles field by field,
  /// and would make the refusal a construction failure rather than a boundary
  /// check the store contract suite can assert on.
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

/// The `workspace` value of one [OnboardingRecord]: **exactly one** of the two
/// descriptor shapes that column is allowed to carry.
///
/// ## Why a holder and not a third type
///
/// `OnboardingRecord.workspace` is one JSON column, and it now holds two
/// documents that do not resemble each other. Neither existing type can become
/// the other's supertype — making them share an interface would mean editing
/// `WorkspaceDescriptor`, which decision `c04f6a8d` binds READ-ONLY for every
/// unit, precisely so the per-execution consumers stay untouched.
///
/// So the union lives one level up, in a holder that can hold one or the other
/// and **never both**. Holding both is not representable: both constructors take
/// exactly one descriptor and set the other half to `null`, and there is no
/// constructor that takes two.
///
/// ## Why the discriminator is a literal, not an enum
///
/// One column, two shapes, and the durable one says `"kind": "durable"` on the
/// wire. `DurableWorkspaceDescriptor.kind` is the authority for that literal
/// ([kDurableWorkspaceKind]); `durable` as a getter value below is only what a
/// reader sees after the document has already been discriminated. An enum would
/// have put the wire format in a file the writer of the descriptor does not own.
///
/// ## Why there is no implicit coercion
///
/// [requireDurable] and [requireExecution] throw rather than returning null, and
/// there is no "if it parses, accept it" path anywhere in [fromJson]. A record
/// naming the wrong kind is a fail-closed error, never a fallback: silently
/// treating a product's durable clone as some worker execution's worktree is
/// fabricated provenance, and that is the defect class this repository has
/// already caught once.
@immutable
class OnboardingWorkspace extends Equatable {
  const OnboardingWorkspace._({this.execution, this.durable})
    : assert(
        (execution == null) != (durable == null),
        'an OnboardingWorkspace holds exactly one descriptor, never zero and '
        'never both',
      );

  /// A per-execution `WorkspaceDescriptor`, held unchanged.
  const OnboardingWorkspace.execution(WorkspaceDescriptor descriptor)
    : this._(execution: descriptor);

  /// A product-scoped [DurableWorkspaceDescriptor], held unchanged.
  const OnboardingWorkspace.durable(DurableWorkspaceDescriptor descriptor)
    : this._(durable: descriptor);

  /// The per-execution descriptor, or `null` when this holds a durable one.
  ///
  /// Read it through [requireExecution] where the shape matters: a bare `!=
  /// null` is how the two shapes get confused.
  final WorkspaceDescriptor? execution;

  /// The durable descriptor, or `null` when this holds a per-execution one.
  ///
  /// Read it through [requireDurable] where the shape matters.
  final DurableWorkspaceDescriptor? durable;

  /// `durable` or `execution` — which of the two shapes this holds.
  ///
  /// Note that only the DURABLE shape carries a `kind` literal on the wire.
  /// The per-execution document is the frozen `WorkspaceDescriptor` schema and
  /// predates the discriminator, so it is identified by its ABSENCE — which is
  /// exactly what [fromJson] does.
  String get kind =>
      durable != null ? kDurableWorkspaceKind : _executionWorkspaceKind;

  static const String _executionWorkspaceKind = 'execution';

  /// The checkout path, whichever shape this holds.
  ///
  /// Both descriptors carry one, and it is the field a caller almost always
  /// wants. This is deliberately a [String] and not a descriptor: returning a
  /// typed descriptor here would hand back a shape the caller has not
  /// discriminated for, which is the coercion this class exists to prevent.
  String get repositoryPath =>
      durable != null ? durable!.repositoryPath : execution!.repositoryPath;

  /// The pinned commit, whichever shape this holds.
  ///
  /// Both descriptors pin to exactly one 40-hex commit, and
  /// [OnboardingRecord.validate] pairs this with `pinnedRevision` — the pairing
  /// is shape-independent because the invariant is the same for both.
  String get startingRevision =>
      durable != null ? durable!.startingRevision : execution!.startingRevision;

  /// The workspace id, whichever shape this holds.
  String get workspaceId =>
      durable != null ? durable!.workspaceId : execution!.workspaceId;

  /// Whether the named workspace has been deleted.
  ///
  /// Always `false` for a durable clone, which has no cleaned state: nothing
  /// deletes a product's only checkout yet, because who presses it is an open
  /// decision. See [DurableWorkspaceDescriptor].
  bool get isCleaned => execution?.isCleaned ?? false;

  /// The durable descriptor, or a [FormatException] naming what was found.
  ///
  /// The fail-closed read a caller should use when it means "this product's
  /// durable clone". There is deliberately no nullable-returning sibling: the
  /// nullable one is [durable], and it is a field, not an answer.
  DurableWorkspaceDescriptor requireDurable() {
    final found = durable;
    if (found == null) {
      throw FormatException(
        'a durable workspace was required, but this record holds an '
        '${_executionWorkspaceKind}-scoped descriptor for workspace '
        '${workspaceId}; the two shapes are never interchangeable',
        workspaceId,
      );
    }
    return found;
  }

  /// The per-execution descriptor, or a [FormatException] naming what was found.
  WorkspaceDescriptor requireExecution() {
    final found = execution;
    if (found == null) {
      throw FormatException(
        'a per-execution workspace was required, but this record holds a '
        'durable product clone for workspace $workspaceId; the two shapes are '
        'never interchangeable',
        workspaceId,
      );
    }
    return found;
  }

  /// Normalises what a caller may hand the record constructor or [copyWith].
  ///
  /// ## Why this is the one wide place in the chain
  ///
  /// `OnboardingRecord.workspace` is declared [OnboardingWorkspace] so no
  /// reader can receive a shape it did not discriminate for. Its CONSTRUCTOR
  /// takes `Object?` because Dart has no union types and the alternative —
  /// adding `implements` to `WorkspaceDescriptor` — is forbidden by decision
  /// `c04f6a8d`. The wide type is therefore on the write boundary only, and
  /// this exhaustive switch is where it is narrowed. An unrecognised value is
  /// refused at construction rather than carried, so a mistyped descriptor can
  /// never reach a store.
  static OnboardingWorkspace? normalise(Object? value) => switch (value) {
    null => null,
    final OnboardingWorkspace held => held,
    final WorkspaceDescriptor descriptor => OnboardingWorkspace.execution(
      descriptor,
    ),
    final DurableWorkspaceDescriptor descriptor => OnboardingWorkspace.durable(
      descriptor,
    ),
    _ => throw ArgumentError.value(
      value,
      'workspace',
      'must be a WorkspaceDescriptor, a DurableWorkspaceDescriptor, an '
          'OnboardingWorkspace, or null',
    ),
  };

  /// Reads the column's JSON, or refuses a document whose shape it does not know.
  ///
  /// Three outcomes and no fourth:
  ///
  ///   * `kind: "durable"` → [DurableWorkspaceDescriptor.fromJson], which
  ///     itself refuses anything but that exact literal;
  ///   * no `kind` at all, but the per-execution fields present → the frozen
  ///     `WorkspaceDescriptor` shape; and
  ///   * anything else → [FormatException].
  ///
  /// The third outcome is the one that matters. A document that is neither is
  /// not a workspace this record can name, and guessing which shape it was
  /// meant to be is how a wrong-kind record becomes a silently accepted one.
  factory OnboardingWorkspace.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'];
    if (rawKind == null) {
      // Absence of the discriminator is what identifies the OLD shape, so it is
      // only accepted together with the fields that shape cannot be read
      // without. A document with neither a `kind` nor those fields is
      // unidentifiable, and an unidentifiable document is refused.
      const executionOnly = <String>[
        'workerExecutionId',
        'workerId',
        'worktreePath',
      ];
      final missing = executionOnly.where((f) => !json.containsKey(f));
      if (missing.isNotEmpty) {
        throw FormatException(
          'a workspace document carries no "kind" and none of the '
          'per-execution fields (${executionOnly.join(", ")}), so its shape '
          'cannot be identified',
          missing.toList(),
        );
      }
      return OnboardingWorkspace.execution(WorkspaceDescriptor.fromJson(json));
    }
    if (rawKind == kDurableWorkspaceKind) {
      return OnboardingWorkspace.durable(
        DurableWorkspaceDescriptor.fromJson(json),
      );
    }
    throw FormatException(
      'a workspace document carries "kind": "$rawKind", which is neither '
      '"$kDurableWorkspaceKind" nor an absent kind naming the per-execution '
      'shape',
      rawKind,
    );
  }

  /// The column's JSON, produced by whichever descriptor this holds.
  Map<String, dynamic> toJson() {
    final durableDescriptor = durable;
    if (durableDescriptor != null) return durableDescriptor.toJson();
    return execution!.toJson();
  }

  @override
  List<Object?> get props => [execution, durable];

  @override
  String toString() => 'OnboardingWorkspace($kind, workspaceId: $workspaceId)';
}

/// Decodes the `workspace` column, or refuses a document it cannot identify.
///
/// Wired into [OnboardingRecord]'s generated `fromJson` through
/// `@JsonKey(fromJson: ...)` and named publicly so the function the generator
/// calls is greppable from either side.
///
/// Three inputs and three outcomes:
///
///   * `null` → no workspace recorded, which is an ordinary state;
///   * a `Map` → [OnboardingWorkspace.fromJson], which discriminates on `kind`
///     and throws [FormatException] on anything it cannot identify; and
///   * an already-typed descriptor or holder → passed through unchanged, so a
///     caller that round-trips an in-memory value is not forced through JSON.
///
/// A bare `Map` of the wrong shape therefore fails at the decode, which is the
/// boundary where a wrong-kind record would otherwise enter a store, rather than
/// at some later reader that would have to guess which shape it was handed.
OnboardingWorkspace? decodeOnboardingWorkspace(Object? raw) => switch (raw) {
  null => null,
  final Map<String, dynamic> document => OnboardingWorkspace.fromJson(document),
  _ => OnboardingWorkspace.normalise(raw),
};
