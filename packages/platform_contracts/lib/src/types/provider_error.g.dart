// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_error.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProviderError _$ProviderErrorFromJson(Map<String, dynamic> json) =>
    ProviderError(
      type: $enumDecode(_$ProviderErrorTypeEnumMap, json['type']),
      provider: json['provider'] as String,
      message: json['message'] as String,
    );

Map<String, dynamic> _$ProviderErrorToJson(ProviderError instance) =>
    <String, dynamic>{
      'type': _$ProviderErrorTypeEnumMap[instance.type]!,
      'provider': instance.provider,
      'message': instance.message,
    };

const _$ProviderErrorTypeEnumMap = {
  ProviderErrorType.creditExhausted: 'creditExhausted',
  ProviderErrorType.rateLimited: 'rateLimited',
  ProviderErrorType.unavailable: 'unavailable',
  ProviderErrorType.authFailed: 'authFailed',
  ProviderErrorType.unknown: 'unknown',
};
