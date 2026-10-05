/// Form events for `Request a feature`.
///
/// The form collects three things — a title, a description of the use case, and
/// the product it is for — because that is what a product owner needs in order
/// to decide whether to take it on. Nothing more is asked for, because nothing
/// more is decided here: the request is filed as a draft and waits for a human.
library;

import 'package:flutter/foundation.dart';

@immutable
sealed class CreateFeatureRequestEvent {
  const CreateFeatureRequestEvent();
}

final class CreateFeatureRequestTitleChanged extends CreateFeatureRequestEvent {
  const CreateFeatureRequestTitleChanged(this.title);

  final String title;
}

final class CreateFeatureRequestDescriptionChanged
    extends CreateFeatureRequestEvent {
  const CreateFeatureRequestDescriptionChanged(this.description);

  final String description;
}

final class CreateFeatureRequestProductChanged
    extends CreateFeatureRequestEvent {
  const CreateFeatureRequestProductChanged(this.productId);

  final String productId;
}

/// Loads the product list the form offers.
final class CreateFeatureRequestOptionsRequested
    extends CreateFeatureRequestEvent {
  const CreateFeatureRequestOptionsRequested();
}

final class CreateFeatureRequestSubmitted extends CreateFeatureRequestEvent {
  const CreateFeatureRequestSubmitted();
}
