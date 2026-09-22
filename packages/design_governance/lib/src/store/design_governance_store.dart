import 'design_finding_store.dart';
import 'design_revision_event_store.dart';
import 'design_revision_store.dart';
import 'design_review_result_store.dart';

/// Combined interface for all design governance store operations.
/// Implementations should provide all four store capabilities.
abstract interface class DesignGovernanceStore
    implements
        DesignRevisionStore,
        DesignReviewResultStore,
        DesignFindingStore,
        DesignRevisionEventStore {}