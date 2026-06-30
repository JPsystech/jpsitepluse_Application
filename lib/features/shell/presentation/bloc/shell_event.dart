part of 'shell_bloc.dart';

abstract class ShellEvent extends Equatable {
  const ShellEvent();

  @override
  List<Object> get props => [];
}

class ShellTabChanged extends ShellEvent {
  final int index;

  const ShellTabChanged(this.index);

  @override
  List<Object> get props => [index];
}
