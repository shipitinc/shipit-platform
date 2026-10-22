import 'package:design_governance/design_governance.dart'
    show DesignRevisionNotFoundException, DesignRevisionStore;
import 'package:platform_contracts/platform_contracts.dart'
    show DesignProviderType, DesignRevision, Job, WorkItem;
import 'package:scheduler/scheduler.dart'
    show SchedulerWorkload, WorkloadResolver;

import 'design_revision_producer.dart' show designRevisionIdMetadataKey;

/// Resolves the workspace a design REVIEW job runs in, and refuses to resolve
/// one when there is no revision/artifact context to review.
///
/// ## WHY THIS IS FAIL-CLOSED, AND WHY NULL IS THE ONLY REFUSAL
///
/// `Scheduler` treats a null [WorkloadResolver] result as "no artifact could be
/// resolved": it does not dispatch, it records the job in
/// `SchedulerTickResult.blockedArtifactMissing`, and the composition root can
/// surface it. Returning a construction-time default instead would send a
/// reviewer to inspect nothing — the exact blind dispatch this lane must not
/// perform (design §2.4, step 8).
///
/// The design review lane is the only lane whose subject is not a produced
/// commit. Its subject is a durable [DesignRevision] plus the Penpot document
/// that revision names. So the resolver reads the revision id the producer
/// stamped onto the work item, reads the revision back, and requires:
///  - the revision belongs to THIS work item;
///  - it is a Penpot revision;
///  - it names both a Penpot file and page.
///
/// Anything less is `null`, logged by name, and never dispatched.
///
/// ## INDEPENDENCE
///
/// This resolver does not select the reviewer's execution and does not know the
/// designer's execution id. Independence is enforced by
/// `designReviewRequest`, which reads `designerExecutionId` from the same work
/// item metadata the producer stamps atomically with `designRevisionId`. Keeping
/// that rule in one place is why this function returns a workspace only.
///
/// ## KNOWN BOUNDARY (reported, not hidden)
///
/// `designReviewInstruction` is synchronous and carries no Penpot coordinates,
/// and [SchedulerWorkload] has nowhere to put them. This resolver therefore
/// proves the artifact EXISTS and is addressable; conveying its file/page/board
/// ids to the agent is the instruction/request contract's gap, not this
/// resolver's to invent. The ids are logged on resolution so an operator can
/// see what was resolved.
WorkloadResolver designReviewWorkloadResolver({
  required DesignRevisionStore designRevisionStore,
  required String repositoryPath,
  required String startingRevision,
  required String runtimeTypeId,
  required int timeoutSeconds,
  void Function(String event, Map<String, dynamic> data)? logger,
}) {
  return (Job job, WorkItem item) async {
    final revisionId = item.metadata?[designRevisionIdMetadataKey];
    if (revisionId is! String || revisionId.isEmpty) {
      logger?.call('design.review.workload.unresolved', {
        'jobId': job.jobId,
        'workItemId': item.workItemId,
        'reason': 'work item carries no $designRevisionIdMetadataKey',
      });
      return null;
    }

    final DesignRevision revision;
    try {
      revision = await designRevisionStore.readDesignRevision(revisionId);
    } on DesignRevisionNotFoundException catch (e) {
      logger?.call('design.review.workload.unresolved', {
        'jobId': job.jobId,
        'workItemId': item.workItemId,
        'revisionId': revisionId,
        'reason': 'design revision is not readable',
        'error': '$e',
      });
      return null;
    }

    if (revision.workItemId != item.workItemId) {
      logger?.call('design.review.workload.unresolved', {
        'jobId': job.jobId,
        'workItemId': item.workItemId,
        'revisionId': revisionId,
        'revisionWorkItemId': revision.workItemId,
        'reason': 'design revision belongs to a different work item',
      });
      return null;
    }

    final fileId = revision.penpotFileId;
    final pageId = revision.penpotPageId;
    if (revision.provider != DesignProviderType.penpot ||
        fileId == null ||
        fileId.isEmpty ||
        pageId == null ||
        pageId.isEmpty) {
      logger?.call('design.review.workload.unresolved', {
        'jobId': job.jobId,
        'workItemId': item.workItemId,
        'revisionId': revisionId,
        'provider': revision.provider.wire,
        'hasPenpotFileId': fileId != null && fileId.isNotEmpty,
        'hasPenpotPageId': pageId != null && pageId.isNotEmpty,
        'reason': 'design revision has no addressable Penpot artifact',
      });
      return null;
    }

    logger?.call('design.review.workload.resolved', {
      'jobId': job.jobId,
      'workItemId': item.workItemId,
      'revisionId': revisionId,
      'penpotFileId': fileId,
      'penpotPageId': pageId,
      'artifactRefs': revision.artifactRefsJson,
    });
    return SchedulerWorkload(
      repositoryPath: repositoryPath,
      startingRevision: startingRevision,
      timeoutSeconds: timeoutSeconds,
      runtimeTypeId: runtimeTypeId,
    );
  };
}
