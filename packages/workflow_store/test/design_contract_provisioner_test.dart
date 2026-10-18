import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// `DesignContractStore`, `InMemoryDesignContractStore`, `DesignContractBuilder`
/// and `DesignContractProvisioner` — the step 1 foundation the design
/// governance runtime needs so that `designRequired` stops being a state with
/// nothing behind it.
///
/// ## What is and is not under test
///
/// What IS: the declaration the builder makes, the shape of the store interface,
/// the read-back discipline that makes a `designContractId` mean a row, and the
/// idempotence that makes a replay converge.
///
/// What is NOT, and cannot be, tested here: that the row SURVIVES a restart.
/// There is no durable implementation in this package yet — the PostgreSQL one
/// is hosted in `apps/server` beside the other `Postgres*Store`s — so nothing in
/// this file should be read as evidence that a contract is durable. It is
/// evidence that the declaration is correct and that the store contract is one a
/// durable implementation can satisfy. The migration itself is asserted
/// separately, as SQL on disk, in
/// `apps/server/test/design_contract_migration_test.dart`.
///
/// ## Why the refusals are asserted rather than left to inspection
///
/// Every value the builder declines to invent — reviewer identity, artifact
/// schemas, an expiry, an approval count — is a `null` or a bare number in the
/// source, and a `null` is indistinguishable from an oversight unless something
/// fails when it changes. Each test below names the input that makes it fail.
void main() {
  const workItemId = 'design-remediation-fixture-1';
  const productId = 'p-fixture-1';
  final now = DateTime.utc(2026, 10, 18, 12, 0, 0);

  late InMemoryDesignContractStore store;
  late DesignContractProvisioner provisioner;

  setUp(() {
    store = InMemoryDesignContractStore();
    provisioner = DesignContractProvisioner(contractStore: store);
  });

  group('the id is a pure function of the work item id', () {
    test('two calls for one item address one row, so a replay converges', () {
      expect(
        designContractIdForWorkItem(workItemId),
        designContractIdForWorkItem(workItemId),
      );
    });

    test('two items address two rows', () {
      expect(
        designContractIdForWorkItem('item-a'),
        isNot(designContractIdForWorkItem('item-b')),
      );
    });

    test('ids that differ ONLY in case address different rows', () {
      // MEASURED, not assumed. Folding case (or any other normalising map)
      // inside this function left the whole file GREEN, because every
      // fixture id is already lower-case and purity and impurity coincide on
      // them. Case is not hypothetical: work-item ids are minted with an
      // upper-case prefix by more than one lane (`WI-feature-…`,
      // `design-remediation-…`), so two items whose ids differ only in case
      // are constructible — and they would converge on ONE contract, with the
      // second item's `designContractId` silently naming the first item's
      // requirement.
      expect(
        designContractIdForWorkItem('WI-item-A'),
        isNot(designContractIdForWorkItem('wi-item-a')),
      );
    });

    test('it is namespaced away from the QA contract id space, because design '
        'and QA contracts have different approvers', () {
      // The prefixes the QA store mints. A collision here would put a design
      // requirement into the table every gate evaluator reads.
      final id = designContractIdForWorkItem(workItemId);
      for (final qaPrefix in const ['qa-triage-', 'qa-product-']) {
        expect(
          id.startsWith(qaPrefix),
          isFalse,
          reason: '$id must not share the $qaPrefix namespace',
        );
      }
    });

    test('provisioning twice for one item leaves exactly ONE row', () async {
      await provisioner.provisionForWorkItem(
        workItemId: workItemId,
        productId: productId,
        now: now,
      );
      await provisioner.provisionForWorkItem(
        workItemId: workItemId,
        productId: productId,
        now: now,
      );
      expect(store.contracts, hasLength(1));
      expect(
        store.contracts.single.contractId,
        designContractIdForWorkItem(workItemId),
      );
    });

    test('provisioning two items leaves two rows', () async {
      await provisioner.provisionForWorkItem(
        workItemId: 'item-a',
        productId: productId,
        now: now,
      );
      await provisioner.provisionForWorkItem(
        workItemId: 'item-b',
        productId: productId,
        now: now,
      );
      expect(store.contracts, hasLength(2));
    });
  });

  group('the declaration the builder makes', () {
    late DesignContract draft;

    setUp(() {
      draft = const DesignContractBuilder().buildDraftContract(
        workItemId: workItemId,
        productId: productId,
        defectId: 'defect-fixture-1',
        triageResultId: 'triage-result-fixture-1',
        now: now,
      );
    });

    test(
      'it is DRAFT, which is what the design calls a remediation contract',
      () {
        expect(draft.status, DesignContractStatus.draft);
      },
    );

    test('it is addressed at the work item it governs', () {
      expect(draft.workItemId, workItemId);
      expect(draft.contractId, designContractIdForWorkItem(workItemId));
    });

    test('it requires the design_revision record, and requires it', () {
      expect(draft.requiredArtifacts, hasLength(1));
      final artifact = draft.requiredArtifacts.single;
      expect(artifact.artifactType, designRevisionArtifactType);
      expect(artifact.required, isTrue);
      expect(
        artifact.description,
        isNotEmpty,
        reason:
            'a required artifact with no description tells a designer nothing '
            'about what is being asked of them',
      );
    });

    test('it declares NO artifact schema, and says so by name rather than by a '
        'bare null', () {
      // The fidelity anchor — the committed schema that would make a column
      // of `design_revision` machine-checkable — does not exist. A
      // `validationSchema` here would be a gate no validator runs.
      expect(draft.requiredArtifacts.single.validationSchema, isNull);
      expect(
        draft.metadata?[requiredArtifactSchemasMetadataKey],
        requiredArtifactSchemasAbsent,
        reason:
            'a null validationSchema reads equally as "no schema exists" and '
            'as "nothing needs checking". The named value is what stops an '
            'absent gate from being read as a passed one.',
      );
    });

    test(
      'it names the reviewer ROLE, and no identity that does not exist yet',
      () {
        expect(draft.reviewers, [AgentRole.designReviewer.wire]);
        final roleWires = AgentRole.values.map((r) => r.wire).toSet();
        for (final reviewer in draft.reviewers) {
          expect(
            roleWires,
            contains(reviewer),
            reason:
                '"$reviewer" is not an AgentRole wire value. Reviewer identity '
                'is not knowable when a work item is created, and inventing one '
                'puts a fabricated actor on a durable governance record.',
          );
        }
      },
    );

    test(
      'it requires exactly one independent approval, and does not encode the '
      'risk-tier gate',
      () {
        expect(draft.approvalThreshold, designContractApprovalThreshold);
        expect(draft.approvalThreshold, greaterThan(0));
        expect(
          draft.approvalThreshold,
          lessThan(2),
          reason:
              'the threshold governs ARTIFACT approval. The designApproval '
              'human gate is a separate authority over the resolved risk tier, '
              'and the tier cannot be resolved while DesignRiskPolicy does not '
              'exist. Encoding a second approval here would record a decision '
              'nobody took.',
        );
      },
    );

    test(
      'it records NOTHING submitted and NOTHING decided — as null, not as []',
      () {
        // `[]` asserts a fact ("nothing was submitted"); `null` says the
        // question has not come up yet, which is what a draft contract knows.
        expect(draft.submittedArtifacts, isNull);
        expect(draft.decisions, isNull);
      },
    );

    test('it sets no expiry, because no expiry rule exists to encode', () {
      expect(draft.expiresAt, isNull);
    });

    test('it records both timestamps from the caller-supplied instant', () {
      expect(draft.createdAt, now);
      expect(draft.updatedAt, now);
    });

    test('it records the provenance of a design-remediation contract', () {
      expect(draft.metadata?['productId'], productId);
      expect(
        draft.metadata?[designContractDefectIdMetadataKey],
        'defect-fixture-1',
      );
      expect(
        draft.metadata?[designContractTriageResultIdMetadataKey],
        'triage-result-fixture-1',
      );
    });

    test(
      'a contract with no design defect behind it records null provenance, not '
      'an invented one',
      () {
        final nonRemediation = const DesignContractBuilder().buildDraftContract(
          workItemId: workItemId,
          productId: productId,
          now: now,
        );
        expect(
          nonRemediation.metadata?[designContractDefectIdMetadataKey],
          isNull,
        );
        expect(
          nonRemediation.metadata?[designContractTriageResultIdMetadataKey],
          isNull,
        );
      },
    );

    test(
      'the same instant builds byte-identical JSON, so a replay is not a churn',
      () {
        final again = const DesignContractBuilder().buildDraftContract(
          workItemId: workItemId,
          productId: productId,
          defectId: 'defect-fixture-1',
          triageResultId: 'triage-result-fixture-1',
          now: now,
        );
        expect(again.toJson().toString(), draft.toJson().toString());
      },
    );

    test(
      'it survives the JSON codec the store uses, with every typed field intact',
      () {
        // The store's JSON columns carry `List<RequiredArtifact>`,
        // `List<SubmittedArtifact>`, `List<String>` and `Map<String, dynamic>`,
        // and each of those has its own generated `fromJson`. A field that does
        // not survive this round trip is a field the columns cannot hold.
        expect(DesignContract.fromJson(draft.toJson()), draft);
      },
    );

    test(
      'a contract carrying submissions and decisions survives the same codec',
      () {
        // The DRAFT is the only shape the builder produces, so the store's
        // decode path for the nullable columns would otherwise never be
        // exercised — and an unexercised decode is exactly how a column becomes
        // unreadable without anything failing.
        final submitted = DesignContract(
          contractId: draft.contractId,
          workItemId: draft.workItemId,
          requiredArtifacts: draft.requiredArtifacts,
          reviewers: draft.reviewers,
          approvalThreshold: draft.approvalThreshold,
          status: DesignContractStatus.underReview,
          submittedArtifacts: [
            SubmittedArtifact(
              artifactType: designRevisionArtifactType,
              contentHash: 'sha256:fixture',
              submittedBy: 'execution-fixture-1',
              submittedAt: now,
            ),
          ],
          decisions: const ['approved-by-independent-reviewer'],
          createdAt: now,
          updatedAt: now,
          metadata: draft.metadata,
        );
        expect(DesignContract.fromJson(submitted.toJson()), submitted);
        expect(
          DesignContract.fromJson(submitted.toJson()).status,
          DesignContractStatus.underReview,
          reason:
              '`underReview` is the one status whose wire form differs from its '
              'Dart name. The store writes the column through this codec, so a '
              'column that stored `underReview` would decode as an unknown '
              'status.',
        );
      },
    );
  });

  group('the store contract', () {
    test(
      'an unwritten id reads back null — the honest answer, not an error',
      () async {
        expect(
          await store.readDesignContract('design-contract-never-written'),
          isNull,
        );
        expect(
          await store.hasDesignContract('design-contract-never-written'),
          isFalse,
        );
      },
    );

    test('it reports the contracts of one item and not another', () async {
      await provisioner.provisionForWorkItem(
        workItemId: 'item-a',
        productId: productId,
        now: now,
      );
      await provisioner.provisionForWorkItem(
        workItemId: 'item-b',
        productId: productId,
        now: now,
      );
      final forA = await store.listDesignContractsForWorkItem('item-a');
      expect(forA, hasLength(1));
      expect(forA.single.workItemId, 'item-a');
      expect(
        await store.listDesignContractsForWorkItem('item-c'),
        isEmpty,
        reason:
            'an item with no contract must read as none, not as someone '
            "else's",
      );
    });

    test(
      'provisioning hands back the row the store HOLDS, not the argument',
      () async {
        // This is the load-bearing property of `provisionDesignContract`. A
        // store that returned the value it was handed would make every
        // "the id resolves" assertion downstream pass for the wrong reason,
        // which is the fabrication this whole layer exists to remove.
        final store = _RewritingDesignContractStore();
        final provisioner = DesignContractProvisioner(contractStore: store);
        final provisioned = await provisioner.provisionForWorkItem(
          workItemId: workItemId,
          productId: productId,
          now: now,
        );
        expect(
          provisioned.approvalThreshold,
          _RewritingDesignContractStore.thresholdOnRead,
          reason:
              'the read-back value is what gets stamped on a work item; '
              'returning the argument would stamp a value the store never held',
        );
      },
    );

    test('the in-memory store honours the read-back obligation ITSELF, rather '
        'than only the ones the fakes honour', () {
      // MEASURED, not assumed. Reverting `InMemoryDesignContractStore` to
      // return the value it was handed instead of the row it read back left
      // this whole file GREEN — the two fakes prove the PROVISIONER uses the
      // read-back value and that a store which cannot read back raises, but
      // neither proves the shipped in-memory implementation honours the same
      // obligation. A store that quietly returns its argument is a store
      // whose "the id resolves" claim is untested, which is the whole
      // property the interface exists for.
      //
      // The observable consequence of skipping the read-back is the missing
      // row, so that is what is provoked: a subclass whose save does not land.
      // With the read-back in place this raises; without it, the provision
      // would return a contract that resolves to nothing.
      final noOpSave = _NoOpSaveDesignContractStore();
      expect(
        () => noOpSave.provisionDesignContract(
          const DesignContractBuilder().buildDraftContract(
            workItemId: workItemId,
            productId: productId,
            now: DateTime.utc(2026, 10, 18),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('cannot be read back'),
          ),
        ),
      );
    });

    test('a store that cannot read back what it wrote raises rather than '
        'returning a contract that resolves to nothing', () async {
      // Unreachable through the in-memory implementation, which is exactly why
      // it needs its own store: the guard has to be held by the CONTRACT, not
      // by the one implementation that happens to satisfy it.
      final provisioner = DesignContractProvisioner(
        contractStore: _VanishingDesignContractStore(),
      );
      await expectLater(
        provisioner.provisionForWorkItem(
          workItemId: workItemId,
          productId: productId,
          now: now,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('cannot be read back'),
          ),
        ),
      );
    });
  });

  group('the provisioner refuses a contract it did not address', () {
    Future<void> expectRefusal(
      DesignContractStore badStore,
      Matcher messageMatcher,
    ) async {
      await expectLater(
        DesignContractProvisioner(contractStore: badStore).provisionForWorkItem(
          workItemId: workItemId,
          productId: productId,
          now: now,
        ),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', messageMatcher),
        ),
      );
    }

    test('when the store returns a DIFFERENT contract id', () async {
      // Failing input: a store that resolves ids by some other rule. The value
      // returned from here is what gets stamped on the work item, so stamping
      // the wrong one silently is the failure this refuses.
      await expectRefusal(
        _MisreportingDesignContractStore(misreport: _Misreport.contractId),
        contains(designContractIdForWorkItem(workItemId)),
      );
    });

    test(
      'when the store returns a contract for a DIFFERENT work item',
      () async {
        // Failing input: a store whose lookup ignores `workItemId`. The contract
        // would then govern an item nobody asked about.
        await expectRefusal(
          _MisreportingDesignContractStore(misreport: _Misreport.workItemId),
          contains(workItemId),
        );
      },
    );

    test('when the row is not there to be read after the write', () async {
      // Failing input: a write that reported success, a read-back that succeeded,
      // and then an existence probe that says the row is gone — a row deleted
      // between the two, or a replica that has not caught up. The value about
      // to be stamped on the work item would then name a contract that exists
      // nowhere.
      await expectRefusal(
        _MisreportingDesignContractStore(
          misreport: _Misreport.vanishesAfterRead,
        ),
        contains('not readable after being written'),
      );
    });
  });
}

/// What a deliberately non-conforming store misreports.
enum _Misreport { contractId, workItemId, vanishesAfterRead }

/// Answers the provisioner's checks dishonestly, one way at a time.
///
/// Each mode is a store that a real implementation could plausibly become — one
/// that mints ids itself, one that reads the wrong index, one whose row
/// disappears between the read-back and the existence probe — so the
/// provisioner's refusals are held against plausible inputs rather than against a
/// mock nobody would write.
class _MisreportingDesignContractStore implements DesignContractStore {
  _MisreportingDesignContractStore({required this.misreport});

  final _Misreport misreport;

  DesignContract? _written;

  @override
  Future<void> saveDesignContract(DesignContract contract) async {
    _written = contract;
  }

  @override
  Future<DesignContract> provisionDesignContract(
    DesignContract contract,
  ) async {
    await saveDesignContract(contract);
    final stored = await readDesignContract(contract.contractId);
    if (stored == null) {
      throw StateError(
        'DesignContract ${contract.contractId} was written but cannot be read '
        'back',
      );
    }
    return stored;
  }

  @override
  Future<DesignContract?> readDesignContract(String contractId) async {
    final contract = _written;
    if (contract == null) return null;
    return switch (misreport) {
      _Misreport.contractId => DesignContract(
        contractId: 'design-contract-some-other-item',
        workItemId: contract.workItemId,
        requiredArtifacts: contract.requiredArtifacts,
        reviewers: contract.reviewers,
        approvalThreshold: contract.approvalThreshold,
        status: contract.status,
        createdAt: contract.createdAt,
        updatedAt: contract.updatedAt,
      ),
      _Misreport.workItemId => DesignContract(
        contractId: contract.contractId,
        workItemId: 'design-remediation-some-other-item',
        requiredArtifacts: contract.requiredArtifacts,
        reviewers: contract.reviewers,
        approvalThreshold: contract.approvalThreshold,
        status: contract.status,
        createdAt: contract.createdAt,
        updatedAt: contract.updatedAt,
      ),
      _Misreport.vanishesAfterRead => contract,
    };
  }

  @override
  Future<bool> hasDesignContract(String contractId) async =>
      misreport != _Misreport.vanishesAfterRead;

  @override
  Future<List<DesignContract>> listDesignContractsForWorkItem(
    String workItemId,
  ) async => const [];
}

/// Holds a different threshold than it was written with, to prove the
/// provisioner uses the read-back row rather than the argument.
class _RewritingDesignContractStore implements DesignContractStore {
  static const int thresholdOnRead = 7;

  DesignContract? _written;

  @override
  Future<void> saveDesignContract(DesignContract contract) async {
    _written = contract;
  }

  @override
  Future<DesignContract> provisionDesignContract(
    DesignContract contract,
  ) async {
    await saveDesignContract(contract);
    final stored = await readDesignContract(contract.contractId);
    if (stored == null) {
      throw StateError(
        'DesignContract ${contract.contractId} was written but cannot be read '
        'back',
      );
    }
    return stored;
  }

  @override
  Future<DesignContract?> readDesignContract(String contractId) async {
    final contract = _written;
    if (contract == null) return null;
    return DesignContract(
      contractId: contract.contractId,
      workItemId: contract.workItemId,
      requiredArtifacts: contract.requiredArtifacts,
      reviewers: contract.reviewers,
      approvalThreshold: thresholdOnRead,
      status: contract.status,
      createdAt: contract.createdAt,
      updatedAt: contract.updatedAt,
    );
  }

  @override
  Future<bool> hasDesignContract(String contractId) async => _written != null;

  @override
  Future<List<DesignContract>> listDesignContractsForWorkItem(
    String workItemId,
  ) async => const [];
}

/// Accepts the write and then reports the row gone.
class _VanishingDesignContractStore implements DesignContractStore {
  @override
  Future<void> saveDesignContract(DesignContract contract) async {}

  @override
  Future<DesignContract> provisionDesignContract(
    DesignContract contract,
  ) async {
    await saveDesignContract(contract);
    final stored = await readDesignContract(contract.contractId);
    if (stored == null) {
      throw StateError(
        'DesignContract ${contract.contractId} was written but cannot be read '
        'back; refusing to hand out a designContractId that resolves to '
        'nothing',
      );
    }
    return stored;
  }

  @override
  Future<DesignContract?> readDesignContract(String contractId) async => null;

  @override
  Future<bool> hasDesignContract(String contractId) async => false;

  @override
  Future<List<DesignContract>> listDesignContractsForWorkItem(
    String workItemId,
  ) async => const [];
}

/// Accepts a provision without storing anything.
///
/// The only way to observe the read-back obligation from outside a store is to
/// make the row absent, because a store that DOES read back returns a value
/// identical to the one it was handed. Overriding the single write method is
/// what makes the row absent without reaching into the implementation.
class _NoOpSaveDesignContractStore extends InMemoryDesignContractStore {
  @override
  Future<void> saveDesignContract(DesignContract contract) async {}
}
