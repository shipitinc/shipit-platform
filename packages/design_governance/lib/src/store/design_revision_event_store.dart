import 'package:platform_contracts/platform_contracts.dart';

import 'design_governance_store_base.dart';

/// Store interface for [DesignRevisionEvent] append-only event log.
abstract interface class DesignRevisionEventStore extends DesignGovernanceStoreBase {
  /// Appends a design revision event. Events are immutable and append-only.
  Future<void> appendEvent(DesignRevisionEvent event);

  /// Reads all events for a design revision, ordered by sequence.
  Future<List<DesignRevisionEvent>> readEventsForRevision(String designRevisionId);

  /// Reads events for a design revision from a specific sequence (exclusive).
  Future<List<DesignRevisionEvent>> readEventsAfterSequence(
    String designRevisionId,
    int sequence,
  );

  /// Reads the last event for a design revision (highest sequence).
  Future<DesignRevisionEvent?> readLastEventForRevision(String designRevisionId);
}