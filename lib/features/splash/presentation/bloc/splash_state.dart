part of 'splash_bloc.dart';

abstract class SplashState extends Equatable {
  const SplashState();
  
  @override
  List<Object> get props => [];
}

class SplashInitial extends SplashState {}

class SplashLoading extends SplashState {}

class SplashSuccess extends SplashState {
  final String nextRoute;

  const SplashSuccess(this.nextRoute);

  @override
  List<Object> get props => [nextRoute];
}

class SplashError extends SplashState {
  final String errorMessage;

  const SplashError(this.errorMessage);

  @override
  List<Object> get props => [errorMessage];
}
