import 'package:platform_contracts/platform_contracts.dart';

/// Durable store for [ModelExecutionRecord] entries.
abstract interface class ModelExecutionRecordStore {
  Future<void> insert(ModelExecutionRecord record);

  Future<List<ModelExecutionRecord>> getByWorkItem(String workItemId);

  Future<List<ModelExecutionRecord>> getByJob(String jobId);

  Future<void> insertAll(List<ModelExecutionRecord> records);
}