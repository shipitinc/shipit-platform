import 'create_defect_state.dart';

sealed class CreateDefectEvent {}

class CreateDefectTitleChanged extends CreateDefectEvent {
  CreateDefectTitleChanged(this.title);

  final String title;
}

class CreateDefectDescriptionChanged extends CreateDefectEvent {
  CreateDefectDescriptionChanged(this.description);

  final String description;
}

class CreateDefectExpectedBehaviorChanged extends CreateDefectEvent {
  CreateDefectExpectedBehaviorChanged(this.expectedBehavior);

  final String expectedBehavior;
}

class CreateDefectReproductionStepsChanged extends CreateDefectEvent {
  CreateDefectReproductionStepsChanged(this.reproductionSteps);

  final String reproductionSteps;
}

class CreateDefectSeverityChanged extends CreateDefectEvent {
  CreateDefectSeverityChanged(this.severity);

  final String severity;
}

class CreateDefectIntakeCategoryChanged extends CreateDefectEvent {
  CreateDefectIntakeCategoryChanged(this.intakeCategory);

  final String? intakeCategory;
}

/// The product chosen at report time. Changing it drops any work item that
/// belonged to the previous product, because the two are now inconsistent.
class CreateDefectProductChanged extends CreateDefectEvent {
  CreateDefectProductChanged(this.productId);

  final String? productId;
}

class CreateDefectAffectedWorkItemChanged extends CreateDefectEvent {
  CreateDefectAffectedWorkItemChanged(this.workItemId);

  final String? workItemId;
}

class CreateDefectEvidenceAdded extends CreateDefectEvent {
  CreateDefectEvidenceAdded(this.files);

  final List<CreateDefectEvidenceFile> files;
}

class CreateDefectEvidenceRemoved extends CreateDefectEvent {
  CreateDefectEvidenceRemoved(this.index);

  final int index;
}

/// Loads the product list once, on bloc start.
class CreateDefectOptionsRequested extends CreateDefectEvent {
  CreateDefectOptionsRequested();
}

/// Reloads the affected-work-item list after the product changed.
class CreateDefectWorkItemsRequested extends CreateDefectEvent {
  CreateDefectWorkItemsRequested();
}

class CreateDefectSubmitted extends CreateDefectEvent {
  CreateDefectSubmitted();
}

class CreateDefectClientContextCaptured extends CreateDefectEvent {
  CreateDefectClientContextCaptured(this.clientContextJson);

  final String clientContextJson;
}
