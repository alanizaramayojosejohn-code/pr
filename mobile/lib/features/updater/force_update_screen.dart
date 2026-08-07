import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_manifest.dart';
import 'update_service.dart';

class ForceUpdateScreen extends ConsumerStatefulWidget {
  const ForceUpdateScreen({super.key});

  @override
  ConsumerState<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends ConsumerState<ForceUpdateScreen> {
  double? _progress;
  bool _downloading = false;
  String? _error;

  Future<void> _download(UpdateManifest manifest) async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      await ref.read(updateServiceProvider.notifier).downloadAndInstall(
            manifest,
            onProgress: (p) => setState(() => _progress = p),
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al descargar. Verifica tu conexión e intenta de nuevo.';
        _downloading = false;
        _progress = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(updateServiceProvider).asData?.value;
    final manifest = result?.manifest;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: manifest == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.system_update_rounded,
                            size: 72, color: Colors.blue),
                        const SizedBox(height: 24),
                        const Text(
                          'Actualización requerida',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Esta versión ya no es compatible.\nDescarga la versión ${manifest.latestVersion} para continuar.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.grey),
                        ),
                        if (manifest.releaseNotesEs.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(manifest.releaseNotesEs,
                              style: const TextStyle(fontSize: 13),
                              textAlign: TextAlign.center),
                        ],
                        const SizedBox(height: 32),
                        if (_downloading) ...[
                          LinearProgressIndicator(value: _progress),
                          const SizedBox(height: 8),
                          Text(
                            _progress != null
                                ? '${(_progress! * 100).toInt()}%'
                                : 'Descargando…',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ] else ...[
                          FilledButton.icon(
                            onPressed: () => _download(manifest),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Descargar actualización'),
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48)),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(_error!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 13),
                                textAlign: TextAlign.center),
                          ],
                          const SizedBox(height: 12),
                          const Text(
                            'Android te pedirá permitir la instalación — pulsa Configuración → Permitir.',
                            style:
                                TextStyle(fontSize: 11, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
