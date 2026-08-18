part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final AuthSessionModel session;
  const AuthSuccess({required this.session});
  @override
  List<Object?> get props => [session];
}

class AuthError extends AuthState {
  final String message;
  const AuthError({required this.message});
  @override
  List<Object?> get props => [message];
}

class AuthMpinOtpSent extends AuthState {
  final String vendorCode;
  final String empCode;
  const AuthMpinOtpSent({required this.vendorCode, required this.empCode});
  @override
  List<Object?> get props => [vendorCode, empCode];
}

class AuthMpinOtpVerified extends AuthState {
  final String resetToken;
  const AuthMpinOtpVerified({required this.resetToken});
  @override
  List<Object?> get props => [resetToken];
}
