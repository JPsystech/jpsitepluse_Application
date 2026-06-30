import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:sitepulse_engineer/core/storage/session_store.dart';
import 'package:sitepulse_engineer/core/storage/terms_store.dart';
import 'package:sitepulse_engineer/core/router/app_routes.dart';

part 'splash_event.dart';
part 'splash_state.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  SplashBloc() : super(SplashInitial()) {
    on<SplashInitialized>(_onSplashInitialized);
  }

  Future<void> _onSplashInitialized(
      SplashInitialized event, Emitter<SplashState> emit) async {
    emit(SplashLoading());
    try {
      // Simulate min splash time for branding
      await Future.delayed(const Duration(milliseconds: 300));

      await SessionStore.load();
      final accepted = await TermsStore.isAccepted();

      final nextRoute = SessionStore.current == null
          ? AppRoutes.login
          : (accepted ? AppRoutes.app : AppRoutes.terms);

      emit(SplashSuccess(nextRoute));
    } catch (e) {
      emit(SplashError(e.toString()));
    }
  }
}
