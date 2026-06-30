import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:sitepulse_engineer/features/auth/data/services/auth_service.dart';

part 'change_password_event.dart';
part 'change_password_state.dart';

class ChangePasswordBloc extends Bloc<ChangePasswordEvent, ChangePasswordState> {
  ChangePasswordBloc() : super(ChangePasswordInitial()) {
    on<ChangePasswordSubmitted>(_onChangePasswordSubmitted);
  }

  bool _looksStrong(String s) {
    if (s.length < 8 || s.length > 128) return false;
    final hasLetter = s.split("").any((ch) => RegExp(r"[A-Za-z]").hasMatch(ch));
    final hasDigit = s.split("").any((ch) => RegExp(r"[0-9]").hasMatch(ch));
    return hasLetter && hasDigit;
  }

  Future<void> _onChangePasswordSubmitted(
      ChangePasswordSubmitted event, Emitter<ChangePasswordState> emit) async {
    emit(ChangePasswordSubmitting());
    try {
      if (event.currentPassword.isEmpty || event.newPassword.isEmpty || event.confirmPassword.isEmpty) {
        throw "All fields are required";
      }
      if (event.newPassword != event.confirmPassword) {
        throw "Passwords do not match";
      }
      if (!_looksStrong(event.newPassword)) {
        throw "Password must be 8-128 chars and include letters and numbers";
      }

      await AuthService().changePassword(
        token: event.sessionToken, 
        currentPassword: event.currentPassword, 
        newPassword: event.newPassword
      );
      
      emit(ChangePasswordSuccess());
    } catch (e) {
      emit(ChangePasswordError(e.toString()));
    }
  }
}
