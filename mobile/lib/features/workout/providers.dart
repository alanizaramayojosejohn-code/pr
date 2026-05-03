import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'workout_notifier.dart';
import 'workout_state.dart';

final workoutProvider =
    NotifierProvider<WorkoutNotifier, WorkoutState>(WorkoutNotifier.new);
