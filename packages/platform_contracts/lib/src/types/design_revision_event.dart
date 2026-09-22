import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'design_revision_event.g.dart';

@JsonSerializable(explicitToJson: true)
@immutable
class DesignRevisionEvent extends Equatable {
  const DesignRevisionEvent({
    required this.eventId,
    required this.designRevisionId,
    required this.eventType,
    required this.payloadJson,
    required this.sequence,
    required this.createdAt,
  });

  final String eventId;
  final String designRevisionId;
  final String eventType;
  final String payloadJson;
  final int sequence;
  final DateTime createdAt;

  factory DesignRevisionEvent.fromJson(Map<String, dynamic> json) =>
      _$DesignRevisionEventFromJson(json);

  Map<String, dynamic> toJson() => _$DesignRevisionEventToJson(this);

  @override
  List<Object?> get props => [
        eventId,
        designRevisionId,
        eventType,
        payloadJson,
        sequence,
        createdAt,
      ];
}