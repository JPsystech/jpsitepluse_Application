import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

part 'shell_event.dart';
part 'shell_state.dart';

class ShellBloc extends Bloc<ShellEvent, ShellState> {
  ShellBloc() : super(const ShellState()) {
    on<ShellTabChanged>((event, emit) {
      emit(state.copyWith(currentIndex: event.index));
    });
  }
}
