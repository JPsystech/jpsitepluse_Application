part of 'change_password_bloc.dart';

abstract class ChangePasswordState extends Equatable {
  const ChangePasswordState();
  
  @override
  List<Object> get props => [];
}

class ChangePasswordInitial extends ChangePasswordState {}

class ChangePasswordSubmitting extends ChangePasswordState {}

class ChangePasswordSuccess extends ChangePasswordState {}

class ChangePasswordError extends ChangePasswordState {
  final String message;

  const ChangePasswordError(this.message);

  @override
  List<Object> get props => [message];
}
