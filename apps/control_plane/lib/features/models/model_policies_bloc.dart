import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/control_plane_repository.dart';

sealed class ModelPoliciesEvent {
  const ModelPoliciesEvent();
}

class ModelPoliciesLoaded extends ModelPoliciesEvent {
  const ModelPoliciesLoaded();
}

class ModelPoliciesBloc extends Bloc<ModelPoliciesEvent, ModelPoliciesState> {
  ModelPoliciesBloc({required ControlPlaneRepository repository})
    : _repository = repository,
      super(const ModelPoliciesState()) {
    on<ModelPoliciesLoaded>(_onLoaded);
  }

  final ControlPlaneRepository _repository;

  ControlPlaneRepository get repository => _repository;

  Future<void> _onLoaded(
    ModelPoliciesLoaded event,
    Emitter<ModelPoliciesState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final policies = await _repository.listModelPolicies();
      final providerHealth = await _repository.getProviderHealth();
      emit(
        ModelPoliciesState(
          isLoading: false,
          policies: policies.map(ModelPolicyRow.fromResponse).toList(),
          knownModels: providerHealth.knownModels,
          providerHealth: providerHealth,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }
}

class ModelPoliciesState {
  const ModelPoliciesState({
    this.isLoading = false,
    this.policies = const [],
    this.knownModels = const [],
    this.providerHealth,
    this.errorMessage,
  });

  final bool isLoading;
  final List<ModelPolicyRow> policies;
  final List<KnownModelResponse> knownModels;
  final ProviderHealthResponse? providerHealth;
  final String? errorMessage;

  ProviderHealthResponse get safeProviderHealth => providerHealth ?? ProviderHealthResponse(providers: [], knownModels: []);

  ModelPoliciesState copyWith({
    bool? isLoading,
    List<ModelPolicyRow>? policies,
    List<KnownModelResponse>? knownModels,
    ProviderHealthResponse? providerHealth,
    String? errorMessage,
    bool clearError = false,
  }) => ModelPoliciesState(
    isLoading: isLoading ?? this.isLoading,
    policies: policies ?? this.policies,
    knownModels: knownModels ?? this.knownModels,
    providerHealth: providerHealth ?? this.providerHealth,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

class ModelPolicyRow {
  const ModelPolicyRow({
    required this.role,
    required this.chain,
    required this.version,
    required this.updatedAt,
    required this.updatedByDecisionId,
    required this.isActive,
  });

  factory ModelPolicyRow.fromResponse(ModelPolicyResponse r) => ModelPolicyRow(
    role: r.role,
    chain: r.chain,
    version: r.version,
    updatedAt: r.updatedAt,
    updatedByDecisionId: r.updatedByDecisionId,
    isActive: r.isActive,
  );

  final String role;
  final List<ModelStepResponse> chain;
  final int version;
  final DateTime updatedAt;
  final String updatedByDecisionId;
  final bool isActive;

  String get roleLabel => _formatRole(role);

  static String _formatRole(String role) {
    return role
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}