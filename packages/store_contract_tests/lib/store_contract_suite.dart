/// Cross-implementation store contract suites.
///
/// Each suite is a plain function that registers `test`/`group` blocks against
/// whatever concrete store the caller supplies. Run the same suites against
/// the in-memory/file stores (package unit tests) and against the PostgreSQL
/// stores (control-plane integration tests) so every implementation is proven
/// against one shared behavioural contract.
library;

export 'src/execution_store_suite.dart';
export 'src/job_store_suite.dart';
export 'src/worker_registration_store_suite.dart';
export 'src/worker_store_suite.dart';
export 'src/workflow_store_suite.dart';
export 'src/fixtures.dart';
