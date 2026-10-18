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
  ) async =>
      _contracts.values.where((c) => c.workItemId == workItemId).toList()
        ..sort(_oldestFirst);

  /// The total order [DesignContractStore.listDesignContractsForWorkItem]
  /// promises: ascending `createdAt`, then ascending `contractId`.
  ///
  /// ## WHY THIS IS NOT A NO-OP
  ///
  /// The interface documents this read as "oldest first", and a Dart `Map`'s
  /// iteration order is INSERTION order — which coincides with oldest-first
  /// only until something writes two contracts for one item out of
  /// chronological order. Two constructions make that happen, and F-146 names
  /// both: a descending-`createdAt` insert sequence reads back newest-first,
  /// and a `LinkedHashMap` overwrite keeps the ORIGINAL position, so a
  /// re-provisioned contract carrying a later `createdAt` keeps its old slot.
  ///
  /// `PostgresDesignContractStore` orders by `"createdAt" ASC` in SQL because
  /// that is what the indexed lookup already sorts on. Sorting here is what
  /// stops the two implementations from answering the same question with two
  /// different orders — the divergence a caller cannot detect and a reviewer
  /// cannot see without reading both files side by side.
  ///
  /// `contractId` breaks ties so the order is TOTAL. `createdAt` is a
  /// caller-asserted instant and two contracts built in the same tick is not
  /// exotic; without a tie-break, two equally-old rows may come back in either
  /// order and the same store would disagree with itself between runs.
  static int _oldestFirst(DesignContract a, DesignContract b) {
    final byAge = a.createdAt.compareTo(b.createdAt);
    return byAge != 0 ? byAge : a.contractId.compareTo(b.contractId);
  }
}
