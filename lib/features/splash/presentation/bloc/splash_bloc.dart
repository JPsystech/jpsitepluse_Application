import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:sitepulse_engineer/core/storage/session_store.dart';
import 'package:sitepulse_engineer/core/storage/terms_store.dart';
import 'package:sitepulse_engineer/core/storage/mpin_store.dart';
import 'package:sitepulse_engineer/core/router/app_routes.dart';
import 'package:safe_device/safe_device.dart';
import 'package:flutter/foundation.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/core/config/app_config.dart';

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
      // Simulate min splash time for branding to match the slower animation
      await Future.delayed(const Duration(milliseconds: 2500));

      if (!kDebugMode) {
        final isMockLocation = await SafeDevice.isMockLocation;
        if (isMockLocation) {
          emit(const SplashSecurityBlocked(
              "Security Risk Detected: A Fake GPS application is currently running on this device. Please disable it to use JP Siteplus."));
          return;
        }

        final isJailBroken = await SafeDevice.isJailBroken;
        if (isJailBroken) {
          emit(const SplashSecurityBlocked(
              "Security Risk Detected: This device appears to be rooted or jailbroken. For security reasons, the app cannot proceed."));
          return;
        }
      }

      await SessionStore.load();
      final accepted = await TermsStore.isAccepted();
      final hasMpin = await MpinStore.hasMpin();

      try {
        final client = await ApiClient.instance.dio;
        final response = await client.get('/api/v1/public/ui-config');
        if (response.data != null && response.data['localization'] != null) {
          final loc = response.data['localization'];
          if (loc['date_format'] != null) {
            AppConfig.setDateFormat(loc['date_format']);
          }
        }
      } catch (e) {
        debugPrint("Failed to fetch ui-config: $e");
      }

      String nextRoute = AppRoutes.login;
      
      if (SessionStore.current != null) {
        if (!accepted) {
          nextRoute = AppRoutes.terms;
        } else if (hasMpin) {
          nextRoute = AppRoutes.mpinUnlock;
        } else {
          nextRoute = AppRoutes.mpinSetup;
        }
      }

      emit(SplashSuccess(nextRoute));
    } catch (e) {
      emit(SplashError(e.toString()));
    }
  }
}
