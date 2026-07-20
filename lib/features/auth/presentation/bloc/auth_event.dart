part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class LoginRequested extends AuthEvent {
  final String vendorCode;
  final String empCode;
  final String password;
  final bool rememberMe;

  const LoginRequested({
    required this.vendorCode,
    required this.empCode,
    required this.password,
    this.rememberMe = false,
  });

  @override
  List<Object?> get props => [vendorCode, empCode, password, rememberMe];
}

class ChangePasswordRequested extends AuthEvent {
  final String token;
  final String currentPassword;
  final String newPassword;

  const ChangePasswordRequested({
    required this.token,
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [token, currentPassword, newPassword];
}
