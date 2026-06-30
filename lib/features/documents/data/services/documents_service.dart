import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;

import "package:sitepulse_engineer/shared/models/engineer_document_model.dart";
import "package:sitepulse_engineer/core/services/api_client.dart";

class DocumentsService {
  DocumentsService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  static const int maxBytes = 15 * 1024 * 1024;

  Future<List<EngineerDocument>> listDocuments({required String token}) async {
    final uri = await api.url("/api/v1/engineer/documents");
    final json = await api.getJson(uri,
        headers: {HttpHeaders.authorizationHeader: "Bearer $token"});
    final resp = EngineerDocumentListResponse.fromUnknown(json);
    return resp.items;
  }

  Future<EngineerDocumentPresignResponse> presign({
    required String token,
    required String documentType,
    required String? documentName,
    required String contentType,
    required int sizeBytes,
    required String originalFileName,
    required String? fileExtension,
  }) async {
    final uri = await api.url("/api/v1/engineer/documents/presign");
    final json = await api.postJson(
      uri,
      headers: {
        HttpHeaders.authorizationHeader: "Bearer $token",
        HttpHeaders.contentTypeHeader: "application/json",
      },
      body: jsonEncode({
        "document_type": documentType,
        if (documentName != null) "document_name": documentName,
        "content_type": contentType,
        "size_bytes": sizeBytes,
        if (fileExtension != null) "file_extension": fileExtension,
        "original_filename": originalFileName,
      }),
    );
    if (json == null) {
      throw ApiException("Invalid response from server");
    }
    return EngineerDocumentPresignResponse.fromJson(json);
  }

  Future<EngineerDocument> complete({
    required String token,
    required String documentType,
    required String? documentName,
    required String key,
    required String publicUrl,
    required String contentType,
    required int sizeBytes,
    required String originalFileName,
  }) async {
    final uri = await api.url("/api/v1/engineer/documents/complete");
    final json = await api.postJson(
      uri,
      headers: {
        HttpHeaders.authorizationHeader: "Bearer $token",
        HttpHeaders.contentTypeHeader: "application/json",
      },
      body: jsonEncode({
        "document_type": documentType,
        if (documentName != null) "document_name": documentName,
        "key": key,
        "public_url": publicUrl,
        "content_type": contentType,
        "size_bytes": sizeBytes,
        "original_filename": originalFileName,
      }),
    );
    if (json == null) {
      throw ApiException("Invalid response from server");
    }
    return EngineerDocument.fromJson(json);
  }

  Future<EngineerDocument> uploadDocumentBytes({
    required String token,
    required String documentType,
    required String? documentName,
    required List<int> bytes,
    required String originalFileName,
    required String contentType,
    required int sizeBytes,
    required String? fileExtension,
  }) async {
    final presigned = await presign(
      token: token,
      documentType: documentType,
      documentName: documentName,
      contentType: contentType,
      sizeBytes: sizeBytes,
      originalFileName: originalFileName,
      fileExtension: fileExtension,
    );

    if (presigned.uploadUrl.trim().isEmpty) {
      throw ApiException("Presign failed: upload_url missing");
    }
    if (presigned.key.trim().isEmpty) {
      throw ApiException("Presign failed: key missing");
    }
    if (presigned.publicUrl.trim().isEmpty) {
      throw ApiException("Presign failed: public_url missing");
    }

    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: contentType
    };
    headers.addAll(presigned.requiredHeaders);

    try {
      final primary = Uri.parse(presigned.uploadUrl.trim());
      http.Response resp;
      try {
        resp = await api.client.put(primary, headers: headers, body: bytes);
      } on HandshakeException {
        final alt = (presigned.uploadUrlAlt ?? "").trim();
        if (alt.isEmpty) {
          rethrow;
        }
        resp =
            await api.client.put(Uri.parse(alt), headers: headers, body: bytes);
      }

      if (resp.statusCode != 200 &&
          resp.statusCode != 201 &&
          resp.statusCode != 204) {
        throw ApiException(
            "Upload failed (status ${resp.statusCode}): ${resp.body}");
      }
    } on HandshakeException catch (e) {
      throw ApiException("Upload failed (TLS): $e");
    } on SocketException catch (e) {
      throw ApiException("Upload failed (network): $e");
    } on http.ClientException catch (e) {
      throw ApiException("Upload failed: $e");
    }

    return complete(
      token: token,
      documentType: documentType,
      documentName: documentName,
      key: presigned.key,
      publicUrl: presigned.publicUrl,
      contentType: contentType,
      sizeBytes: sizeBytes,
      originalFileName: originalFileName,
    );
  }
}
