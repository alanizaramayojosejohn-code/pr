import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/measurements_repository.dart';

class MeasurementsNotifier
    extends AsyncNotifier<List<BodyMeasurement>> {
  final _repo = MeasurementsRepository();

  @override
  Future<List<BodyMeasurement>> build() => _repo.fetchAll();

  Future<bool> create(Map<String, dynamic> payload) async {
    try {
      await _repo.create(payload);
      ref.invalidateSelf();
      await future;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> patch(String id, Map<String, dynamic> changes) async {
    await _repo.update(id, changes);
    ref.invalidateSelf();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    ref.invalidateSelf();
  }
}

final measurementsProvider =
    AsyncNotifierProvider<MeasurementsNotifier, List<BodyMeasurement>>(
  MeasurementsNotifier.new,
);
