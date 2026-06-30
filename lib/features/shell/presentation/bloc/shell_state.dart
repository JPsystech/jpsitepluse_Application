part of 'shell_bloc.dart';

class ShellState extends Equatable {
  final int currentIndex;

  const ShellState({this.currentIndex = 0});

  ShellState copyWith({int? currentIndex}) {
    return ShellState(
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }

  @override
  List<Object> get props => [currentIndex];
}
