/// One file the reporter attached to the form.
///
/// The bytes are not held in the bloc: the platform has no artifact store yet,
/// so what survives the submit is the file's name, size and SHA-256, recorded
/// as defect evidence metadata. That is stated plainly rather than implying an
/// upload happened.
class CreateDefectEvidenceFile {
  const CreateDefectEvidenceFile({
    required this.name,
    required this.size,
    required this.sha256,
  });

  final String name;
  final int size;
  final String sha256;

  /// `screenshot.png (12.4 KB)` — what the evidence row reads back as.
  String get description {
    if (size < 1024) return '$name ($size B)';
    if (size < 1024 * 1024) {
      return '$name (${(size / 1024).toStringAsFixed(1)} KB)';
    }
    return '$name (${(size / (1024 * 1024)).toStringAsFixed(1)} MB)';
  }
}

class CreateDefectState {
  CreateDefectState({
    this.title = '',
    this.description = '',
    this.expectedBehavior = '',
    this.reproductionSteps = '',
    this.severity,
    this.intakeCategory,
    this.productId,
    this.affectedWorkItemId,
    this.evidence = const [],
    this.products = const [],
    this.workItems = const [],
    this.optionsLoading = false,
    this.prefilledWorkItemId,
    this.prefilledRunId,
    this.clientContextJson,
    this.isSubmitting = false,
    this.createdDefectId,
    this.success = false,
    this.errorMessage,
    this.partialFailureMessage,
  })
    // Two facts that must never be true at once, asserted rather than left to
    // convention:
    //
    //  * `success` means a defect reference exists. Without one there is
    //    nothing for the operator to act on, so a "success" the page cannot
    //    render is a defect the page would silently hide.
    //  * `errorMessage` means NOTHING WAS CREATED. A submission that created a
    //    defect is not a failed submission, and reporting it as one strands a
    //    real reference and invites the operator to file a duplicate. A failure
    //    that happens after the write — evidence that would not attach — is a
    //    partial failure and travels on [partialFailureMessage].
    //
    // These run in every test and in every DEBUG build. They are NOT a release
    // guard: `flutter build web --release` — the command docker/Dockerfile.client
    // ships — strips them (flutter_tools web/compiler_config.dart gates
    // `--enable-asserts` on BuildMode.debug). In the released bundle the
    // invariant rests on `CreateDefectBloc` having exactly one success emitter.
    // Independent review 2026-10-16 (dcaf538): reverting the page's guard this
    // assert backs turns ZERO tests red, precisely because the assert makes that
    // state unconstructable in a test. Do not "simplify" this by deleting the
    // page guard and trusting the assert.
    : assert(
         !success || (createdDefectId != null && createdDefectId.isNotEmpty),
         'success requires a created defect reference: a success the page cannot '
         'render would be swallowed by the form.',
       ),
       assert(
         !success || errorMessage == null,
         'success and a failure-bearing errorMessage must never both be set: '
         'that is the contradiction that reports a created defect as a failed '
         'submission. Use partialFailureMessage for a failure after the write.',
       );

  final String title;
  final String description;
  final String expectedBehavior;
  final String reproductionSteps;
  final String? severity;
  final String? intakeCategory;

  /// The product chosen at report time, when one was. Persisted on the defect
  /// so a report no longer has to reach it through an affected work item.
  final String? productId;

  /// The work item the reporter says is affected. Falls back to
  /// [prefilledWorkItemId] when the form was opened from a work item.
  final String? affectedWorkItemId;
  final List<CreateDefectEvidenceFile> evidence;

  /// `id` / `name` pairs for the product dropdown.
  final List<(String, String)> products;

  /// `id` / label pairs for the affected-work-item dropdown, already narrowed
  /// to [productId] when one is chosen.
  final List<(String, String)> workItems;
  final bool optionsLoading;

  final String? prefilledWorkItemId;
  final String? prefilledRunId;
  final String? clientContextJson;
  final bool isSubmitting;
  final String? createdDefectId;

  /// A submission that produced a defect reference. Never true together with a
  /// non-null [errorMessage] — the constructor refuses that state.
  final bool success;

  /// The submission failed and nothing was created. Always accompanied by a
  /// null [createdDefectId].
  final String? errorMessage;

  /// The defect WAS created, but something attached to the form was not.
  ///
  /// This is deliberately not [errorMessage]. The report exists and its
  /// reference is real; only the attachment is missing, and an operator has to
  /// be able to see which file was lost without being told the report itself
  /// failed.
  final String? partialFailureMessage;

  /// True only when a submission produced a reference there is something to
  /// show. [success] says the write landed; this says there is a reference.
  bool get hasCreatedReference =>
      createdDefectId != null && createdDefectId!.isNotEmpty;

  /// The defect exists and at least one attachment did not make it.
  bool get hasPartialFailure => partialFailureMessage != null;

  /// The work item that will actually be attached, if any.
  String? get effectiveWorkItemId => affectedWorkItemId ?? prefilledWorkItemId;

  bool get isValid =>
      title.trim().isNotEmpty &&
      description.trim().isNotEmpty &&
      expectedBehavior.trim().isNotEmpty &&
      severity != null &&
      productId != null;

  CreateDefectState copyWith({
    String? title,
    String? description,
    String? expectedBehavior,
    String? reproductionSteps,
    String? severity,
    String? intakeCategory,
    String? productId,
    String? affectedWorkItemId,
    List<CreateDefectEvidenceFile>? evidence,
    List<(String, String)>? products,
    List<(String, String)>? workItems,
    bool? optionsLoading,
    String? prefilledWorkItemId,
    String? prefilledRunId,
    String? clientContextJson,
    bool? isSubmitting,
    String? createdDefectId,
    bool? success,
    String? errorMessage,
    String? partialFailureMessage,
    bool clearError = false,
    bool clearPartialFailure = false,
    bool clearProduct = false,
    bool clearAffectedWorkItem = false,
  }) {
    return CreateDefectState(
      title: title ?? this.title,
      description: description ?? this.description,
      expectedBehavior: expectedBehavior ?? this.expectedBehavior,
      reproductionSteps: reproductionSteps ?? this.reproductionSteps,
      severity: severity ?? this.severity,
      intakeCategory: intakeCategory ?? this.intakeCategory,
      productId: clearProduct ? null : (productId ?? this.productId),
      affectedWorkItemId: clearAffectedWorkItem
          ? null
          : (affectedWorkItemId ?? this.affectedWorkItemId),
      evidence: evidence ?? this.evidence,
      products: products ?? this.products,
      workItems: workItems ?? this.workItems,
      optionsLoading: optionsLoading ?? this.optionsLoading,
      prefilledWorkItemId: prefilledWorkItemId ?? this.prefilledWorkItemId,
      prefilledRunId: prefilledRunId ?? this.prefilledRunId,
      clientContextJson: clientContextJson ?? this.clientContextJson,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      createdDefectId: createdDefectId ?? this.createdDefectId,
      success: success ?? this.success,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      partialFailureMessage: clearPartialFailure
          ? null
          : (partialFailureMessage ?? this.partialFailureMessage),
    );
  }

  static const List<(String, String)> severityOptions = [
    ('cosmetic', 'Cosmetic'),
    ('annoying', 'Annoying'),
    ('blocking', 'Blocking'),
    ('data_loss', 'Data Loss'),
  ];

  static const List<(String, String)> intakeCategoryOptions = [
    ('visual_bug', 'Visual Bug'),
    ('incorrect_behavior', 'Incorrect Behavior'),
    ('usability_issue', 'Usability Issue'),
    ('browser_specific', 'Browser-Specific'),
    ('intermittent_failure', 'Intermittent Failure'),
    ('unexpected_state', 'Unexpected State'),
    ('other', 'Other'),
  ];
}
