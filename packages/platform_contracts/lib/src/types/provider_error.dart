import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/provider_error_type.dart';

part 'provider_error.g.dart';

@JsonSerializable(explicitToJson: true)
@immutable
class ProviderError extends Equatable {
  const ProviderError({
    required this.type,
    required this.provider,
    required this.message,
  });

  final ProviderErrorType type;
  final String provider;
  final String message;

  factory ProviderError.fromJson(Map<String, dynamic> json) =>
      _$ProviderErrorFromJson(json);

  Map<String, dynamic> toJson() => _$ProviderErrorToJson(this);

  @override
  List<Object?> get props => [type, provider, message];
}