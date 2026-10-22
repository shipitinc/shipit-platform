import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_store/workflow_store.dart';

/// Re-saves the design contract row [contractId] names with
/// [DesignContractStatus.underReview].
///
/// `designContractUnderReview()` reads the status from the design contract
/// STORE, together with the work item's confirmed `designContractId` column. A
/// fixture that walks `designRequired -> designInReview` therefore has to put
/// the row in that state; passing `{'designContractStatus': …}` in the
/// transition context is exactly the caller-supplied value the guard no longer
/// reads, and a fixture still passing one would keep working while asserting
/// nothing about the store.
///
/// [DesignContract] has no `copyWith`, so the row is round-tripped through its
/// own JSON and the one field under test is changed. That also exercises the
/// wire form (`under_review`) the Postgres store persists.
Future<void> markDesignContractUnderReview(
  DesignContractStore store,
  String contractId,
) async {
  final row = await store.readDesignContract(contractId);
  if (row == null) {
    throw StateError(
      'no design contract $contractId to move under review: the fixture has '
      'nothing to walk to designInReview with',
    );
  }
  await store.saveDesignContract(
    DesignContract.fromJson({...row.toJson(), 'status': 'under_review'}),
  );
}
