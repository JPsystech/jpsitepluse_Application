import "dart:convert";
import "dart:io";
import "dart:math";
import "dart:typed_data";
import "dart:ui" as ui;

import "package:flutter/widgets.dart";
import "package:http/http.dart" as http;

import "package:sitepulse_engineer/core/utils/ist_time.dart";
import "package:sitepulse_engineer/core/services/api_client.dart";

class SitePhotoService {
  final ApiClient api;

  SitePhotoService({ApiClient? api}) : api = api ?? ApiClient();

  Future<Uint8List> _stampToPng({
    required Uint8List originalBytes,
    required String line1,
    required String line2,
    required String line3,
    String? line4,
  }) async {
    final codec = await ui.instantiateImageCodec(
      originalBytes,
      targetWidth: 1280,
      targetHeight: 1280,
    );
    final frame = await codec.getNextFrame();
    final src = frame.image;

    final w = src.width.toDouble();
    final h = src.height.toDouble();
    final pad = max(12.0, min(w, h) * 0.02);
    final fontSize = max(16.0, w * 0.035);
    final fontSmall = max(14.0, fontSize * 0.85);
    final lines = <({String text, double size})>[
      (text: line1, size: fontSize),
      (text: line2, size: fontSmall),
      (text: line3, size: fontSmall),
      if (line4 != null && line4.trim().isNotEmpty)
        (text: line4.trim(), size: fontSmall),
    ];

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    canvas.drawImage(src, Offset.zero, Paint());

    final maxTextWidth = w * 0.86;
    final painters = <TextPainter>[];
    for (final l in lines) {
      final tp = TextPainter(
        text: TextSpan(
          text: l.text,
          style: TextStyle(
            color: const Color(0xFFFFFFFF),
            fontSize: l.size,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: "…",
      );
      tp.layout(maxWidth: maxTextWidth);
      painters.add(tp);
    }

    var widest = 0.0;
    for (final tp in painters) {
      if (tp.width > widest) widest = tp.width;
    }

    final ascent = fontSize;
    final lineGap = max(6.0, ascent * 0.35);
    var boxH = pad * 2;
    for (final tp in painters) {
      boxH += tp.height;
    }
    boxH += lineGap * max(0, painters.length - 1);

    final boxW = min(w * 0.92, widest + pad * 2);
    final x0 = pad;
    final y0 = h - boxH - pad;
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x0, y0, boxW, boxH), Radius.circular(pad * 0.75));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xA0000000));

    var y = y0 + pad;
    for (final tp in painters) {
      tp.paint(canvas, Offset(x0 + pad, y));
      y += tp.height + lineGap;
    }

    final picture = recorder.endRecording();
    final out = await picture.toImage(src.width, src.height);
    final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<String> uploadProgressPhoto({
    required String token,
    required File file,
    required double lat,
    required double lng,
    required String addressText,
    required String projectName,
    required String siteName,
    required String empCode,
    DateTime? capturedAt,
  }) async {
    final when = capturedAt ?? DateTime.now();
    final dateStr = IstTime.formatDate(when);
    final ist = IstTime.toIst(when);
    final timeStr =
        "${ist.hour.toString().padLeft(2, "0")}:${ist.minute.toString().padLeft(2, "0")}:${ist.second.toString().padLeft(2, "0")}";

    final originalBytes = await file.readAsBytes();
    final stampedBytes = await _stampToPng(
      originalBytes: originalBytes,
      line1: "${projectName.trim()} | ${siteName.trim()}",
      line2: "Date: $dateStr    Time: $timeStr",
      line3: "Lat: ${lat.toStringAsFixed(6)}    Lng: ${lng.toStringAsFixed(6)}",
      line4: "Emp: ${empCode.trim().isEmpty ? "-" : empCode.trim()}",
    );

    const contentType = "image/png";
    const fileExtension = ".png";
    final sizeBytes = stampedBytes.length;

    final presignUri = await api.url("/api/v1/engineer/site-photos/presign");
    final presignJson = await api.postJson(
      presignUri,
      headers: {
        HttpHeaders.authorizationHeader: "Bearer $token",
        HttpHeaders.contentTypeHeader: "application/json",
      },
      body: jsonEncode({
        "photo_type": "progress",
        "latitude": lat,
        "longitude": lng,
        "address_text": addressText,
        "captured_at": when.toUtc().toIso8601String(),
        "content_type": contentType,
        "file_extension": fileExtension,
        "size_bytes": sizeBytes,
      }),
    );

    final uploadUrl = presignJson?["upload_url"];
    final uploadUrlAlt = presignJson?["upload_url_alt"];
    final key = presignJson?["key"];
    final publicUrl = presignJson?["public_url"];
    final requiredHeaders = presignJson?["required_headers"];
    final projectId = presignJson?["project_id"];
    final attendanceLogId = presignJson?["attendance_log_id"];

    if (uploadUrl is! String || uploadUrl.trim().isEmpty) {
      throw ApiException("Presign failed: upload_url missing");
    }
    if (key is! String || key.trim().isEmpty) {
      throw ApiException("Presign failed: key missing");
    }
    if (publicUrl is! String || publicUrl.trim().isEmpty) {
      throw ApiException("Presign failed: public_url missing");
    }

    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: contentType
    };
    if (requiredHeaders is Map) {
      for (final entry in requiredHeaders.entries) {
        final k = entry.key;
        final v = entry.value;
        if (k is String && v is String) {
          headers[k] = v;
        }
      }
    }

    try {
      final primary = Uri.parse(uploadUrl.trim());
      http.Response resp;
      try {
        resp =
            await api.client.put(primary, headers: headers, body: stampedBytes);
      } on HandshakeException {
        final alt = (uploadUrlAlt is String) ? uploadUrlAlt.trim() : "";
        if (alt.isEmpty) {
          rethrow;
        }
        resp = await api.client
            .put(Uri.parse(alt), headers: headers, body: stampedBytes);
      }

      if (resp.statusCode != 200 &&
          resp.statusCode != 201 &&
          resp.statusCode != 204) {
        throw ApiException(
            "Upload failed (status ${resp.statusCode}): ${resp.body}");
      }
    } on HandshakeException catch (e) {
      final primaryHost = Uri.tryParse(uploadUrl.trim())?.host ?? "";
      final altHost = (uploadUrlAlt is String)
          ? (Uri.tryParse(uploadUrlAlt.trim())?.host ?? "")
          : "";
      final targets = <String>[
        if (primaryHost.isNotEmpty) primaryHost,
        if (altHost.isNotEmpty && altHost != primaryHost) altHost,
      ];
      final suffix = targets.isEmpty ? "" : " (hosts: ${targets.join(", ")})";
      throw ApiException("Upload failed (TLS)$suffix: $e");
    } on SocketException catch (e) {
      throw ApiException("Upload failed (network): $e");
    } on http.ClientException catch (e) {
      throw ApiException("Upload failed: $e");
    }

    final completeUri = await api.url("/api/v1/engineer/site-photos/complete");
    final completeJson = await api.postJson(
      completeUri,
      headers: {
        HttpHeaders.authorizationHeader: "Bearer $token",
        HttpHeaders.contentTypeHeader: "application/json",
      },
      body: jsonEncode({
        "photo_type": "progress",
        "latitude": lat,
        "longitude": lng,
        "address_text": addressText,
        "captured_at": when.toUtc().toIso8601String(),
        if (projectId is String) "project_id": projectId,
        if (attendanceLogId is String) "attendance_log_id": attendanceLogId,
        "key": key,
        "file_url": publicUrl,
        "content_type": contentType,
        "size_bytes": sizeBytes,
      }),
    );

    final url = completeJson?["file_url"];
    if (url is! String || url.trim().isEmpty) {
      throw ApiException("Save failed: file_url missing");
    }
    return url.trim();
  }
}
