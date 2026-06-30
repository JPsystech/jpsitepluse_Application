import 'package:sitepulse_engineer/features/home/data/models/today_assignment_model.dart';
import 'package:sitepulse_engineer/features/home/data/services/home_service.dart';

class HomeRepository {
  final HomeService _homeService;

  HomeRepository({HomeService? homeService})
      : _homeService = homeService ?? HomeService();

  Future<TodayAssignmentResponseModel> getTodayAssignments() async {
    return await _homeService.getTodayAssignments();
  }
}
