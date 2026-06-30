part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class LoginRequested extends AuthEvent {
  final String companyCode;
  final String empCode;
  final String password;

  const LoginRequested({
    required this.companyCode,
    required this.empCode,
    required this.password,
  });

  @override
  List<Object?> get props => [companyCode, empCode, password];
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
