enum RunsFilter {
  all('All work'),
  workingOnIt('Working on it'),
  needsYou('Needs you'),
  finished('Finished'),
  failed('Failed');

  const RunsFilter(this.label);
  final String label;
}

sealed class RunsEvent {
  const RunsEvent();
}

class RunsLoaded extends RunsEvent {}

class RunsFilterChanged extends RunsEvent {
  const RunsFilterChanged(this.filter);

  final RunsFilter filter;
}
