import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:sitepulse_engineer/core/storage/session_store.dart';
import 'package:sitepulse_engineer/core/services/offline_punch_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc() : super(ProfileInitial()) {
    on<ProfileLogoutRequested>(_onProfileLogoutRequested);
  }

  Future<void> _onProfileLogoutRequested(
      ProfileLogoutRequested event, Emitter<ProfileState> emit) async {
    await SessionStore.clear();
    await OfflinePunchQueue().clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("cached_today_assignments_v1");
    emit(ProfileLogoutSuccess());
  }
}
