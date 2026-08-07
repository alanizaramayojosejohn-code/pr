import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_manifest.dart';
import 'update_service.dart';

class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key, required this.manifest});
  final UpdateManifest manifest;

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  double? _progress;
  bool _downloading = false;
  String? _error;

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      await ref.read(updateServiceProvider.notifier).downloadAndInstall(
            widget.manifest,
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
    return AlertDialog(
      title: Text('Nueva versión ${widget.manifest.latestVersion}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.manifest.releaseNotesEs.isNotEmpty)
            Text(widget.manifest.releaseNotesEs,
                style: const TextStyle(fontSize: 13)),
          if (_downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 4),
            Text(
              _progress != null
                  ? '${(_progress! * 100).toInt()}%'
                  : 'Descargando…',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 8),
          const Text(
            'Android te pedirá permitir la instalación — pulsa Configuración → Permitir.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      actions: _downloading
          ? null
          : [
              TextButton(
                onPressed: () async {
                  await ref
                      .read(updateServiceProvider.notifier)
                      .dismissSuggested(widget.manifest.latestBuild);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Más tarde'),
              ),
              FilledButton(
                onPressed: _download,
                child: const Text('Actualizar'),
              ),
            ],
    );
  }
}
