import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionStore;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart' show JobStore;
import 'package:serverpod/serverpod.dart';
import 'package:workflow_store/workflow_store.dart'
    show DurableWorkflowEngine, WorkflowStore;
import 'package:worker_runtime/worker_runtime.dart'
    show WorkerRegistrationStore, WorkerStore;
import 'package:worker_protocol/worker_protocol.dart' show WorkerRegistration;

import '../persistence/persistence_database.dart';
import '../persistence/postgres_execution_store.dart';
import '../persistence/postgres_job_store.dart';
import '../persistence/postgres_worker_registration_store.dart';
import '../persistence/postgres_worker_store.dart';
import '../persistence/postgres_workflow_store.dart';
import 'structured_logger.dart';

/// Application services for the control plane.
///
/// Owns the durable Postgres-backed stores that implementations of
/// [WorkflowStore], [JobStore], [WorkerStore], [ExecutionStore] and
/// [WorkerRegistrationStore] are hosted on, and exposes read/query
/// operations plus the single write path a request may legally perform
/// (resolving a human decision through the durable workflow engine).
///
/// This layer deliberately has NO operation that sets [WorkItem.state]
/// directly: state transitions, job lifecycle, worker lifecycle, and agent
/// execution orchestration all belong to the engine/coordinator packages
/// that construct their domain objects here. Endpoints only observe state
/// or unlock work that a human decision blocked.
class ControlPlaneService {
  ControlPlaneService(this.session, {StructuredLogger? logger})
    : logger = logger ?? StructuredLogger(session, 'service');

  final Session session;
  final StructuredLogger logger;

  PersistenceDatabase get _db => PersistenceDatabase(session.db);

  WorkflowStore get workflowStore => PostgresWorkflowStore(_db);
  JobStore get jobStore => PostgresJobStore(_db);
  WorkerStore get workerStore => PostgresWorkerStore(_db);
  ExecutionStore get executionStore => PostgresExecutionStore(_db);
  WorkerRegistrationStore get workerRegistrationStore =>
      PostgresWorkerRegistrationStore(_db);

  /// The durable orchestration engine; the only place workflow state writes.
  DurableWorkflowEngine get workflowEngine =>
      DurableWorkflowEngine(store: workflowStore);

  // ---------------------------------------------------------------------
  // Workflow state (reads)
  // ---------------------------------------------------------------------

  Future<WorkItem> readWorkItem(String workItemId) async {
    final item = await workflowStore.readWorkItem(workItemId);
    logger.debug('work_item.read', {'workItemId': workItemId});
    return item;
  }

  Future<List<WorkItem>> readAllWorkItems() async {
    final items = await workflowStore.readAllWorkItems();
    logger.debug('work_item.list', {'count': items.length});
    return items;
  }

  Future<List<WorkflowTransitionRecord>> readTransitionHistory(
    String workItemId,
  ) async {
    final history = await workflowStore.readTransitionHistory(workItemId);
    logger.debug('workflow.transition_history', {
      'workItemId': workItemId,
      'count': history.length,
    });
    return history;
  }

  Future<List<HumanDecision>> readDecisionsForWorkItem(
    String workItemId,
  ) async {
    final decisions = await workflowStore.readHumanDecisionsForWorkItem(
      workItemId,
    );
    logger.debug('workflow.decisions', {
      'workItemId': workItemId,
      'count': decisions.length,
    });
    return decisions;
  }

  // ---------------------------------------------------------------------
  // Human decision resolution (the only legal request-side write path)
  // ---------------------------------------------------------------------

  /// Resolves a human decision through the durable engine. Guarantees:
  /// - decisions are durable before any gate is entered,
  /// - the resolution is persisted inside the same transaction that moves
  ///   the work item,
  /// - a duplicate resolution is an idempotent replay, never a second
  ///   transition.
  Future<WorkItem> resolveHumanDecision({
    required String decisionId,
    required HumanDecisionChoice choice,
    required String decider,
    required String rationale,
    required DecisionSignature signature,
  }) async {
    final workItem = await workflowEngine.resolveHumanDecision(
      decisionId: decisionId,
      choice: choice,
      decider: decider,
      rationale: rationale,
      signature: signature,
    );
    logger.info('workflow.decision_resolved', {
      'decisionId': decisionId,
      'choice': choice.wire,
      'decider': decider,
      'workItemId': workItem.workItemId,
      'state': workItem.state.name,
      'version': workItem.version,
    });
    return workItem;
  }

  // ---------------------------------------------------------------------
  // Scheduler / job state (reads)
  // ---------------------------------------------------------------------

  Future<List<Job>> listJobs() async {
    final jobs = await jobStore.listJobs();
    logger.debug('scheduler.jobs', {'count': jobs.length});
    return jobs;
  }

  Future<List<Job>> listJobsForWorkItem(String workItemId) async {
    final jobs = await jobStore.listJobsForWorkItem(workItemId);
    logger.debug('scheduler.jobs_for_work_item', {
      'workItemId': workItemId,
      'count': jobs.length,
    });
    return jobs;
  }

  Future<Job?> readJob(String jobId) async {
    final job = await jobStore.readJob(jobId);
    logger.debug('scheduler.job', {'jobId': jobId});
    return job;
  }

  Future<List<SchedulerEventRecord>> readJobEvents(String jobId) async {
    final events = await jobStore.readEvents(jobId);
    logger.debug('scheduler.job_events', {
      'jobId': jobId,
      'count': events.length,
    });
    return events;
  }

  Future<JobClaim?> readClaimForJob(String jobId) async {
    final claim = await jobStore.readClaimForJob(jobId);
    logger.debug('scheduler.job_claim', {'jobId': jobId});
    return claim;
  }

  // ---------------------------------------------------------------------
  // Worker + worker_runtime state (reads)
  // ---------------------------------------------------------------------

  Future<List<WorkerRegistration>> listWorkers() async {
    final workers = await workerRegistrationStore.listWorkers();
    logger.debug('worker.registrations', {'count': workers.length});
    return workers;
  }

  Future<List<WorkerExecution>> listWorkerExecutions() async {
    final executions = await workerStore.listWorkerExecutions();
    logger.debug('worker.executions', {'count': executions.length});
    return executions;
  }

  Future<WorkerExecutionResult?> readWorkerResult(String executionId) async {
    final result = await workerStore.readResult(executionId);
    logger.debug('worker.result', {'workerExecutionId': executionId});
    return result;
  }

  Future<List<WorkerEventRecord>> readWorkerEvents(String executionId) async {
    final events = await workerStore.readEvents(executionId);
    logger.debug('worker.events', {
      'workerExecutionId': executionId,
      'count': events.length,
    });
    return events;
  }

  // ---------------------------------------------------------------------
  // Agent execution state (reads)
  // ---------------------------------------------------------------------

  Future<List<AgentExecution>> listAgentExecutions({String? workItemId}) async {
    final executions = await executionStore.listExecutions(
      workItemId: workItemId,
    );
    logger.debug('execution.list', {
      'workItemId': workItemId,
      'count': executions.length,
    });
    return executions;
  }

  Future<AgentExecution> readAgentExecution(String executionId) async {
    final execution = await executionStore.readExecution(executionId);
    logger.debug('execution.read', {'executionId': executionId});
    return execution;
  }

  Future<AgentResult?> readAgentResult(String executionId) async {
    final result = await executionStore.readResult(executionId);
    logger.debug('execution.result', {'executionId': executionId});
    return result;
  }

  Future<List<AgentEventRecord>> readAgentEvents(String executionId) async {
    final events = await executionStore.readEvents(executionId);
    logger.debug('execution.events', {
      'executionId': executionId,
      'count': events.length,
    });
    return events;
  }

  Future<List<PlatformVerification>> readVerifications(
    String executionId,
  ) async {
    final verifications = await executionStore.readVerifications(executionId);
    logger.debug('execution.verifications', {
      'executionId': executionId,
      'count': verifications.length,
    });
    return verifications;
  }
}
