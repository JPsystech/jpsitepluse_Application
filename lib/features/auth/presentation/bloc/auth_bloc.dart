import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:sitepulse_engineer/features/auth/data/models/auth_session_model.dart';
import 'package:sitepulse_engineer/features/auth/data/repositories/auth_repository.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;

  AuthBloc({AuthRepository? repository})
      : _repository = repository ?? AuthRepository(),
        super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<ChangePasswordRequested>(_onChangePasswordRequested);
  }

  Future<void> _onLoginRequested(
      LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final session = await _repository.login(
        companyCode: event.companyCode,
        empCode: event.empCode,
        password: event.password,
      );
      await SessionStore.set(session);
      emit(AuthSuccess(session: session));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onChangePasswordRequested(
      ChangePasswordRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _repository.changePassword(
        token: event.token,
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
      );
      emit(AuthInitial());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }
}
