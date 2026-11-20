import "dart:convert";
import "dart:io";
import "package:shared_preferences/shared_preferences.dart";

import "package:dio/dio.dart";
import "package:sitepulse_engineer/core/network/api_client.dart";

import "package:sitepulse_engineer/shared/models/engineer_document_model.dart";
import "package:sitepulse_engineer/core/error/error_handler.dart";
import "package:sitepulse_engineer/core/error/app_exception.dart";
import "package:sitepulse_engineer/core/error/error_type.dart";

class DocumentsService {
  DocumentsService({ApiClient? api}) : api = api ?? ApiClient.instance;

  final ApiClient api;

  static const int maxBytes = 15 * 1024 * 1024;

  Future<List<DocumentTypeDefinition>> documentTypes({
    required String token,
  }) async {
    final client = await api.dio;
    final response = await client.get("/api/v1/engineer/document-types");
    final rows = response.data is List ? response.data as List : const [];
    return rows
        .whereType<Map>()
        .map((row) => DocumentTypeDefinition.fromJson(
            Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<DocumentTypeDefinition?> documentType({
    required String token,
    required String documentType,
  }) async {
    final normalizedType = documentType.trim().toLowerCase();
    final types = await documentTypes(token: token);
    for (final type in types) {
      if (type.code.toLowerCase() == normalizedType) return type;
    }
    return null;
  }

  Future<List<DocumentFieldDefinition>> documentFields({
    required String token,
    required String documentType,
  }) async => (await this.documentType(token: token, documentType: documentType))?.fields ?? const [];

  Future<List<EngineerDocument>> listDocuments({required String token}) async {
    final cacheKey = "cached_documents_v1";

    try {
      final client = await api.dio;
      final res = await client.get("/api/v1/engineer/documents");
      final json = res.data;
      
      // Save to cache on success
      if (json != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(json));
      }

      final resp = EngineerDocumentListResponse.fromUnknown(json);
      return resp.items;
    } catch (e) {
      final isOffline = ErrorHandler.isOfflineError(e);
      
      if (isOffline) {
        // Try to load from cache
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString(cacheKey);
        if (cachedData != null) {
          final json = jsonDecode(cachedData);
          final resp = EngineerDocumentListResponse.fromUnknown(json);
          return resp.items;
        } else {
          throw const AppException(
            userMessage: "Unable to connect to the server and no documents are available.",
            type: AppErrorType.network,
          );
        }
      }
      rethrow;
    }
  }

  Future<EngineerDocumentPresignResponse> presign({
    required String token,
    required String documentType,
    required String? documentName,
    required String contentType,
    required int sizeBytes,
    required String originalFileName,
    required String? fileExtension,
    Map<String, dynamic> fieldValues = const {},
  }) async {
    final client = await api.dio;
    final res = await client.post(
      "/api/v1/engineer/documents/presign",
      data: {
        "document_type": documentType,
        if (documentName != null) "document_name": documentName,
        "content_type": contentType,
        "size_bytes": sizeBytes,
        if (fileExtension != null) "file_extension": fileExtension,
        "original_filename": originalFileName,
        "field_values": fieldValues,
      },
    );
    final json = res.data;
    if (json == null) {
      throw Exception("Invalid response from server");
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
    Map<String, dynamic> fieldValues = const {},
  }) async {
    final client = await api.dio;
    final res = await client.post(
      "/api/v1/engineer/documents/complete",
      data: {
        "document_type": documentType,
        if (documentName != null) "document_name": documentName,
        "key": key,
        "download_url": publicUrl,
        "content_type": contentType,
        "size_bytes": sizeBytes,
        "original_filename": originalFileName,
        "field_values": fieldValues,
      },
    );
    final json = res.data;
    if (json == null) {
      throw Exception("Invalid response from server");
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
    Map<String, dynamic> fieldValues = const {},
  }) async {
    final presigned = await presign(
      token: token,
      documentType: documentType,
      documentName: documentName,
      contentType: contentType,
      sizeBytes: sizeBytes,
      originalFileName: originalFileName,
      fileExtension: fileExtension,
      fieldValues: fieldValues,
    );

    if (presigned.uploadUrl.trim().isEmpty) {
      throw Exception("Presign failed: upload_url missing");
    }
    if (presigned.key.trim().isEmpty) {
      throw Exception("Presign failed: key missing");
    }
    if (presigned.publicUrl.trim().isEmpty) {
      throw Exception("Presign failed: public_url missing");
    }

    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: contentType
    };
    headers.addAll(presigned.requiredHeaders);

    try {
      final uploadDio = Dio();
      var uploadUrl = presigned.uploadUrl.trim();
      if (!uploadUrl.startsWith("http")) {
        final base = (await api.dio).options.baseUrl;
        uploadUrl = "$base$uploadUrl";
      }
      
      Response res;
      try {
        res = await uploadDio.put(
          uploadUrl,
          data: bytes,
          options: Options(headers: headers),
        );
      } on DioException {
        final alt = (presigned.uploadUrlAlt ?? "").trim();
        if (alt.isEmpty) {
          rethrow;
        }
        var altUrl = alt;
        if (!altUrl.startsWith("http")) {
          final base = (await api.dio).options.baseUrl;
          altUrl = "$base$altUrl";
        }
        res = await uploadDio.put(
          altUrl,
          data: bytes,
          options: Options(headers: headers),
        );
      }

      if (res.statusCode != 200 &&
          res.statusCode != 201 &&
          res.statusCode != 204) {
        throw Exception(
            "Upload failed (status ${res.statusCode}): ${res.data}");
      }
    } catch (e) {
      rethrow;
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
      fieldValues: fieldValues,
    );
  }

  Future<void> deleteDocument({
    required String token,
    required String documentId,
  }) async {
    final client = await api.dio;
    final options = (token.isNotEmpty)
        ? Options(headers: {'Authorization': 'Bearer $token'})
        : null;

    final res = await client.delete(
      "/api/v1/engineer/documents/$documentId",
      options: options,
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception("Failed to delete document (status ${res.statusCode})");
    }
  }
}

class DocumentFieldDefinition {
  final String key;
  final String label;
  final String fieldType;
  final bool required;
  final List<String> options;
  final String? helpText;
  final bool isExpiry;

  const DocumentFieldDefinition({
    required this.key,
    required this.label,
    required this.fieldType,
    required this.required,
    required this.options,
    this.helpText,
    this.isExpiry = false,
  });

  factory DocumentFieldDefinition.fromJson(Map<String, dynamic> json) => DocumentFieldDefinition(
    key: json["key"]?.toString() ?? "",
    label: json["label"]?.toString() ?? "Field",
    fieldType: json["field_type"]?.toString() ?? "text",
    required: json["required"] == true,
    options: json["options"] is List ? (json["options"] as List).map((value) => value.toString()).toList() : const [],
    helpText: json["help_text"]?.toString(),
    isExpiry: json["is_expiry"] == true,
  );
}

class DocumentTypeDefinition {
  const DocumentTypeDefinition({
    required this.code,
    required this.name,
    required this.fields,
    required this.extensions,
    required this.sources,
  });

  final String code;
  final String name;
  final List<DocumentFieldDefinition> fields;
  final List<String> extensions;
  final List<String> sources;

  factory DocumentTypeDefinition.fromJson(Map<String, dynamic> json) {
    final rules = json["upload_rules"] is Map ? Map<String, dynamic>.from(json["upload_rules"] as Map) : const <String, dynamic>{};
    return DocumentTypeDefinition(
      code: json["code"]?.toString().trim() ?? "",
      name: json["name"]?.toString().trim() ?? "",
      fields: json["field_definitions"] is List ? (json["field_definitions"] as List).whereType<Map>().map((row) => DocumentFieldDefinition.fromJson(Map<String, dynamic>.from(row))).toList() : const [],
      extensions: rules["extensions"] is List ? (rules["extensions"] as List).map((value) => value.toString().toLowerCase()).toList() : const [],
      sources: rules["sources"] is List ? (rules["sources"] as List).map((value) => value.toString().toLowerCase()).toList() : const [],
    );
  }
}
