class UpdateManifest {
  const UpdateManifest({
    required this.latestVersion,
    required this.latestBuild,
    required this.minSupportedBuild,
    required this.apkUrl,
    required this.sha256,
    required this.releaseNotesEs,
  });

  final String latestVersion;
  final int latestBuild;
  final int minSupportedBuild;
  final String apkUrl;
  final String sha256;
  final String releaseNotesEs;

  factory UpdateManifest.fromJson(Map<String, dynamic> j) => UpdateManifest(
        latestVersion: j['latest_version'] as String,
        latestBuild: j['latest_build'] as int,
        minSupportedBuild: j['min_supported_build'] as int,
        apkUrl: j['apk_url'] as String,
        sha256: (j['sha256'] as String?) ?? '',
        releaseNotesEs: (j['release_notes_es'] as String?) ?? '',
      );
}
