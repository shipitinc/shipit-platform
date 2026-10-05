import 'package:flutter/foundation.dart';

/// The `Request a feature` form's state.
///
/// [state] is the workflow state the created work item was filed in, not a
/// form field: it is read back from the server so the success panel reports
/// what was actually written rather than what the form hoped for.
@immutable
class CreateFeatureRequestState {
  const CreateFeatureRequestState({
    this.title = '',
    this.description = '',
    this.productId,
    this.products = const [],
    this.optionsLoading = false,
    this.attemptedSubmit = false,
    this.isSubmitting = false,
    this.success = false,
    this.createdWorkItemId,
    this.createdTitle,
    this.createdState,
    this.errorMessage,
  });

  final String title;

  /// The reporter's own words for the use case. This is the field that decides
  /// whether an owner can tell what is being asked for, so it is a full box.
  final String description;

  final String? productId;

  /// `id` / `name` pairs for the product dropdown.
  final List<(String, String)> products;

  final bool optionsLoading;

  /// The reporter has pressed submit at least once. Field-level messages turn
  /// on from here and stay on until the field is valid, so correcting a field
  /// clears its own message without a second press. Distinct from
  /// [isSubmitting], which is only true during the write itself.
  final bool attemptedSubmit;

  final bool isSubmitting;

  /// The request is filed and the work item exists.
  final bool success;

  final String? createdWorkItemId;
  final String? createdTitle;
  final String? createdState;

  final String? errorMessage;

  /// A product is required: an unowned feature request has nobody to answer
  /// it, which is the whole of what this form is for.
  bool get productMissing => (productId ?? '').isEmpty;

  /// Validation messages, shown under the field that caused them once the
  /// reporter has tried to submit.
  String? get titleError =>
      title.trim().isEmpty && attemptedSubmit ? 'Title is required' : null;

  String? get productError => productMissing && attemptedSubmit
      ? 'Choose the product this is for'
      : null;

  /// What the success panel reads back.
  String get createdRef => createdWorkItemId ?? '';

  CreateFeatureRequestState copyWith({
    String? title,
    String? description,
    String? productId,
    bool clearProduct = false,
    List<(String, String)>? products,
    bool? optionsLoading,
    bool? attemptedSubmit,
    bool? isSubmitting,
    bool? success,
    String? createdWorkItemId,
    String? createdTitle,
    String? createdState,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CreateFeatureRequestState(
      title: title ?? this.title,
      description: description ?? this.description,
      productId: clearProduct ? null : (productId ?? this.productId),
      products: products ?? this.products,
      optionsLoading: optionsLoading ?? this.optionsLoading,
      attemptedSubmit: attemptedSubmit ?? this.attemptedSubmit,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      success: success ?? this.success,
      createdWorkItemId: createdWorkItemId ?? this.createdWorkItemId,
      createdTitle: createdTitle ?? this.createdTitle,
      createdState: createdState ?? this.createdState,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateFeatureRequestState &&
          other.title == title &&
          other.description == description &&
          other.productId == productId &&
          other.optionsLoading == optionsLoading &&
          other.attemptedSubmit == attemptedSubmit &&
          other.isSubmitting == isSubmitting &&
          other.success == success &&
          other.createdWorkItemId == createdWorkItemId &&
          other.createdTitle == createdTitle &&
          other.createdState == createdState &&
          other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(
    title,
    description,
    productId,
    optionsLoading,
    isSubmitting,
    success,
    createdWorkItemId,
    createdTitle,
    createdState,
    errorMessage,
  );
}
