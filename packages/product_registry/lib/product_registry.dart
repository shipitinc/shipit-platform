/// Durable Product registry, onboarding, baseline, and clarification storage.
library product_registry;

export 'src/store/product_registry_store.dart';
export 'src/store/in_memory_product_registry_store.dart';
export 'src/store/human_decision_store.dart';
export 'src/store/in_memory_human_decision_store.dart';
export 'src/engine/product_registry_engine.dart';
export 'src/engine/baseline_content_hash.dart';
export 'src/engine/baseline_content_hash_v2.dart';
export 'src/engine/baseline_content_hash_v3.dart';
export 'src/engine/baseline_approval_binding.dart';
export 'src/engine/lifecycle_decision_binding.dart';
export 'src/discovery/discovery_observation.dart';
export 'src/discovery/maturity_classifier.dart';
export 'src/discovery/read_only_repository_reader.dart';
export 'src/discovery/discovery_policy.dart';

export 'src/exceptions.dart';
