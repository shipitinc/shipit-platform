import 'package:control_plane/core/theme.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/data/operator_attestation.dart';
import 'package:control_plane/features/products/add_product_page.dart';
import 'package:control_plane/shared/form_primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/unimplemented_repository_apis.dart';

/// The label the generate control carries, and the promise the Register button's
/// own subtext already makes: "Generate a deploy key first".
///
/// Spelled once and asserted against, so the test cannot drift from the copy by
/// accident: if the control is renamed, this fails rather than silently finding
/// nothing.
const kGenerateLabel = 'Generate a deploy key';

/// Desktop board width. Above `ShipItMetrics.mobileBreakpoint` (840) so
/// `_AddProductView` takes the two-column path.
const Size kDesktopSize = Size(1280, 1400);

/// The mobile board's own viewport, as `mobile_render_test.dart` uses.
const Size kMobileSize = Size(390, 844);

const kProductName = 'ShipIt Platform';
const kRepositoryUri = 'git@github.com:shipit/shipit-platform.git';

/// A host-key fingerprint in the shape the server's validator accepts, and the
/// operator who confirmed it. Supplied through [OperatorAttestation] — the same
/// channel production uses — so the verification below is genuinely reached
/// rather than stubbed into the client.
const _attestation = OperatorAttestation(
  hostKeyFingerprint: 'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU',
  confirmedBy: 'Dana Okafor',
);

/// The one credential id this fake mints, so Register's read-back can match on
/// the row the mint produced rather than a second one.
const _credentialId = 'cred-shipit-platform-1700000000000';

/// The server-minted authorized-keys line, verbatim.
const _mintedPublicKey =
    'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleMintedBlobShipItPlatform '
    'shipit+shipit-platform';

/// A repository that models the two server facts that shape the client, and
/// nothing else.
///
///   * `generate` resolves the repository reference first and refuses anything
///     else, so the product and its reference must exist before a mint. This is
///     why the fake refuses a mint without them, and it is what makes "the
///     client's `_ensureProductAndRepository` runs first" observable here rather
///     than assumed.
///   * `recordGeneratedCredential` is insert-only and refuses a second active
///     credential, so a second mint throws — which is what makes "re-checking
///     does not re-mint" observable.
///
/// Deliberately its own fake rather than a shared one: this test drives the
/// WIDGET tree, and it needs to render cold and count taps, where the bloc test
/// needs a call log. Sharing one would have meant editing reviewed test code
/// for no gain.
class FakeRepositoryProbe
    with UnimplementedRepositoryApis
    implements ControlPlaneRepository {
  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final Map<String, String> products = {};
  final Map<String, String> repositoryUris = {};
  final Map<String, List<CredentialResponse>> credentials = {};
  final List<String> calls = [];

  @override
  Future<ProductDetailResponse> createProduct({
    required String productId,
    required String name,
    String? description,
    required String manifestJson,
    String? manifestVersion,
  }) async {
    calls.add('createProduct');
    products[productId] = name;
    return _detail(productId, name);
  }

  @override
  Future<void> addRepositoryReference({
    required String productId,
    required String repositoryId,
    required String uri,
    required String kind,
    required String provider,
  }) async {
    calls.add('addRepositoryReference');
    if (!products.containsKey(productId)) {
      throw StateError('repository $repositoryId does not exist');
    }
    repositoryUris[repositoryId] = uri;
  }

  @override
  Future<MintedDeployKey> generateDeployKey({
    required String productId,
    required String repositoryId,
  }) async {
    calls.add('generateDeployKey');
    if (!products.containsKey(productId)) {
      throw StateError('product $productId does not exist');
    }
    if (!repositoryUris.containsKey(repositoryId)) {
      throw StateError(
        'repository $repositoryId does not exist for product $productId',
      );
    }
    if ((credentials[productId] ?? const []).isNotEmpty) {
      throw StateError(
        'repository $repositoryId already has an active credential; rotate it '
        'instead of issuing a second one',
      );
    }
    credentials[productId] = [
      CredentialResponse(
        credentialId: _credentialId,
        repositoryId: repositoryId,
        referenceName: 'GIT_REPOSITORY_${repositoryId}_SSH',
        fingerprint: 'SHA256:0mJ0FakeFingerprintOfThePublicBlob',
        algorithm: 'ed25519',
        status: 'generated',
        hostKeyStatus: 'unknown',
        host: repositoryUris[repositoryId],
        canReachRepository: false,
      ),
    ];
    return const MintedDeployKey(
      credentialId: _credentialId,
      publicKey: _mintedPublicKey,
      fingerprint: 'SHA256:0mJ0FakeFingerprintOfThePublicBlob',
      algorithm: 'ed25519',
      status: 'generated',
      hostKeyStatus: 'unknown',
    );
  }

  @override
  Future<DeployKeyAccessVerification> verifyDeployKeyAccess({
    required String productId,
    required String repositoryId,
    required String hostKeyFingerprint,
    required String confirmedBy,
    String? checkedBy,
  }) async {
    calls.add('verifyDeployKeyAccess');
    final rows = credentials[productId] ?? const <CredentialResponse>[];
    if (rows.isEmpty) {
      throw StateError(
        'repository $repositoryId has no active credential to verify',
      );
    }
    credentials[productId] = [
      CredentialResponse(
        credentialId: rows.first.credentialId,
        repositoryId: repositoryId,
        referenceName: rows.first.referenceName,
        fingerprint: rows.first.fingerprint,
        algorithm: rows.first.algorithm,
        status: 'verified',
        hostKeyStatus: 'confirmed',
        host: rows.first.host,
        canReachRepository: true,
      ),
    ];
    return DeployKeyAccessVerification(
      credentialId: rows.first.credentialId,
      status: 'verified',
      canReachRepository: true,
      secretMaterialRemoved: true,
      hostKeyConfirmationProvenance:
          'operator-asserted: the fingerprint was supplied by the caller',
      failureReason: null,
    );
  }

  @override
  Future<ProductDetailResponse> getProductDetail(String productId) async {
    calls.add('getProductDetail');
    return _detail(productId, products[productId] ?? productId);
  }

  ProductDetailResponse _detail(String productId, String name) =>
      ProductDetailResponse(
        productId: productId,
        name: name,
        state: 'registered',
        allowsDispatch: false,
        updatedAt: DateTime.utc(2026, 1, 1),
        repositories: repositoryUris.entries
            .map(
              (e) => ProductRepositoryResponse(
                repositoryId: e.key,
                uri: e.value,
                kind: 'monorepo',
                provider: 'github',
              ),
            )
            .toList(),
        credentials: credentials[productId] ?? const <CredentialResponse>[],
        activeBaselineFactCount: 0,
        pendingBaselineVerified: false,
        openClarifications: const [],
        policies: const [],
      );

  // Everything the Add Product flow does not touch. Present only to satisfy
  // `implements ControlPlaneRepository`; each throws so that a test which
  // accidentally reaches one fails loudly rather than receiving a plausible
  // empty answer.
  @override
  Future<OverviewResponse> getOverview() async => throw UnimplementedError();

  @override
  Future<List<ProductSummaryResponse>> listProductSummaries() async =>
      throw UnimplementedError();

  @override
  Future<List<WorkItemResponse>> listWorkItems({
    String? state,
    String? productId,
    int? limit,
  }) async => throw UnimplementedError();

  @override
  Future<List<DecisionResponse>> pendingDecisions({int? limit}) async =>
      throw UnimplementedError();

  @override
  Future<WorkItemDetailResponse> inspectWorkItem(String workItemId) async =>
      throw UnimplementedError();

  @override
  Future<DecisionDetailResponse> inspectDecision(String workItemId) async =>
      throw UnimplementedError();

  @override
  Future<List<JobSummaryResponse>> jobsForWorkItem(String workItemId) async =>
      throw UnimplementedError();

  @override
  Future<List<DecisionResponse>> recentDecisions({
    String? productId,
    int? limit,
    int? offset,
  }) async => throw UnimplementedError();

  @override
  Future<DecisionResponse> requestLifecycleDecision({
    required String productId,
    required String action,
    bool drainInFlight = true,
  }) async => throw UnimplementedError();

  @override
  Future<DecisionResponse> resolveLifecycleDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    bool noWorkInFlight = false,
  }) async => throw UnimplementedError();

  @override
  Future<DecisionResponse> requestPolicyAuthorisation({
    required String productId,
    required List<String> actions,
  }) async => throw UnimplementedError();

  @override
  Future<PolicyResponse> resolvePolicyAuthorisation({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async => throw UnimplementedError();

  @override
  Future<void> revokeStandingPolicy({
    required String productId,
    required String policyId,
    required String revokedBy,
  }) async => throw UnimplementedError();

  @override
  Future<void> resolveDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async => throw UnimplementedError();
}

/// The single-line input whose hint identifies it, so a test never depends on
/// the order fields happen to be declared in.
Finder _fieldWithHint(String hint) => find.descendant(
  of: find.byWidgetPredicate((w) => w is SingleLineInput && w.hintText == hint),
  matching: find.byType(TextField),
);

/// The control that mints the key, once it is offered.
Finder get generateControl => find.widgetWithText(FilledButton, kGenerateLabel);

void main() {
  late FakeRepositoryProbe repository;

  setUp(() {
    repository = FakeRepositoryProbe();
  });

  /// Renders the real page at [size] over a bloc created HERE, inside the test's
  /// own zone, and returns it.
  ///
  /// THE BLOC IS BUILT IN HERE, NOT IN `setUp`, AND THAT IS LOAD-BEARING.
  /// `testWidgets` runs its body inside a `FakeAsync` zone. A bloc constructed in
  /// `setUp` — which runs outside that zone — keeps its event and listener
  /// plumbing bound to the zone it was born in, so `bloc.state` advances while
  /// `BlocBuilder` never gets a frame to rebuild for. The symptom is a page that
  /// looks frozen at its first render: the state changes underneath and the tree
  /// keeps showing the cold frame. It reads exactly like the unreachable-flow bug
  /// this file exists to catch and is indistinguishable from it in the output,
  /// which is why it is documented here instead of being left to be rediscovered
  /// as a product bug. Cost me the better part of this correction to establish,
  /// so it is written down.
  ///
  /// No bloc event is dispatched directly in this file. That is the whole point:
  /// the previous suite drove the bloc and went green while the UI could not enter
  /// the state the bloc described.
  Future<AddProductBloc> pumpPage(
    WidgetTester tester,
    Size size, {
    OperatorAttestation? attestation,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bloc = AddProductBloc(
      repository: repository,
      attestation: attestation ?? _attestation,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: ShipItTheme.light(),
        home: Scaffold(body: AddProductPage(bloc: bloc)),
      ),
    );
    await tester.pumpAndSettle();
    return bloc;
  }

  /// Types into the product name and repository fields the way an operator
  /// would, so every state change arrives from the widget tree.
  Future<void> fillForm(WidgetTester tester) async {
    await tester.enterText(_fieldWithHint('e.g. TeamHub'), kProductName);
    await tester.pumpAndSettle();
    await tester.enterText(
      _fieldWithHint('git@github.com:acme/teamhub.git'),
      kRepositoryUri,
    );
    await tester.pumpAndSettle();
  }

  group('the deploy-key flow is reachable from a cold empty state', () {
    for (final layout in <({String name, Size size})>[
      (name: 'desktop', size: kDesktopSize),
      (name: 'mobile', size: kMobileSize),
    ]) {
      testWidgets(
        '${layout.name}: nothing to press when cold, then one press mints a key '
        'and makes Copy public key reachable',
        (tester) async {
          final bloc = await pumpPage(tester, layout.size);

          // COLD. No product, no repository, so there is no key and nothing may
          // offer to make one — the action cannot succeed yet.
          expect(
            generateControl,
            findsNothing,
            reason:
                'a control that cannot succeed must not be offered, and at '
                '2f6b78d there was no generate control at any state at all',
          );
          expect(find.text(kGenerateLabel), findsNothing);
          expect(bloc.state.deployKey, isNull);
          expect(find.text('Product name is required'), findsOneWidget);

          await fillForm(tester);

          // Both inputs present and not checking: the control appears, and it is
          // the control that mints — not a dead affordance.
          expect(
            generateControl,
            findsOneWidget,
            reason:
                'with a product name and a repository the mint can succeed, so '
                'it must be offered on the ${layout.name} layout',
          );

          await tester.ensureVisible(generateControl);
          await tester.tap(generateControl);
          await tester.pumpAndSettle();

          // A REAL key, minted the way the server mints one: the product and its
          // repository reference had to exist first.
          expect(bloc.state.deployKey, isNotNull);
          expect(
            repository.calls,
            containsAllInOrder([
              'createProduct',
              'addRepositoryReference',
              'generateDeployKey',
            ]),
          );

          // And the consequence the operator needs is on screen.
          expect(
            find.text(kGenerateLabel),
            findsNothing,
            reason: 'the control must not linger once a key exists',
          );
          expect(find.text(_mintedPublicKey), findsOneWidget);
          expect(find.text('Copy public key'), findsOneWidget);

          // Step 1 is done, and Register has stopped asking for a key.
          expect(
            find.text('1   A deploy key is generated for this product'),
            findsOneWidget,
          );
          expect(bloc.state.accessStatus, AccessStatus.verified);
          expect(bloc.state.canRegister, isTrue);
          expect(
            find.text('Access verified \u2014 this product can be registered'),
            findsOneWidget,
          );
        },
      );
    }

    testWidgets(
      'the generate control is not offered until both the product name and the '
      'repository are present, because it cannot succeed without both',
      (tester) async {
        final bloc = await pumpPage(tester, kDesktopSize);

        expect(
          generateControl,
          findsNothing,
          reason: 'nothing is filled, so generating cannot succeed',
        );

        // A product name alone is not enough: the mint resolves the repository
        // reference first, and there is not one yet.
        await tester.enterText(_fieldWithHint('e.g. TeamHub'), kProductName);
        await tester.pumpAndSettle();
        expect(bloc.state.repository, isEmpty);
        expect(generateControl, findsNothing);

        await tester.enterText(
          _fieldWithHint('git@github.com:acme/teamhub.git'),
          kRepositoryUri,
        );
        await tester.pumpAndSettle();
        expect(generateControl, findsOneWidget);
      },
    );
  });

  group('canRegister, through the widget tree', () {
    testWidgets('is shut while there is no key at all', (tester) async {
      final bloc = await pumpPage(tester, kDesktopSize);
      await fillForm(tester);

      expect(bloc.state.deployKey, isNull);
      expect(bloc.state.canRegister, isFalse);
      expect(
        find.text('Generate a deploy key first'),
        findsOneWidget,
        reason:
            'the Register subtext names the affordance that satisfies it; if '
            'this text ever survives a mint, the promise and the flow have come '
            'apart again',
      );
    });

    testWidgets(
      'is shut while a key exists but access is unproven, and the check is not '
      'attempted at all without a host-key confirmation',
      (tester) async {
        // Minting does not prove anything, so the gate must stay shut in the
        // middle state — reached here with no attestation, which is how a
        // deployment that has not configured a host-key confirmation behaves.
        final bloc = await pumpPage(
          tester,
          kDesktopSize,
          attestation: const OperatorAttestation(),
        );
        await fillForm(tester);
        await tester.ensureVisible(generateControl);
        await tester.tap(generateControl);
        await tester.pumpAndSettle();

        expect(bloc.state.deployKey, isNotNull);
        expect(bloc.state.accessStatus, AccessStatus.notChecked);
        expect(bloc.state.canRegister, isFalse);
        expect(
          find.text(
            'Access must be verified before a product can be registered',
          ),
          findsOneWidget,
        );
        expect(
          repository.calls,
          isNot(contains('verifyDeployKeyAccess')),
          reason:
              'nothing may be asserted to the server that was not configured',
        );
      },
    );
  });
}
