import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:sitepulse_engineer/core/storage/terms_store.dart';

part 'terms_event.dart';
part 'terms_state.dart';

class TermsBloc extends Bloc<TermsEvent, TermsState> {
  TermsBloc() : super(TermsInitial()) {
    on<TermsAccepted>(_onTermsAccepted);
  }

  Future<void> _onTermsAccepted(
      TermsAccepted event, Emitter<TermsState> emit) async {
    emit(TermsSaving());
    try {
      await TermsStore.setAccepted(true);
      emit(TermsSuccess());
    } catch (e) {
      emit(TermsError(e.toString()));
    }
  }
}
