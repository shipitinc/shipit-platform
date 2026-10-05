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
  });

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
  final bool success;
  final String? errorMessage;

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
    bool clearError = false,
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
