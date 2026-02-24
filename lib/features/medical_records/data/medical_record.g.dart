// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medical_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MedicalRecord _$MedicalRecordFromJson(Map<String, dynamic> json) =>
    _MedicalRecord(
      id: (json['id'] as num).toInt(),
      userId: json['user_id'] as String,
      recordFor: json['record_for'] as String,
      recordType: json['record_type'] as String,
      recordDate: DateTime.parse(json['record_date'] as String),
      fileUrls:
          json['file_urls'] == null
              ? const <String>[]
              : _stringListFromJson(json['file_urls']),
      createdAt: DateTime.parse(json['created_at'] as String),
      deletedAt:
          json['deleted_at'] == null
              ? null
              : DateTime.parse(json['deleted_at'] as String),
    );

Map<String, dynamic> _$MedicalRecordToJson(_MedicalRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'record_for': instance.recordFor,
      'record_type': instance.recordType,
      'record_date': instance.recordDate.toIso8601String(),
      'file_urls': instance.fileUrls,
      'created_at': instance.createdAt.toIso8601String(),
      'deleted_at': instance.deletedAt?.toIso8601String(),
    };
