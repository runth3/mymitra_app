class VersionResponse {
  final String minVersion;
  final String updateUrl;
  final bool maintenance;

  VersionResponse({
    required this.minVersion,
    required this.updateUrl,
    required this.maintenance,
  });

  factory VersionResponse.fromJson(Map<String, dynamic> json) {
    return VersionResponse(
      minVersion: json['min_version'],
      updateUrl: json['update_url'],
      maintenance: json['maintenance'],
    );
  }
}