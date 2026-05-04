import 'package:freezed_annotation/freezed_annotation.dart';

part 'medical_record.freezed.dart';
part 'medical_record.g.dart';

List<String> _stringListFromJson(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  if (value is String && value.isNotEmpty) {
    return <String>[value];
  }
  return const <String>[];
}

@freezed
abstract class MedicalRecord with _$MedicalRecord {
  const factory MedicalRecord({
    required int id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'record_for') required String recordFor,
    @JsonKey(name: 'record_type') required String recordType,
    @JsonKey(name: 'record_date') required DateTime recordDate,
    @JsonKey(name: 'file_urls', fromJson: _stringListFromJson)
    @Default(<String>[])
    List<String> fileUrls,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'deleted_at') DateTime? deletedAt,
    @JsonKey(name: 'locked_until') DateTime? lockedUntil,
  }) = _MedicalRecord;

  factory MedicalRecord.fromJson(Map<String, dynamic> json) =>
      _$MedicalRecordFromJson(json);
}
