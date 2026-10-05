sealed class DefectListEvent {}

class DefectListLoaded extends DefectListEvent {
  DefectListLoaded({
    this.status,
    this.classification,
    this.productId,
    this.limit,
  });

  final String? status;
  final String? classification;
  final String? productId;
  final int? limit;
}

class DefectListFilterChanged extends DefectListEvent {
  DefectListFilterChanged({
    this.status,
    this.classification,
    this.productId,
    this.limit,
  });

  final String? status;
  final String? classification;
  final String? productId;
  final int? limit;
}

class DefectListPageRequested extends DefectListEvent {
  DefectListPageRequested({this.offset, this.limit});

  final int? offset;
  final int? limit;
}

class DefectListRefreshed extends DefectListEvent {}
