enum ProviderErrorType {
  creditExhausted,
  rateLimited,
  unavailable,
  authFailed,
  unknown,
}

extension ProviderErrorTypeWire on ProviderErrorType {
  String get wire => switch (this) {
    ProviderErrorType.creditExhausted => 'credit_exhausted',
    ProviderErrorType.rateLimited => 'rate_limited',
    ProviderErrorType.unavailable => 'unavailable',
    ProviderErrorType.authFailed => 'auth_failed',
    ProviderErrorType.unknown => 'unknown',
  };

  static ProviderErrorType fromWire(String value) {
    return switch (value) {
      'credit_exhausted' => ProviderErrorType.creditExhausted,
      'rate_limited' => ProviderErrorType.rateLimited,
      'unavailable' => ProviderErrorType.unavailable,
      'auth_failed' => ProviderErrorType.authFailed,
      _ => ProviderErrorType.unknown,
    };
  }
}