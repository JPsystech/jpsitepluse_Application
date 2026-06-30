part of 'change_password_bloc.dart';

abstract class ChangePasswordEvent extends Equatable {
  const ChangePasswordEvent();

  @override
  List<Object> get props => [];
}

class ChangePasswordSubmitted extends ChangePasswordEvent {
  final String sessionToken;
  final String currentPassword;
  final String newPassword;
  final String confirmPassword;

  const ChangePasswordSubmitted({
    required this.sessionToken,
    required this.currentPassword,
    required this.newPassword,
    required this.confirmPassword,
  });

  @override
  List<Object> get props => [sessionToken, currentPassword, newPassword, confirmPassword];
}
