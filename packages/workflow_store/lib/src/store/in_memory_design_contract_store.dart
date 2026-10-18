import 'package:platform_contracts/platform_contracts.dart';

import '../design_contract_store.dart';

/// A non-durable [DesignContractStore] for tests and single-instance usage.
///
/// It is deliberately the *same* shape as `PostgresQAContractStore` at the
/// points that matter, so a test that passes here is testing the contract and
/// not this implementation: [provisionDesignContract] saves and then READS BACK,
/// and raises rather than returning the value it was handed when the read
/// cannot find it. An implementation that returned the argument would make every
/// "the id resolves" assertion pass for the wrong reason.
class InMemoryDesignContractStore implements DesignContractStore {
  final Map<String, DesignContract> _contracts = {};

  /// The rows, in insertion order. Exposed so a test can assert that a replay
  /// converged on ONE row rather than two, which is the property
  /// [provisionDesignContract]'s idempotence claim is actually about.
  List<DesignContract> get contracts =>
      List<DesignContract>.unmodifiable(_contracts.values);

  @override
  Future<void> saveDesignContract(DesignContract contract) async {
    _contracts[contract.contractId] = contract;
  }

  @override
  Future<DesignContract> provisionDesignContract(
    DesignContract contract,
  ) async {
    await saveDesignContract(contract);
    final stored = await readDesignContract(contract.contractId);
    if (stored == null) {
      // Reachable only if the write above did not write. Surfaced rather than
      // swallowed, for the reason `DesignContractStore`'s own doc gives: the
      // caller is about to stamp `stored.contractId` onto a work item, and the
      // whole point of this method is that the id provably resolves.
      throw StateError(
        'DesignContract ${contract.contractId} was written but cannot be '
        'read back; refusing to hand out a designContractId that resolves to '
        'nothing',
      );
    }
    return stored;
  }

  @override
  Future<DesignContract?> readDesignContract(String contractId) async =>
      _contracts[contractId];

  @override
  Future<bool> hasDesignContract(String contractId) async =>
      _contracts.containsKey(contractId);

  @override
  Future<List<DesignContract>> listDesignContractsForWorkItem(
    String workItemId,
  ) async => _contracts.values
      .where((c) => c.workItemId == workItemId)
      .toList(growable: false);
}
