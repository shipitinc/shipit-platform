import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('DesignRevisionStatus wire values', () {
    test('fromWire and wire getters round-trip', () {
      for (final status in DesignRevisionStatus.values) {
        expect(DesignRevisionStatus.fromWire(status.wire), equals(status));
        expect(status.wire, isNotEmpty);
      }
    });

    test('unknown wire value throws FormatException', () {
      expect(
        () => DesignRevisionStatus.fromWire('not_a_status'),
        throwsFormatException,
      );
    });

    test('isTerminal is true for approved and superseded', () {
      expect(DesignRevisionStatus.approved.isTerminal, isTrue);
      expect(DesignRevisionStatus.superseded.isTerminal, isTrue);
      expect(DesignRevisionStatus.draft.isTerminal, isFalse);
      expect(DesignRevisionStatus.inReview.isTerminal, isFalse);
      expect(DesignRevisionStatus.changesRequired.isTerminal, isFalse);
      expect(DesignRevisionStatus.reviewPassed.isTerminal, isFalse);
      expect(DesignRevisionStatus.humanApprovalRequired.isTerminal, isFalse);
    });

    test('canTransitionToApproved only for reviewPassed and humanApprovalRequired', () {
      expect(DesignRevisionStatus.reviewPassed.canTransitionToApproved, isTrue);
      expect(DesignRevisionStatus.humanApprovalRequired.canTransitionToApproved, isTrue);
      expect(DesignRevisionStatus.draft.canTransitionToApproved, isFalse);
      expect(DesignRevisionStatus.inReview.canTransitionToApproved, isFalse);
      expect(DesignRevisionStatus.changesRequired.canTransitionToApproved, isFalse);
      expect(DesignRevisionStatus.approved.canTransitionToApproved, isFalse);
      expect(DesignRevisionStatus.superseded.canTransitionToApproved, isFalse);
    });
  });

  group('DesignRiskTier wire values', () {
    test('fromWire and wire getters round-trip', () {
      for (final tier in DesignRiskTier.values) {
        expect(DesignRiskTier.fromWire(tier.wire), equals(tier));
        expect(tier.wire, isNotEmpty);
      }
    });

    test('unknown wire value throws FormatException', () {
      expect(
        () => DesignRiskTier.fromWire('not_a_tier'),
        throwsFormatException,
      );
    });
  });

  group('DesignReviewVerdict wire values', () {
    test('fromWire and wire getters round-trip', () {
      for (final verdict in DesignReviewVerdict.values) {
        expect(DesignReviewVerdict.fromWire(verdict.wire), equals(verdict));
        expect(verdict.wire, isNotEmpty);
      }
    });

    test('unknown wire value throws FormatException', () {
      expect(
        () => DesignReviewVerdict.fromWire('not_a_verdict'),
        throwsFormatException,
      );
    });

    test('isPassing is true for approved and approvedWithMinorFindings', () {
      expect(DesignReviewVerdict.approved.isPassing, isTrue);
      expect(DesignReviewVerdict.approvedWithMinorFindings.isPassing, isTrue);
      expect(DesignReviewVerdict.changesRequired.isPassing, isFalse);
      expect(DesignReviewVerdict.rejected.isPassing, isFalse);
    });
  });

  group('DesignFindingSeverity wire values', () {
    test('fromWire and wire getters round-trip', () {
      for (final severity in DesignFindingSeverity.values) {
        expect(DesignFindingSeverity.fromWire(severity.wire), equals(severity));
        expect(severity.wire, isNotEmpty);
      }
    });

    test('unknown wire value throws FormatException', () {
      expect(
        () => DesignFindingSeverity.fromWire('not_a_severity'),
        throwsFormatException,
      );
    });

    test('blocksApproval is true for blocker and major', () {
      expect(DesignFindingSeverity.blocker.blocksApproval, isTrue);
      expect(DesignFindingSeverity.major.blocksApproval, isTrue);
      expect(DesignFindingSeverity.minor.blocksApproval, isFalse);
      expect(DesignFindingSeverity.advisory.blocksApproval, isFalse);
    });
  });

  group('DesignFindingCategory wire values', () {
    test('fromWire and wire getters round-trip', () {
      for (final category in DesignFindingCategory.values) {
        expect(DesignFindingCategory.fromWire(category.wire), equals(category));
        expect(category.wire, isNotEmpty);
      }
    });

    test('unknown wire value throws FormatException', () {
      expect(
        () => DesignFindingCategory.fromWire('not_a_category'),
        throwsFormatException,
      );
    });
  });

  group('DesignProviderType wire values', () {
    test('fromWire and wire getters round-trip', () {
      for (final provider in DesignProviderType.values) {
        expect(DesignProviderType.fromWire(provider.wire), equals(provider));
        expect(provider.wire, isNotEmpty);
      }
    });

    test('unknown wire value throws FormatException', () {
      expect(
        () => DesignProviderType.fromWire('not_a_provider'),
        throwsFormatException,
      );
    });
  });

  group('DesignRequirementPriority wire values', () {
    test('fromWire and wire getters round-trip', () {
      for (final priority in DesignRequirementPriority.values) {
        expect(DesignRequirementPriority.fromWire(priority.wire), equals(priority));
        expect(priority.wire, isNotEmpty);
      }
    });

    test('unknown wire value throws FormatException', () {
      expect(
        () => DesignRequirementPriority.fromWire('not_a_priority'),
        throwsFormatException,
      );
    });
  });

  group('DesignConstraintType wire values', () {
    test('fromWire and wire getters round-trip', () {
      for (final type in DesignConstraintType.values) {
        expect(DesignConstraintType.fromWire(type.wire), equals(type));
        expect(type.wire, isNotEmpty);
      }
    });

    test('unknown wire value throws FormatException', () {
      expect(
        () => DesignConstraintType.fromWire('not_a_type'),
        throwsFormatException,
      );
    });
  });

  group('DesignRevision serialization', () {
    test('round-trips all fields including enums', () {
      final revision = DesignRevision(
        revisionId: 'DES-R001',
        workItemId: '123e4567-e89b-12d3-a456-426614174002',
        productId: '123e4567-e89b-12d3-a456-426614174000',
        parentRevisionId: null,
        designSystemRevision: 'dsr-1',
        provider: DesignProviderType.penpot,
        penpotFileId: 'penpot-file-123',
        penpotPageId: 'penpot-page-123',
        boardIdsJson: '["board-1", "board-2"]',
        responsiveTargetsJson: '["mobile", "desktop"]',
        statesRepresentedJson: '["default", "hover"]',
        artifactRefsJson: '["art-1", "art-2"]',
        designerExecutionId: '123e4567-e89b-12d3-a456-426614174010',
        reviewExecutionIdsJson: '["rev-exec-1", "rev-exec-2"]',
        status: DesignRevisionStatus.inReview,
        riskTier: DesignRiskTier.medium,
        reviewScopeJson: {'screens': ['login', 'register']},
        carriedForwardFromRevisionId: null,
        supersededByRevisionId: null,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-02T00:00:00Z'),
        approvedAt: null,
        version: 1,
      );

      final json = revision.toJson();
      final decoded = DesignRevision.fromJson(json);

      expect(decoded.revisionId, equals(revision.revisionId));
      expect(decoded.workItemId, equals(revision.workItemId));
      expect(decoded.provider, equals(DesignProviderType.penpot));
      expect(decoded.penpotFileId, equals('penpot-file-123'));
      expect(decoded.penpotPageId, equals('penpot-page-123'));
      expect(decoded.boardIdsJson, equals('["board-1", "board-2"]'));
      expect(decoded.responsiveTargetsJson, equals('["mobile", "desktop"]'));
      expect(decoded.statesRepresentedJson, equals('["default", "hover"]'));
      expect(decoded.artifactRefsJson, equals('["art-1", "art-2"]'));
      expect(decoded.designerExecutionId, equals(revision.designerExecutionId));
      expect(decoded.reviewExecutionIdsJson, equals('["rev-exec-1", "rev-exec-2"]'));
      expect(decoded.status, equals(DesignRevisionStatus.inReview));
      expect(decoded.riskTier, equals(DesignRiskTier.medium));
      expect(decoded.designSystemRevision, equals('dsr-1'));
      expect(decoded.boardIdsJson, equals('["board-1", "board-2"]'));
      expect(decoded.responsiveTargetsJson, equals('["mobile", "desktop"]'));
      expect(decoded.statesRepresentedJson, equals('["default", "hover"]'));
      expect(decoded.artifactRefsJson, equals('["art-1", "art-2"]'));
      expect(decoded.reviewScopeJson, equals({'screens': ['login', 'register']}));
      expect(decoded.createdAt, equals(revision.createdAt));
      expect(decoded.updatedAt, equals(revision.updatedAt));
      expect(decoded.approvedAt, isNull);
      expect(decoded.supersededByRevisionId, isNull);
      expect(decoded.version, equals(1));

      // Verify wire values in JSON
      expect(json['provider'], equals('penpot'));
      expect(json['status'], equals('in_review'));
      expect(json['riskTier'], equals('medium'));
    });

    test('round-trips approved revision with approvedAt', () {
      final revision = DesignRevision(
        revisionId: 'DES-R002',
        workItemId: '123e4567-e89b-12d3-a456-426614174002',
        productId: '123e4567-e89b-12d3-a456-426614174000',
        parentRevisionId: 'DES-R001',
        designSystemRevision: 'dsr-1',
        provider: DesignProviderType.penpot,
        penpotFileId: 'penpot-file-123',
        penpotPageId: 'penpot-page-123',
        boardIdsJson: '["board-1"]',
        responsiveTargetsJson: '["mobile", "desktop"]',
        statesRepresentedJson: '["default"]',
        artifactRefsJson: '["art-1"]',
        designerExecutionId: '123e4567-e89b-12d3-a456-426614174010',
        reviewExecutionIdsJson: '["rev-exec-1"]',
        status: DesignRevisionStatus.approved,
        riskTier: DesignRiskTier.high,
        reviewScopeJson: {'screens': ['payment']},
        carriedForwardFromRevisionId: null,
        supersededByRevisionId: null,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-03T00:00:00Z'),
        approvedAt: DateTime.parse('2024-01-03T00:00:00Z'),
        version: 2,
      );

      final json = revision.toJson();
      final decoded = DesignRevision.fromJson(json);

      expect(decoded.status, equals(DesignRevisionStatus.approved));
      expect(decoded.approvedAt, equals(DateTime.parse('2024-01-03T00:00:00Z')));
      expect(json['status'], equals('approved'));
      expect(json['riskTier'], equals('high'));
      expect(decoded.parentRevisionId, equals('DES-R001'));
    });

    test('round-trips superseded revision', () {
      final revision = DesignRevision(
        revisionId: 'DES-R001',
        workItemId: '123e4567-e89b-12d3-a456-426614174002',
        productId: '123e4567-e89b-12d3-a456-426614174000',
        parentRevisionId: null,
        designSystemRevision: 'dsr-1',
        provider: DesignProviderType.penpot,
        penpotFileId: 'penpot-file-123',
        penpotPageId: 'penpot-page-123',
        boardIdsJson: '["board-1"]',
        responsiveTargetsJson: '["mobile"]',
        statesRepresentedJson: '["default"]',
        artifactRefsJson: '["art-1"]',
        designerExecutionId: '123e4567-e89b-12d3-a456-426614174010',
        reviewExecutionIdsJson: '["rev-exec-1"]',
        status: DesignRevisionStatus.superseded,
        riskTier: DesignRiskTier.low,
        reviewScopeJson: {'screens': ['old']},
        carriedForwardFromRevisionId: null,
        supersededByRevisionId: 'DES-R002',
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-05T00:00:00Z'),
        approvedAt: DateTime.parse('2024-01-03T00:00:00Z'),
        version: 3,
      );

      final json = revision.toJson();
      final decoded = DesignRevision.fromJson(json);

      expect(decoded.status, equals(DesignRevisionStatus.superseded));
      expect(decoded.supersededByRevisionId, equals('DES-R002'));
      expect(json['status'], equals('superseded'));
    });
  });

  group('DesignReviewResult serialization', () {
    test('round-trips all fields including findings', () {
      final reviewResult = DesignReviewResult(
        reviewExecutionId: '123e4567-e89b-12d3-a456-426614174020',
        revisionId: 'DES-R001',
        verdict: DesignReviewVerdict.approvedWithMinorFindings,
        findings: [
          DesignFinding(
            findingId: '123e4567-e89b-12d3-a456-426614174030',
            revisionId: 'DES-R001',
            reviewExecutionId: '123e4567-e89b-12d3-a456-426614174020',
            category: DesignFindingCategory.accessibility,
            severity: DesignFindingSeverity.minor,
            dimension: 'login-form',
            evidence: 'Color contrast ratio 3.5:1 on submit button',
            requiredCorrection: 'Increase contrast to 4.5:1 minimum',
            affectedSurface: 'LoginScreen.submitButton',
            createdAt: DateTime.parse('2024-01-02T10:00:00Z'),
            resolvedByRevisionId: null,
            version: 1,
          ),
          DesignFinding(
            findingId: '123e4567-e89b-12d3-a456-426614174031',
            revisionId: 'DES-R001',
            reviewExecutionId: '123e4567-e89b-12d3-a456-426614174020',
            category: DesignFindingCategory.interactionCompleteness,
            severity: DesignFindingSeverity.advisory,
            dimension: 'login-flow',
            evidence: 'Missing loading state on submit',
            requiredCorrection: 'Add loading spinner during authentication',
            affectedSurface: 'LoginScreen.submitAction',
            createdAt: DateTime.parse('2024-01-02T10:05:00Z'),
            resolvedByRevisionId: null,
            version: 1,
          ),
        ],
        assessedDimensions: ['accessibility', 'interaction_completeness', 'responsive_coverage'],
        reviewScopeJson: {'screens': ['login']},
        createdAt: DateTime.parse('2024-01-02T11:00:00Z'),
        version: 1,
      );

      final json = reviewResult.toJson();
      final decoded = DesignReviewResult.fromJson(json);

      expect(decoded.reviewExecutionId, equals(reviewResult.reviewExecutionId));
      expect(decoded.revisionId, equals(reviewResult.revisionId));
      expect(decoded.verdict, equals(DesignReviewVerdict.approvedWithMinorFindings));
      expect(decoded.findings.length, equals(2));
      expect(decoded.findings[0].category, equals(DesignFindingCategory.accessibility));
      expect(decoded.findings[0].severity, equals(DesignFindingSeverity.minor));
      expect(decoded.findings[1].category, equals(DesignFindingCategory.interactionCompleteness));
      expect(decoded.findings[1].severity, equals(DesignFindingSeverity.advisory));
      expect(decoded.assessedDimensions, equals(['accessibility', 'interaction_completeness', 'responsive_coverage']));
      expect(decoded.reviewScopeJson, equals({'screens': ['login']}));
      expect(decoded.createdAt, equals(reviewResult.createdAt));
      expect(decoded.version, equals(1));

      // Verify wire values in JSON
      expect(json['verdict'], equals('approved_with_minor_findings'));
      expect(json['findings'][0]['category'], equals('accessibility'));
      expect(json['findings'][0]['severity'], equals('minor'));
      expect(json['findings'][1]['category'], equals('interaction_completeness'));
      expect(json['findings'][1]['severity'], equals('advisory'));
    });

    test('round-trips rejected verdict with blocker finding', () {
      final reviewResult = DesignReviewResult(
        reviewExecutionId: '123e4567-e89b-12d3-a456-426614174021',
        revisionId: 'DES-R001',
        verdict: DesignReviewVerdict.rejected,
        findings: [
          DesignFinding(
            findingId: '123e4567-e89b-12d3-a456-426614174032',
            revisionId: 'DES-R001',
            reviewExecutionId: '123e4567-e89b-12d3-a456-426614174021',
            category: DesignFindingCategory.feasibility,
            severity: DesignFindingSeverity.blocker,
            dimension: 'payment-integration',
            evidence: 'API requires 3D Secure which is not implemented',
            requiredCorrection: 'Add 3D Secure flow before payment submission',
            affectedSurface: 'PaymentScreen',
            createdAt: DateTime.parse('2024-01-02T10:00:00Z'),
            resolvedByRevisionId: null,
            version: 1,
          ),
        ],
        assessedDimensions: ['feasibility'],
        createdAt: DateTime.parse('2024-01-02T11:00:00Z'),
        version: 1,
      );

      final json = reviewResult.toJson();
      final decoded = DesignReviewResult.fromJson(json);

      expect(decoded.verdict, equals(DesignReviewVerdict.rejected));
      expect(decoded.findings.single.severity, equals(DesignFindingSeverity.blocker));
      expect(decoded.findings.single.severity.blocksApproval, isTrue);
      expect(json['verdict'], equals('rejected'));
      expect(json['findings'][0]['severity'], equals('blocker'));
    });
  });

  group('DesignFinding serialization', () {
    test('round-trips all fields including resolvedByRevisionId', () {
      final finding = DesignFinding(
        findingId: '123e4567-e89b-12d3-a456-426614174030',
        revisionId: 'DES-R001',
        reviewExecutionId: '123e4567-e89b-12d3-a456-426614174020',
        category: DesignFindingCategory.feasibility,
        severity: DesignFindingSeverity.blocker,
        dimension: 'payment-integration',
        evidence: 'API requires 3D Secure which is not implemented',
        requiredCorrection: 'Add 3D Secure flow before payment submission',
        affectedSurface: 'PaymentScreen',
        createdAt: DateTime.parse('2024-01-02T10:00:00Z'),
        resolvedByRevisionId: 'DES-R002',
        version: 1,
      );

      final json = finding.toJson();
      final decoded = DesignFinding.fromJson(json);

      expect(decoded.findingId, equals(finding.findingId));
      expect(decoded.revisionId, equals(finding.revisionId));
      expect(decoded.reviewExecutionId, equals(finding.reviewExecutionId));
      expect(decoded.category, equals(DesignFindingCategory.feasibility));
      expect(decoded.severity, equals(DesignFindingSeverity.blocker));
      expect(decoded.dimension, equals('payment-integration'));
      expect(decoded.evidence, equals('API requires 3D Secure which is not implemented'));
      expect(decoded.requiredCorrection, equals('Add 3D Secure flow before payment submission'));
      expect(decoded.affectedSurface, equals('PaymentScreen'));
      expect(decoded.createdAt, equals(finding.createdAt));
      expect(decoded.resolvedByRevisionId, equals('DES-R002'));
      expect(decoded.version, equals(1));

      // Verify wire values in JSON
      expect(json['category'], equals('feasibility'));
      expect(json['severity'], equals('blocker'));
    });

    test('round-trips without resolvedByRevisionId', () {
      final finding = DesignFinding(
        findingId: '123e4567-e89b-12d3-a456-426614174030',
        revisionId: 'DES-R001',
        reviewExecutionId: '123e4567-e89b-12d3-a456-426614174020',
        category: DesignFindingCategory.accessibility,
        severity: DesignFindingSeverity.minor,
        dimension: 'login-form',
        evidence: 'Color contrast ratio 3.5:1 on submit button',
        requiredCorrection: 'Increase contrast to 4.5:1 minimum',
        affectedSurface: 'LoginScreen.submitButton',
        createdAt: DateTime.parse('2024-01-02T10:00:00Z'),
        resolvedByRevisionId: null,
        version: 1,
      );

      final json = finding.toJson();
      final decoded = DesignFinding.fromJson(json);

      expect(decoded.resolvedByRevisionId, isNull);
      expect(json.containsKey('resolvedByRevisionId'), isFalse);
      expect(decoded.version, equals(1));
    });
  });

  group('DesignBrief serialization', () {
    test('round-trips all fields including nested enums', () {
      final brief = DesignBrief(
        briefId: '123e4567-e89b-12d3-a456-426614174040',
        workItemId: '123e4567-e89b-12d3-a456-426614174002',
        productId: '123e4567-e89b-12d3-a456-426614174000',
        title: 'Redesign user onboarding flow',
        context: 'New users drop off at step 3 of onboarding',
        requirements: [
          DesignRequirement(
            requirementId: 'req-1',
            description: 'Reduce onboarding steps from 5 to 3',
            priority: DesignRequirementPriority.must,
            traceabilityRef: 'REQ-001',
          ),
          DesignRequirement(
            requirementId: 'req-2',
            description: 'Add progress indicator',
            priority: DesignRequirementPriority.should,
            traceabilityRef: 'REQ-002',
          ),
          DesignRequirement(
            requirementId: 'req-3',
            description: 'Add skip option',
            priority: DesignRequirementPriority.could,
            traceabilityRef: null,
          ),
        ],
        constraints: [
          DesignConstraint(
            constraintId: 'con-1',
            description: 'Must use existing design system components',
            type: DesignConstraintType.designSystem,
          ),
          DesignConstraint(
            constraintId: 'con-2',
            description: 'WCAG 2.1 AA compliance required',
            type: DesignConstraintType.accessibility,
          ),
          DesignConstraint(
            constraintId: 'con-3',
            description: 'Must work on iOS 15+ and Android 10+',
            type: DesignConstraintType.platform,
          ),
        ],
        acceptanceCriteria: [
          'User completes onboarding in under 2 minutes',
          'Drop-off rate at each step < 10%',
        ],
        referenceArtifacts: [
          ReferenceArtifact(
            artifactType: 'user-research',
            location: 'research/onboarding-study-2024.pdf',
            description: 'User research on current onboarding friction',
          ),
          ReferenceArtifact(
            artifactType: 'competitor-analysis',
            location: 'research/competitor-onboarding-2024.pdf',
            description: 'Competitor onboarding flows analysis',
          ),
        ],
        designSystemTokens: ['color-primary', 'spacing-lg', 'border-radius-md'],
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
        version: 1,
      );

      final json = brief.toJson();
      final decoded = DesignBrief.fromJson(json);

      expect(decoded.briefId, equals(brief.briefId));
      expect(decoded.workItemId, equals(brief.workItemId));
      expect(decoded.productId, equals(brief.productId));
      expect(decoded.title, equals('Redesign user onboarding flow'));
      expect(decoded.context, equals('New users drop off at step 3 of onboarding'));
      expect(decoded.requirements.length, equals(3));
      expect(decoded.requirements[0].priority, equals(DesignRequirementPriority.must));
      expect(decoded.requirements[1].priority, equals(DesignRequirementPriority.should));
      expect(decoded.requirements[2].priority, equals(DesignRequirementPriority.could));
      expect(decoded.constraints.length, equals(3));
      expect(decoded.constraints[0].type, equals(DesignConstraintType.designSystem));
      expect(decoded.constraints[1].type, equals(DesignConstraintType.accessibility));
      expect(decoded.constraints[2].type, equals(DesignConstraintType.platform));
      expect(decoded.acceptanceCriteria.length, equals(2));
      expect(decoded.referenceArtifacts!.length, equals(2));
      expect(decoded.designSystemTokens, equals(['color-primary', 'spacing-lg', 'border-radius-md']));
      expect(decoded.version, equals(1));

      // Verify wire values in JSON
      expect(json['requirements'][0]['priority'], equals('must'));
      expect(json['requirements'][1]['priority'], equals('should'));
      expect(json['requirements'][2]['priority'], equals('could'));
      expect(json['constraints'][0]['type'], equals('design_system'));
      expect(json['constraints'][1]['type'], equals('accessibility'));
      expect(json['constraints'][2]['type'], equals('platform'));
    });
  });

  group('WorkerCapability new design capabilities', () {
    test('includes penpotRead, penpotWrite, visualDesign, designReview', () {
      expect(WorkerCapability.penpotRead.name, equals('penpotRead'));
      expect(WorkerCapability.penpotWrite.name, equals('penpotWrite'));
      expect(WorkerCapability.visualDesign.name, equals('visualDesign'));
      expect(WorkerCapability.designReview.name, equals('designReview'));
    });

    test('new capabilities can be used in requiredCapabilities sets', () {
      final capabilities = {
        WorkerCapability.penpotRead,
        WorkerCapability.penpotWrite,
        WorkerCapability.visualDesign,
        WorkerCapability.designReview,
      };

      expect(capabilities, contains(WorkerCapability.penpotRead));
      expect(capabilities, contains(WorkerCapability.penpotWrite));
      expect(capabilities, contains(WorkerCapability.visualDesign));
      expect(capabilities, contains(WorkerCapability.designReview));
    });
  });
}