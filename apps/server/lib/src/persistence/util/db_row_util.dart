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
///
/// ## THIS STAYS STRICT, DELIBERATELY
///
/// A column that holds parseable JSON of the WRONG TYPE throws here rather
/// than degrading, because every one of its callers passes the result straight
/// into a typed constructor and a silent `null` would be indistinguishable from
/// a genuinely absent value. Fourteen call sites across six stores depend on
/// that loudness; weakening it here to accommodate one column would trade a
/// crash on ONE row for a silent wrong answer on any of them.
///
/// The tolerant read is [readJsonArrayColumn], which REPORTS what it found
/// instead of swallowing it. A caller that must not crash takes that one and is
/// handed the reason.
List<dynamic>? decodeJsonArray(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return jsonDecode(value) as List<dynamic>;
}

/// Why a column declared to hold a JSON array did not yield a [List].
enum JsonArrayDefect {
  /// Parseable JSON of a non-array type: an object, a string, a number, a
  /// boolean, or the literal `null`.
  notAnArray,

  /// The column did not hold parseable JSON at all.
  unparseable,
}

/// The outcome of reading a JSON-array column without throwing.
///
/// Three outcomes, and the distinction between the first two is the whole point
/// of this type: an ABSENT column is data, and a DEFECTIVE column is a fault.
/// A reader that collapses both to `null` has turned a fault into data, which
/// is how a malformed row reaches an operator screen looking healthy.
class JsonArrayColumnRead {
  const JsonArrayColumnRead._({
    this.value,
    this.defect,
    this.raw,
  });

  /// NULL, empty or whitespace. NOT a defect — a column nobody ever wrote to.
  const JsonArrayColumnRead.absent()
    : this._(value: null, defect: null, raw: null);

  /// Parseable JSON holding an array.
  const JsonArrayColumnRead.array(List<dynamic> value)
    : this._(value: value, defect: null, raw: null);

  /// The column held something that is not an array. [raw] is the column
  /// exactly as read, so a caller can log the evidence rather than only the
  /// verdict.
  const JsonArrayColumnRead.defective(JsonArrayDefect defect, String raw)
    : this._(value: null, defect: defect, raw: raw);

  /// The decoded array, or null when the column was absent or defective.
  final List<dynamic>? value;

  /// Why the read failed, or null when it did not.
  final JsonArrayDefect? defect;

  /// The offending column text, present only when [isDefective].
  final String? raw;

  bool get isDefective => defect != null;

  @override
  String toString() => isDefective
      ? 'JsonArrayColumnRead(defect: $defect, raw: ${raw?.length ?? 0} chars)'
      : 'JsonArrayColumnRead(value: ${value?.length ?? 'null'} elements)';
}

/// Reads a JSON-array column and classifies every failure instead of throwing.
///
/// This is the tolerant sibling of [decodeJsonArray] and exists for columns
/// that a row-level read must survive: the value is a property of ONE stored
/// row, and a row this reader cannot decode must not be able to fail a whole
/// endpoint for every other row in the same table.
///
/// It NEVER invents a value. A defective column yields [value] null and a
/// [defect]; what the caller does about that is its decision, and the reason
/// travels with it precisely so that decision cannot be silent.
JsonArrayColumnRead readJsonArrayColumn(String? value) {
  if (value == null || value.trim().isEmpty) {
    return const JsonArrayColumnRead.absent();
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(value);
  } on FormatException {
    return JsonArrayColumnRead.defective(JsonArrayDefect.unparseable, value);
  }
  if (decoded is List) return JsonArrayColumnRead.array(decoded);
  return JsonArrayColumnRead.defective(JsonArrayDefect.notAnArray, value);
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
