import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:sitepulse_engineer/features/home/data/models/today_assignment_model.dart';
import 'package:sitepulse_engineer/features/home/data/repositories/home_repository.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final HomeRepository _repository;

  HomeBloc({HomeRepository? repository})
      : _repository = repository ?? HomeRepository(),
        super(HomeInitial()) {
    on<LoadAssignmentsRequested>(_onLoadAssignmentsRequested);
  }

  Future<void> _onLoadAssignmentsRequested(LoadAssignmentsRequested event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    try {
      final response = await _repository.getTodayAssignments();
      emit(HomeSuccess(response: response));
    } catch (e) {
      emit(HomeError(message: e.toString()));
    }
  }
}
