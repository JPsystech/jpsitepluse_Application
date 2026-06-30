part of 'timeline_bloc.dart';

abstract class TimelineEvent extends Equatable {
  const TimelineEvent();
  @override
  List<Object?> get props => [];
}

class LoadTimelineRequested extends TimelineEvent {
  final String sessionToken;
  final String month;
  
  const LoadTimelineRequested({required this.sessionToken, this.month = ""});
  
  @override
  List<Object?> get props => [sessionToken, month];
}

class FilterTimelineRequested extends TimelineEvent {
  final String statusFilter;
  
  const FilterTimelineRequested({required this.statusFilter});
  
  @override
  List<Object?> get props => [statusFilter];
}

class DownloadTimelinePdfRequested extends TimelineEvent {
  final String sessionToken;
  final String month;

  const DownloadTimelinePdfRequested({required this.sessionToken, required this.month});

  @override
  List<Object?> get props => [sessionToken, month];
}
