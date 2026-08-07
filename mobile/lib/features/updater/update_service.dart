import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_manifest.dart';

const _manifestUrl = 'https://pr-app-efa2f.web.app/app-version.json';

enum UpdateStatus { none, suggested, forced }

class UpdateResult {
  const UpdateResult(this.status, [this.manifest]);
  final UpdateStatus status;
  final UpdateManifest? manifest;
}

final updateServiceProvider =
    AsyncNotifierProvider<UpdateService, UpdateResult>(UpdateService.new);

class UpdateService extends AsyncNotifier<UpdateResult> {
  @override
  Future<UpdateResult> build() async => const UpdateResult(UpdateStatus.none);

  Future<void> checkForUpdate() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 1;

      final response = await http
          .get(Uri.parse(_manifestUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return const UpdateResult(UpdateStatus.none);
      }

      final manifest =
          UpdateManifest.fromJson(jsonDecode(response.body) as Map<String, dynamic>);

      if (currentBuild < manifest.minSupportedBuild) {
        return UpdateResult(UpdateStatus.forced, manifest);
      }

      if (currentBuild < manifest.latestBuild) {
        final prefs = await SharedPreferences.getInstance();
        final key = 'update_dismissed_for_build_${manifest.latestBuild}';
        final dismissedAt = prefs.getInt(key);
        if (dismissedAt != null) {
          final elapsed = DateTime.now().millisecondsSinceEpoch - dismissedAt;
          if (elapsed < const Duration(hours: 24).inMilliseconds) {
            return const UpdateResult(UpdateStatus.none);
          }
        }
        return UpdateResult(UpdateStatus.suggested, manifest);
      }

      return const UpdateResult(UpdateStatus.none);
    });
  }

  Future<void> dismissSuggested(int latestBuild) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'update_dismissed_for_build_$latestBuild',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> downloadAndInstall(
    UpdateManifest manifest, {
    void Function(double)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final apkPath = '${dir.path}/pr-update.apk';
    final file = File(apkPath);

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(manifest.apkUrl));
      final response = await client.send(request);
      final totalBytes = response.contentLength ?? 0;
      var received = 0;

      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0) onProgress?.call(received / totalBytes);
      }
      await sink.close();

      if (manifest.sha256.isNotEmpty) {
        final bytes = await file.readAsBytes();
        final digest = sha256.convert(bytes).toString();
        if (digest != manifest.sha256) {
          await file.delete();
          throw Exception('APK corrupto: sha256 no coincide');
        }
      }

      await OpenFilex.open(apkPath, type: 'application/vnd.android.package-archive');
    } finally {
      client.close();
    }
  }
}
