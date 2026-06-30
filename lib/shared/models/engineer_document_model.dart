class EngineerDocumentListResponse {
  final List<EngineerDocument> items;

  EngineerDocumentListResponse({required this.items});

  factory EngineerDocumentListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json["items"];
    final items = raw is List ? raw.whereType<Map<String, dynamic>>().map(EngineerDocument.fromJson).toList() : <EngineerDocument>[];
    return EngineerDocumentListResponse(items: items);
  }

  static EngineerDocumentListResponse fromUnknown(dynamic json) {
    if (json is Map<String, dynamic>) {
      return EngineerDocumentListResponse.fromJson(json);
    }
    if (json is List) {
      final items = json.whereType<Map<String, dynamic>>().map(EngineerDocument.fromJson).toList();
      return EngineerDocumentListResponse(items: items);
    }
    return EngineerDocumentListResponse(items: const []);
  }
}

class EngineerDocument {
  final String id;
  final String engineerId;
  final String documentType;
  final String documentName;
  final String fileUrl;
  final String? originalFilename;
  final String contentType;
  final int sizeBytes;
  final String verificationStatus;
  final String? adminRemarks;
  final bool? isRequired;
  final String? requiredLabel;
  final DateTime uploadedAt;
  final DateTime updatedAt;

  EngineerDocument({
    required this.id,
    required this.engineerId,
    required this.documentType,
    required this.documentName,
    required this.fileUrl,
    required this.originalFilename,
    required this.contentType,
    required this.sizeBytes,
    required this.verificationStatus,
    required this.adminRemarks,
    required this.isRequired,
    required this.requiredLabel,
    required this.uploadedAt,
    required this.updatedAt,
  });

  factory EngineerDocument.fromJson(Map<String, dynamic> json) {
    return EngineerDocument(
      id: (json["id"] as String?) ?? "",
      engineerId: (json["engineer_id"] as String?) ?? "",
      documentType: (json["document_type"] as String?) ?? "",
      documentName: (json["document_name"] as String?) ?? "",
      fileUrl: (json["file_url"] as String?) ?? (json["url"] as String?) ?? "",
      originalFilename: json["original_filename"] as String?,
      contentType: (json["content_type"] as String?) ?? "application/octet-stream",
      sizeBytes: (json["size_bytes"] as num?)?.toInt() ?? 0,
      verificationStatus: (json["verification_status"] as String?) ?? (json["status"] as String?) ?? "",
      adminRemarks: json["admin_remarks"] as String?,
      isRequired: json["is_required"] as bool? ?? json["required"] as bool?,
      requiredLabel: json["required_label"] as String?,
      uploadedAt: DateTime.tryParse((json["uploaded_at"] as String?) ?? "") ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse((json["updated_at"] as String?) ?? "") ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String get normalizedType => documentType.trim().toLowerCase();

  String get effectiveFileName {
    final name = (originalFilename ?? "").trim();
    if (name.isNotEmpty) return name;
    final url = fileUrl.trim();
    if (url.isEmpty) return "";
    final beforeQuery = url.split("?").first;
    final last = beforeQuery.split("/").last;
    return last;
  }
}

class EngineerDocumentPresignResponse {
  final String uploadUrl;
  final String? uploadUrlAlt;
  final String key;
  final String publicUrl;
  final Map<String, String> requiredHeaders;
  final int expiresIn;

  EngineerDocumentPresignResponse({
    required this.uploadUrl,
    required this.uploadUrlAlt,
    required this.key,
    required this.publicUrl,
    required this.requiredHeaders,
    required this.expiresIn,
  });

  factory EngineerDocumentPresignResponse.fromJson(Map<String, dynamic> json) {
    final rh = <String, String>{};
    final rawHeaders = json["required_headers"];
    if (rawHeaders is Map) {
      for (final e in rawHeaders.entries) {
        final k = e.key;
        final v = e.value;
        if (k is String && v is String) {
          rh[k] = v;
        }
      }
    }
    return EngineerDocumentPresignResponse(
      uploadUrl: (json["upload_url"] as String?) ?? "",
      uploadUrlAlt: json["upload_url_alt"] as String?,
      key: (json["key"] as String?) ?? "",
      publicUrl: (json["public_url"] as String?) ?? "",
      requiredHeaders: rh,
      expiresIn: (json["expires_in"] as num?)?.toInt() ?? 0,
    );
  }
}
