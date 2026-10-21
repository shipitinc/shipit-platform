/// An in-memory [QAContractStore] for tests that need a contract without a
/// database.
///
/// ## WHY IT IS HERE
///
/// The QA evaluation reads its contract through this interface, and the
/// interface is deliberately the seam the design chose
/// (`evaluator-spec.md` §1: the evaluation is driven through a store, so the
/// same evaluation can be driven by a test without a workflow).
///
/// The production store is
/// `apps/server/lib/src/persistence/postgres_qa_contract_store.dart` and is
/// covered by its own tests.
///
/// ## WHY IT HOLDS MORE THAN ONE
///
/// A [QAContract] carries no work item id, so a store cannot answer "the
/// contract of THIS work item" by filtering — it answers by contract id. That
/// is enough for one contract, and a test that needs two work items
/// evaluated in the same drain pass needs two contracts. So this store holds
/// a map keyed by contract id, and the single-contract constructor stays for
/// the tests that have one.
library;

import 'package:qa_orchestration/qa_orchestration.dart';

class InMemoryQAContractStore implements QAContractStore {
  InMemoryQAContractStore([QAContract? contract]) {
    if (contract != null) _contracts[contract.contractId] = contract;
  }

  final Map<String, QAContract> _contracts = {};

  /// Replaces everything held with [contract] (or with nothing).
  set contract(QAContract? contract) {
    _contracts.clear();
    if (contract != null) _contracts[contract.contractId] = contract;
  }

  /// Holds [contract] alongside the others.
  void hold(QAContract contract) => _contracts[contract.contractId] = contract;

  @override
  Future<void> saveQAContract(QAContract contract) async {
    _contracts[contract.contractId] = contract;
  }

  @override
  Future<QAContract> provisionQAContract(QAContract contract) async {
    _contracts[contract.contractId] = contract;
    return contract;
  }

  @override
  Future<QAContract?> readQAContract(String contractId) async {
    return _contracts[contractId];
  }

  @override
  Future<bool> hasQAContract(String contractId) async {
    return _contracts.containsKey(contractId);
  }

  /// Every contract held.
  ///
  /// A contract names a category and a set of gates, not a work item, so
  /// there is nothing to filter on. The drain reads contracts by id
  /// (`readQAContract`), which is the lookup that matters.
  @override
  Future<List<QAContract>> listQAContractsForWorkItem(
    String workItemId,
  ) async {
    return _contracts.values.toList();
  }

  @override
  Future<List<QAContract>> listQAContractsByCategory(
    WorkItemCategory category,
  ) async {
    return _contracts.values
        .where((contract) => contract.workItemCategory == category)
        .toList();
  }
}
