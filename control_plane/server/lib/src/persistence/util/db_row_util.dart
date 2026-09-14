import 'dart:convert';

/// Decodes a JSON document column into a `Map<String, dynamic>`, or null when
/// the column is NULL/empty.
Map<String, dynamic>? decodeJsonMap(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final decoded = jsonDecode(value);
  return decoded == null ? null : (decoded as Map<String, dynamic>);
}

/// Decodes a JSON array column into a `List<T>`, or null when the column is
/// NULL/empty.
List<T>? decodeJsonList<T>(
  String? value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value == null || value.trim().isEmpty) return null;
  final decoded = jsonDecode(value) as List<dynamic>;
  return decoded
      .map((e) => fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

/// Decodes a raw JSON array column into a `List<dynamic>`, or null when the
/// column is NULL/empty. Useful when the elements are primitive (e.g. a list
/// of capability names) rather than JSON objects.
List<dynamic>? decodeJsonArray(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return jsonDecode(value) as List<dynamic>;
}

/// Decodes a `timestamp without time zone` cell back into its UTC instant.
///
/// Domain DateTimes are always stored as UTC wall-clock values, so the naive
/// timestamp read from PostgreSQL is interpreted as UTC. Accepts the raw
/// driver value (a [DateTime] without a zone) to stay driver-agnostic.
DateTime? decodeUtc(Object? value) {
  if (value == null) return null;
  if (value is String) return DateTime.parse(value).toUtc();
  final t = value as DateTime;
  return DateTime.utc(
    t.year,
    t.month,
    t.day,
    t.hour,
    t.minute,
    t.second,
    t.millisecond,
    t.microsecond,
  );
}
