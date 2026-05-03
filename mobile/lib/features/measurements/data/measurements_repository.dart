import '../../../supabase/client.dart';

class MeasurementFieldDef {
  const MeasurementFieldDef({
    required this.key,
    required this.label,
    required this.unit,
  });
  final String key;
  final String label;
  final String unit;
}

const kMeasurementFields = [
  MeasurementFieldDef(key: 'weight_kg', label: 'Peso', unit: 'kg'),
  MeasurementFieldDef(key: 'body_fat_pct', label: 'Grasa corporal', unit: '%'),
  MeasurementFieldDef(key: 'waist_cm', label: 'Cintura', unit: 'cm'),
  MeasurementFieldDef(key: 'chest_cm', label: 'Pecho', unit: 'cm'),
  MeasurementFieldDef(key: 'arm_cm', label: 'Brazo', unit: 'cm'),
  MeasurementFieldDef(key: 'thigh_cm', label: 'Muslo', unit: 'cm'),
];

class BodyMeasurement {
  const BodyMeasurement({
    required this.id,
    required this.measuredAt,
    this.weightKg,
    this.bodyFatPct,
    this.waistCm,
    this.chestCm,
    this.armCm,
    this.thighCm,
    this.notes,
  });

  final String id;
  final String measuredAt;
  final double? weightKg;
  final double? bodyFatPct;
  final double? waistCm;
  final double? chestCm;
  final double? armCm;
  final double? thighCm;
  final String? notes;

  double? fieldValue(String key) => switch (key) {
        'weight_kg' => weightKg,
        'body_fat_pct' => bodyFatPct,
        'waist_cm' => waistCm,
        'chest_cm' => chestCm,
        'arm_cm' => armCm,
        'thigh_cm' => thighCm,
        _ => null,
      };

  factory BodyMeasurement.fromJson(Map<String, dynamic> j) => BodyMeasurement(
        id: j['id'] as String,
        measuredAt: j['measured_at'] as String,
        weightKg: _toDouble(j['weight_kg']),
        bodyFatPct: _toDouble(j['body_fat_pct']),
        waistCm: _toDouble(j['waist_cm']),
        chestCm: _toDouble(j['chest_cm']),
        armCm: _toDouble(j['arm_cm']),
        thighCm: _toDouble(j['thigh_cm']),
        notes: j['notes'] as String?,
      );
}

double? _toDouble(dynamic v) => v == null ? null : (v as num).toDouble();

class MeasurementsRepository {
  Future<List<BodyMeasurement>> fetchAll() async {
    final res = await supabase
        .from('body_measurements')
        .select()
        .order('measured_at', ascending: false)
        .order('created_at', ascending: false);
    return (res as List)
        .whereType<Map<String, dynamic>>()
        .map(BodyMeasurement.fromJson)
        .toList();
  }

  Future<BodyMeasurement> create(Map<String, dynamic> payload) async {
    final res = await supabase
        .from('body_measurements')
        .insert({...payload, 'user_id': supabase.auth.currentUser!.id})
        .select()
        .single();
    return BodyMeasurement.fromJson(res);
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    await supabase.from('body_measurements').update(patch).eq('id', id);
  }

  Future<void> delete(String id) async {
    await supabase.from('body_measurements').delete().eq('id', id);
  }
}
