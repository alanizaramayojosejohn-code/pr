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
  MeasurementFieldDef(key: 'weight_kg',    label: 'Peso',         unit: 'kg'),
  MeasurementFieldDef(key: 'body_fat_pct', label: 'Grasa corp.',  unit: '%'),
  MeasurementFieldDef(key: 'neck_cm',      label: 'Cuello',       unit: 'cm'),
  MeasurementFieldDef(key: 'shoulder_cm',  label: 'Hombros',      unit: 'cm'),
  MeasurementFieldDef(key: 'chest_cm',     label: 'Pecho',        unit: 'cm'),
  MeasurementFieldDef(key: 'waist_cm',     label: 'Cintura',      unit: 'cm'),
  MeasurementFieldDef(key: 'hip_cm',       label: 'Cadera',       unit: 'cm'),
  MeasurementFieldDef(key: 'arm_cm',       label: 'Brazo',        unit: 'cm'),
  MeasurementFieldDef(key: 'forearm_cm',   label: 'Antebrazo',    unit: 'cm'),
  MeasurementFieldDef(key: 'thigh_cm',     label: 'Muslo',        unit: 'cm'),
  MeasurementFieldDef(key: 'calf_cm',      label: 'Pantorrilla',  unit: 'cm'),
];

class BodyMeasurement {
  const BodyMeasurement({
    required this.id,
    required this.measuredAt,
    this.weightKg,
    this.bodyFatPct,
    this.neckCm,
    this.shoulderCm,
    this.waistCm,
    this.chestCm,
    this.hipCm,
    this.armCm,
    this.forearmCm,
    this.thighCm,
    this.calfCm,
    this.notes,
  });

  final String id;
  final String measuredAt;
  final double? weightKg;
  final double? bodyFatPct;
  final double? neckCm;
  final double? shoulderCm;
  final double? waistCm;
  final double? chestCm;
  final double? hipCm;
  final double? armCm;
  final double? forearmCm;
  final double? thighCm;
  final double? calfCm;
  final String? notes;

  double? fieldValue(String key) => switch (key) {
        'weight_kg'    => weightKg,
        'body_fat_pct' => bodyFatPct,
        'neck_cm'      => neckCm,
        'shoulder_cm'  => shoulderCm,
        'waist_cm'     => waistCm,
        'chest_cm'     => chestCm,
        'hip_cm'       => hipCm,
        'arm_cm'       => armCm,
        'forearm_cm'   => forearmCm,
        'thigh_cm'     => thighCm,
        'calf_cm'      => calfCm,
        _              => null,
      };

  factory BodyMeasurement.fromJson(Map<String, dynamic> j) => BodyMeasurement(
        id:          j['id'] as String,
        measuredAt:  j['measured_at'] as String,
        weightKg:    _toDouble(j['weight_kg']),
        bodyFatPct:  _toDouble(j['body_fat_pct']),
        neckCm:      _toDouble(j['neck_cm']),
        shoulderCm:  _toDouble(j['shoulder_cm']),
        waistCm:     _toDouble(j['waist_cm']),
        chestCm:     _toDouble(j['chest_cm']),
        hipCm:       _toDouble(j['hip_cm']),
        armCm:       _toDouble(j['arm_cm']),
        forearmCm:   _toDouble(j['forearm_cm']),
        thighCm:     _toDouble(j['thigh_cm']),
        calfCm:      _toDouble(j['calf_cm']),
        notes:       j['notes'] as String?,
      );
}

double? _toDouble(dynamic v) => v == null ? null : (v as num).toDouble();

class MeasurementsRepository {
  Future<List<BodyMeasurement>> fetchAll() async {
    // Un instructor tiene permiso de lectura sobre las mediciones de sus
    // alumnos: sin filtrar por user_id vería las de ellos junto a las suyas.
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final res = await supabase
        .from('body_measurements')
        .select()
        .eq('user_id', userId)
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
