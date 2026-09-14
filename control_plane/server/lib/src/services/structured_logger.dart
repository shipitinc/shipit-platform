import 'package:serverpod/serverpod.dart';

/// Structured logger for control-plane endpoint and service layers.
///
/// Emits a single line per event with a stable `event` prefix and
/// `key=value` fields, routed to the Serverpod session log (which is itself
/// persisted to Postgres). Levels follow [LogLevel].
class StructuredLogger {
  StructuredLogger(this._session, [this._component = 'control_plane']);

  final Session _session;
  final String _component;

  void debug(String event, [Map<String, Object?>? fields]) =>
      _emit(LogLevel.debug, event, fields);

  void info(String event, [Map<String, Object?>? fields]) =>
      _emit(LogLevel.info, event, fields);

  void warning(String event, [Map<String, Object?>? fields]) =>
      _emit(LogLevel.warning, event, fields);

  void error(String event, [Map<String, Object?>? fields]) =>
      _emit(LogLevel.error, event, fields);

  void _emit(
    LogLevel level,
    String event,
    Map<String, Object?>? fields,
  ) {
    final buffer = StringBuffer('[$_component] $event');
    fields?.forEach((key, value) => buffer.write(' $key=$_format(value)'));
    _session.log(buffer.toString(), level: level);
  }

  static String _format(Object? value) {
    if (value == null) return 'null';
    if (value is String) return '"$value"';
    if (value is DateTime) return value.toIso8601String();
    return '$value';
  }
}

/// Renders a domain `toJson()` map into a JSON-encodeable object.
Map<String, Object?> toJsonObject(Map<String, dynamic> json) =>
    Map<String, Object?>.from(json);

/// Renders a list of domain `toJson()` maps into JSON-encodeable objects.
List<Object?> toJsonList(Iterable<Map<String, dynamic>> jsonList) =>
    jsonList.map(Map<String, Object?>.from).toList();
