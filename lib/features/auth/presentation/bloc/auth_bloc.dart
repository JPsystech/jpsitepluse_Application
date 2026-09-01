import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:sitepulse_engineer/features/auth/data/models/auth_session_model.dart';
import 'package:sitepulse_engineer/features/auth/data/repositories/auth_repository.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';
import 'package:sitepulse_engineer/core/storage/credential_store.dart';
import 'package:sitepulse_engineer/core/storage/offline_session_cache.dart';
import 'package:sitepulse_engineer/core/storage/mpin_store.dart';
import 'package:sitepulse_engineer/core/error/error_handler.dart';
part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;

  AuthBloc({AuthRepository? repository})
      : _repository = repository ?? AuthRepository(),
        super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<ChangePasswordRequested>(_onChangePasswordRequested);
    on<SendMpinOtpEvent>(_onSendMpinOtp);
    on<VerifyMpinOtpEvent>(_onVerifyMpinOtp);
  }

  Future<void> _onLoginRequested(
      LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final deviceId = await SessionStore.getDeviceId();
      final session = await _repository.login(
        companyCode: event.vendorCode,
        empCode: event.empCode,
        password: event.password,
        rememberMe: event.rememberMe,
        deviceId: deviceId,
      );
      await SessionStore.set(session);
      await CredentialStore.saveCredentials(
        vendorCode: event.vendorCode,
        empCode: event.empCode,
        password: event.password,
        engineerName: session.engineer.fullName,
      );
      await OfflineSessionCache.save(session);
      emit(AuthSuccess(session: session));
    } catch (e) {
      final isOffline = ErrorHandler.isOfflineError(e);
      
      if (isOffline) {
        // Fallback for offline MPIN login
        final hasMpin = await MpinStore.hasMpin();
        if (hasMpin) {
          final isMatch = await MpinStore.verifyMpin(event.password);
          if (isMatch) {
            final cachedSession = await OfflineSessionCache.get();
            if (cachedSession != null) {
              final sessionModel = AuthSessionModel(
                token: cachedSession.token,
                engineer: cachedSession.engineer,
                mustChangePassword: cachedSession.mustChangePassword,
                expiresAtMs: cachedSession.expiresAtMs,
                hasMpin: cachedSession.hasMpin,
                acceptedTerms: cachedSession.acceptedTerms,
              );
              await SessionStore.set(sessionModel);
              emit(AuthSuccess(session: sessionModel));
              return;
            }
          } else {
            emit(const AuthError(message: "Invalid MPIN."));
            return;
          }
        }
      }
      
      final appError = ErrorHandler.handle(e);
      emit(AuthError(message: appError.userMessage));
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
      final appError = ErrorHandler.handle(e);
      emit(AuthError(message: appError.userMessage));
    }
  }

  Future<void> _onSendMpinOtp(
      SendMpinOtpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _repository.sendMpinOtp(event.vendorCode, event.empCode, event.email);
      emit(AuthMpinOtpSent(vendorCode: event.vendorCode, empCode: event.empCode));
    } catch (e) {
      final appError = ErrorHandler.handle(e);
      emit(AuthError(message: appError.userMessage));
    }
  }

  Future<void> _onVerifyMpinOtp(
      VerifyMpinOtpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final token = await _repository.verifyMpinOtp(event.vendorCode, event.empCode, event.otp);
      emit(AuthMpinOtpVerified(resetToken: token));
    } catch (e) {
      final appError = ErrorHandler.handle(e);
      emit(AuthError(message: appError.userMessage));
    }
  }
}
