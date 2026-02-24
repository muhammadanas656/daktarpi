// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clinic.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Clinic _$ClinicFromJson(Map<String, dynamic> json) => _Clinic(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String? ?? 'Unknown Clinic',
  address: json['address'] as String? ?? 'Unknown Address',
);

Map<String, dynamic> _$ClinicToJson(_Clinic instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'address': instance.address,
};
