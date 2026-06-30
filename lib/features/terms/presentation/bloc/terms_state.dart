part of 'terms_bloc.dart';

abstract class TermsState extends Equatable {
  const TermsState();

  @override
  List<Object> get props => [];
}

class TermsInitial extends TermsState {}

class TermsSaving extends TermsState {}

class TermsSuccess extends TermsState {}

class TermsError extends TermsState {
  final String message;

  const TermsError(this.message);

  @override
  List<Object> get props => [message];
}
