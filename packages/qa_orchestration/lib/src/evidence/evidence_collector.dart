import 'package:platform_contracts/platform_contracts.dart';

abstract class EvidenceCollector {
  Future<QAEvidence> collect(
    String workItemId,
    String gateId,
    String evidenceType,
    Map<String, dynamic> config,
  );
}
