import 'design_governance_store.dart';

/// Base interface for design governance stores providing transaction support.
abstract class DesignGovernanceStoreBase {
  /// Runs [body] within a single store transaction. Implementations that back a
  /// transaction-capable database must make every store call inside [body]
  /// atomic and rollback together on error. The default implementation has no
  /// transaction and simply forwards.
  Future<T> inTransaction<T>(
    Future<T> Function(DesignGovernanceStore store) body,
  ) async => body(this as DesignGovernanceStore);
}