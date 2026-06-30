import "dart:io";
import "package:sitepulse_engineer/core/services/api_client.dart";
import "package:sitepulse_engineer/shared/models/today_assignment.dart";

class HistoryService {
  final ApiClient api;

  HistoryService({ApiClient? api}) : api = api ?? ApiClient();

  Future<EngineerHistoryResponse> history(
      {required String token, String? month}) async {
    final qs = (month != null && month.trim().isNotEmpty)
        ? "?month=${Uri.encodeComponent(month.trim())}"
        : "";
    final uri = await api.url("/api/v1/engineer/history$qs");
    final json = await api.getJson(uri,
        headers: {HttpHeaders.authorizationHeader: "Bearer $token"});
    if (json == null) {
      throw ApiException("Invalid response from server");
    }
    return EngineerHistoryResponse.fromJson(json);
  }
}
