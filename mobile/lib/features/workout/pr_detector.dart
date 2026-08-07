enum PRType { oneRm, sessionVolume, absoluteWeight, repsAtWeight }

class ExerciseBests {
  const ExerciseBests({
    this.maxWeight,
    this.maxOneRm,
    this.maxSessionVolume,
    this.repsByWeight = const {},
  });
  final double? maxWeight;
  final double? maxOneRm;
  final double? maxSessionVolume;
  // weight → max reps historically achieved at that exact load
  final Map<double, int> repsByWeight;
}

class PRHit {
  const PRHit({required this.type, required this.newValue, this.prevValue});
  final PRType type;
  final double newValue;
  final double? prevValue;
}

class PendingPR {
  const PendingPR({
    required this.exerciseId,
    required this.exerciseName,
    required this.hits,
  });
  final int exerciseId;
  final String exerciseName;
  final List<PRHit> hits;
}

abstract final class PRDetector {
  // Average of Epley and Brzycki; reps clamped to 36 (Brzycki undefined at 37+).
  static double estimateOneRm(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0;
    if (reps == 1) return weight;
    final r = reps.clamp(1, 36);
    final epley = weight * (1 + r / 30);
    final brzycki = weight * 36 / (37 - r);
    return (epley + brzycki) / 2;
  }

  static List<PRHit> check({
    required double weight,
    required int reps,
    required ExerciseBests bests,
    required double sessionVolumeBeforeSet,
  }) {
    if (weight <= 0 || reps <= 0) return const [];
    final hits = <PRHit>[];

    // 1. 1RM estimado (Epley / Brzycki)
    final oneRm = estimateOneRm(weight, reps);
    if (bests.maxOneRm == null || oneRm > bests.maxOneRm!) {
      hits.add(PRHit(type: PRType.oneRm, newValue: oneRm, prevValue: bests.maxOneRm));
    }

    // 2. Volumen total de sesión (sets × reps × peso acumulado)
    final newVol = sessionVolumeBeforeSet + weight * reps;
    if (bests.maxSessionVolume == null || newVol > bests.maxSessionVolume!) {
      hits.add(PRHit(type: PRType.sessionVolume, newValue: newVol, prevValue: bests.maxSessionVolume));
    }

    // 3. Peso absoluto
    if (bests.maxWeight == null || weight > bests.maxWeight!) {
      hits.add(PRHit(type: PRType.absoluteWeight, newValue: weight, prevValue: bests.maxWeight));
    }

    // 4. Reps al mismo peso
    final prevReps = bests.repsByWeight[weight];
    if (prevReps == null || reps > prevReps) {
      hits.add(PRHit(
        type: PRType.repsAtWeight,
        newValue: reps.toDouble(),
        prevValue: prevReps?.toDouble(),
      ));
    }

    return hits;
  }
}
