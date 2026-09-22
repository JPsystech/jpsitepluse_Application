import 'package:equatable/equatable.dart';

class CandidateResumePresignModel extends Equatable {
  final String uploadUrl;
  final String key;
  final String? downloadUrl;
  final Map<String, String> requiredHeaders;
  final int expiresIn;

  const CandidateResumePresignModel({
    required this.uploadUrl,
    required this.key,
    this.downloadUrl,
    this.requiredHeaders = const {},
    this.expiresIn = 900,
  });

  factory CandidateResumePresignModel.fromJson(Map<String, dynamic> json) {
    final rawHeaders = json['required_headers'];
    Map<String, String> headers = {};
    if (rawHeaders is Map) {
      headers = rawHeaders.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return CandidateResumePresignModel(
      uploadUrl: json['upload_url']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      downloadUrl: json['download_url']?.toString(),
      requiredHeaders: headers,
      expiresIn: json['expires_in'] is int ? json['expires_in'] as int : 900,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'upload_url': uploadUrl,
      'key': key,
      'download_url': downloadUrl,
      'required_headers': requiredHeaders,
      'expires_in': expiresIn,
    };
  }

  @override
  List<Object?> get props => [
        uploadUrl,
        key,
        downloadUrl,
        requiredHeaders,
        expiresIn,
      ];
}
