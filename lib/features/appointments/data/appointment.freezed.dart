// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'appointment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Appointment {

 int get id;@JsonKey(name: 'schedule_date') String get scheduleDate;@JsonKey(name: 'start_time') String get startTime;@JsonKey(name: 'end_time') String get endTime; String get status;@JsonKey(name: 'patient_name') String get patientName;@JsonKey(name: 'patient_phone') String get patientPhone;@JsonKey(name: 'patient_email') String get patientEmail;@JsonKey(name: 'patient_gender') String get patientGender;@JsonKey(name: 'patient_dob') String get patientDob;@JsonKey(name: 'doctors') Doctor? get doctor;@JsonKey(name: 'clinics') Clinic? get clinic;@JsonKey(name: 'deleted_at') DateTime? get deletedAt;@JsonKey(name: 'attached_record_ids') List<int> get attachedRecordIds;
/// Create a copy of Appointment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppointmentCopyWith<Appointment> get copyWith => _$AppointmentCopyWithImpl<Appointment>(this as Appointment, _$identity);

  /// Serializes this Appointment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Appointment&&(identical(other.id, id) || other.id == id)&&(identical(other.scheduleDate, scheduleDate) || other.scheduleDate == scheduleDate)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.status, status) || other.status == status)&&(identical(other.patientName, patientName) || other.patientName == patientName)&&(identical(other.patientPhone, patientPhone) || other.patientPhone == patientPhone)&&(identical(other.patientEmail, patientEmail) || other.patientEmail == patientEmail)&&(identical(other.patientGender, patientGender) || other.patientGender == patientGender)&&(identical(other.patientDob, patientDob) || other.patientDob == patientDob)&&(identical(other.doctor, doctor) || other.doctor == doctor)&&(identical(other.clinic, clinic) || other.clinic == clinic)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&const DeepCollectionEquality().equals(other.attachedRecordIds, attachedRecordIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,scheduleDate,startTime,endTime,status,patientName,patientPhone,patientEmail,patientGender,patientDob,doctor,clinic,deletedAt,const DeepCollectionEquality().hash(attachedRecordIds));

@override
String toString() {
  return 'Appointment(id: $id, scheduleDate: $scheduleDate, startTime: $startTime, endTime: $endTime, status: $status, patientName: $patientName, patientPhone: $patientPhone, patientEmail: $patientEmail, patientGender: $patientGender, patientDob: $patientDob, doctor: $doctor, clinic: $clinic, deletedAt: $deletedAt, attachedRecordIds: $attachedRecordIds)';
}


}

/// @nodoc
abstract mixin class $AppointmentCopyWith<$Res>  {
  factory $AppointmentCopyWith(Appointment value, $Res Function(Appointment) _then) = _$AppointmentCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'schedule_date') String scheduleDate,@JsonKey(name: 'start_time') String startTime,@JsonKey(name: 'end_time') String endTime, String status,@JsonKey(name: 'patient_name') String patientName,@JsonKey(name: 'patient_phone') String patientPhone,@JsonKey(name: 'patient_email') String patientEmail,@JsonKey(name: 'patient_gender') String patientGender,@JsonKey(name: 'patient_dob') String patientDob,@JsonKey(name: 'doctors') Doctor? doctor,@JsonKey(name: 'clinics') Clinic? clinic,@JsonKey(name: 'deleted_at') DateTime? deletedAt,@JsonKey(name: 'attached_record_ids') List<int> attachedRecordIds
});


$DoctorCopyWith<$Res>? get doctor;$ClinicCopyWith<$Res>? get clinic;

}
/// @nodoc
class _$AppointmentCopyWithImpl<$Res>
    implements $AppointmentCopyWith<$Res> {
  _$AppointmentCopyWithImpl(this._self, this._then);

  final Appointment _self;
  final $Res Function(Appointment) _then;

/// Create a copy of Appointment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? scheduleDate = null,Object? startTime = null,Object? endTime = null,Object? status = null,Object? patientName = null,Object? patientPhone = null,Object? patientEmail = null,Object? patientGender = null,Object? patientDob = null,Object? doctor = freezed,Object? clinic = freezed,Object? deletedAt = freezed,Object? attachedRecordIds = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,scheduleDate: null == scheduleDate ? _self.scheduleDate : scheduleDate // ignore: cast_nullable_to_non_nullable
as String,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,patientName: null == patientName ? _self.patientName : patientName // ignore: cast_nullable_to_non_nullable
as String,patientPhone: null == patientPhone ? _self.patientPhone : patientPhone // ignore: cast_nullable_to_non_nullable
as String,patientEmail: null == patientEmail ? _self.patientEmail : patientEmail // ignore: cast_nullable_to_non_nullable
as String,patientGender: null == patientGender ? _self.patientGender : patientGender // ignore: cast_nullable_to_non_nullable
as String,patientDob: null == patientDob ? _self.patientDob : patientDob // ignore: cast_nullable_to_non_nullable
as String,doctor: freezed == doctor ? _self.doctor : doctor // ignore: cast_nullable_to_non_nullable
as Doctor?,clinic: freezed == clinic ? _self.clinic : clinic // ignore: cast_nullable_to_non_nullable
as Clinic?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,attachedRecordIds: null == attachedRecordIds ? _self.attachedRecordIds : attachedRecordIds // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}
/// Create a copy of Appointment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DoctorCopyWith<$Res>? get doctor {
    if (_self.doctor == null) {
    return null;
  }

  return $DoctorCopyWith<$Res>(_self.doctor!, (value) {
    return _then(_self.copyWith(doctor: value));
  });
}/// Create a copy of Appointment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClinicCopyWith<$Res>? get clinic {
    if (_self.clinic == null) {
    return null;
  }

  return $ClinicCopyWith<$Res>(_self.clinic!, (value) {
    return _then(_self.copyWith(clinic: value));
  });
}
}


/// Adds pattern-matching-related methods to [Appointment].
extension AppointmentPatterns on Appointment {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Appointment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Appointment() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Appointment value)  $default,){
final _that = this;
switch (_that) {
case _Appointment():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Appointment value)?  $default,){
final _that = this;
switch (_that) {
case _Appointment() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'schedule_date')  String scheduleDate, @JsonKey(name: 'start_time')  String startTime, @JsonKey(name: 'end_time')  String endTime,  String status, @JsonKey(name: 'patient_name')  String patientName, @JsonKey(name: 'patient_phone')  String patientPhone, @JsonKey(name: 'patient_email')  String patientEmail, @JsonKey(name: 'patient_gender')  String patientGender, @JsonKey(name: 'patient_dob')  String patientDob, @JsonKey(name: 'doctors')  Doctor? doctor, @JsonKey(name: 'clinics')  Clinic? clinic, @JsonKey(name: 'deleted_at')  DateTime? deletedAt, @JsonKey(name: 'attached_record_ids')  List<int> attachedRecordIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Appointment() when $default != null:
return $default(_that.id,_that.scheduleDate,_that.startTime,_that.endTime,_that.status,_that.patientName,_that.patientPhone,_that.patientEmail,_that.patientGender,_that.patientDob,_that.doctor,_that.clinic,_that.deletedAt,_that.attachedRecordIds);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'schedule_date')  String scheduleDate, @JsonKey(name: 'start_time')  String startTime, @JsonKey(name: 'end_time')  String endTime,  String status, @JsonKey(name: 'patient_name')  String patientName, @JsonKey(name: 'patient_phone')  String patientPhone, @JsonKey(name: 'patient_email')  String patientEmail, @JsonKey(name: 'patient_gender')  String patientGender, @JsonKey(name: 'patient_dob')  String patientDob, @JsonKey(name: 'doctors')  Doctor? doctor, @JsonKey(name: 'clinics')  Clinic? clinic, @JsonKey(name: 'deleted_at')  DateTime? deletedAt, @JsonKey(name: 'attached_record_ids')  List<int> attachedRecordIds)  $default,) {final _that = this;
switch (_that) {
case _Appointment():
return $default(_that.id,_that.scheduleDate,_that.startTime,_that.endTime,_that.status,_that.patientName,_that.patientPhone,_that.patientEmail,_that.patientGender,_that.patientDob,_that.doctor,_that.clinic,_that.deletedAt,_that.attachedRecordIds);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'schedule_date')  String scheduleDate, @JsonKey(name: 'start_time')  String startTime, @JsonKey(name: 'end_time')  String endTime,  String status, @JsonKey(name: 'patient_name')  String patientName, @JsonKey(name: 'patient_phone')  String patientPhone, @JsonKey(name: 'patient_email')  String patientEmail, @JsonKey(name: 'patient_gender')  String patientGender, @JsonKey(name: 'patient_dob')  String patientDob, @JsonKey(name: 'doctors')  Doctor? doctor, @JsonKey(name: 'clinics')  Clinic? clinic, @JsonKey(name: 'deleted_at')  DateTime? deletedAt, @JsonKey(name: 'attached_record_ids')  List<int> attachedRecordIds)?  $default,) {final _that = this;
switch (_that) {
case _Appointment() when $default != null:
return $default(_that.id,_that.scheduleDate,_that.startTime,_that.endTime,_that.status,_that.patientName,_that.patientPhone,_that.patientEmail,_that.patientGender,_that.patientDob,_that.doctor,_that.clinic,_that.deletedAt,_that.attachedRecordIds);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _Appointment implements Appointment {
  const _Appointment({required this.id, @JsonKey(name: 'schedule_date') required this.scheduleDate, @JsonKey(name: 'start_time') required this.startTime, @JsonKey(name: 'end_time') required this.endTime, this.status = 'pending', @JsonKey(name: 'patient_name') this.patientName = '', @JsonKey(name: 'patient_phone') this.patientPhone = '', @JsonKey(name: 'patient_email') this.patientEmail = '', @JsonKey(name: 'patient_gender') this.patientGender = 'Male', @JsonKey(name: 'patient_dob') this.patientDob = '', @JsonKey(name: 'doctors') this.doctor, @JsonKey(name: 'clinics') this.clinic, @JsonKey(name: 'deleted_at') this.deletedAt, @JsonKey(name: 'attached_record_ids') final  List<int> attachedRecordIds = const []}): _attachedRecordIds = attachedRecordIds;
  factory _Appointment.fromJson(Map<String, dynamic> json) => _$AppointmentFromJson(json);

@override final  int id;
@override@JsonKey(name: 'schedule_date') final  String scheduleDate;
@override@JsonKey(name: 'start_time') final  String startTime;
@override@JsonKey(name: 'end_time') final  String endTime;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'patient_name') final  String patientName;
@override@JsonKey(name: 'patient_phone') final  String patientPhone;
@override@JsonKey(name: 'patient_email') final  String patientEmail;
@override@JsonKey(name: 'patient_gender') final  String patientGender;
@override@JsonKey(name: 'patient_dob') final  String patientDob;
@override@JsonKey(name: 'doctors') final  Doctor? doctor;
@override@JsonKey(name: 'clinics') final  Clinic? clinic;
@override@JsonKey(name: 'deleted_at') final  DateTime? deletedAt;
 final  List<int> _attachedRecordIds;
@override@JsonKey(name: 'attached_record_ids') List<int> get attachedRecordIds {
  if (_attachedRecordIds is EqualUnmodifiableListView) return _attachedRecordIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachedRecordIds);
}


/// Create a copy of Appointment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppointmentCopyWith<_Appointment> get copyWith => __$AppointmentCopyWithImpl<_Appointment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppointmentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Appointment&&(identical(other.id, id) || other.id == id)&&(identical(other.scheduleDate, scheduleDate) || other.scheduleDate == scheduleDate)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.status, status) || other.status == status)&&(identical(other.patientName, patientName) || other.patientName == patientName)&&(identical(other.patientPhone, patientPhone) || other.patientPhone == patientPhone)&&(identical(other.patientEmail, patientEmail) || other.patientEmail == patientEmail)&&(identical(other.patientGender, patientGender) || other.patientGender == patientGender)&&(identical(other.patientDob, patientDob) || other.patientDob == patientDob)&&(identical(other.doctor, doctor) || other.doctor == doctor)&&(identical(other.clinic, clinic) || other.clinic == clinic)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&const DeepCollectionEquality().equals(other._attachedRecordIds, _attachedRecordIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,scheduleDate,startTime,endTime,status,patientName,patientPhone,patientEmail,patientGender,patientDob,doctor,clinic,deletedAt,const DeepCollectionEquality().hash(_attachedRecordIds));

@override
String toString() {
  return 'Appointment(id: $id, scheduleDate: $scheduleDate, startTime: $startTime, endTime: $endTime, status: $status, patientName: $patientName, patientPhone: $patientPhone, patientEmail: $patientEmail, patientGender: $patientGender, patientDob: $patientDob, doctor: $doctor, clinic: $clinic, deletedAt: $deletedAt, attachedRecordIds: $attachedRecordIds)';
}


}

/// @nodoc
abstract mixin class _$AppointmentCopyWith<$Res> implements $AppointmentCopyWith<$Res> {
  factory _$AppointmentCopyWith(_Appointment value, $Res Function(_Appointment) _then) = __$AppointmentCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'schedule_date') String scheduleDate,@JsonKey(name: 'start_time') String startTime,@JsonKey(name: 'end_time') String endTime, String status,@JsonKey(name: 'patient_name') String patientName,@JsonKey(name: 'patient_phone') String patientPhone,@JsonKey(name: 'patient_email') String patientEmail,@JsonKey(name: 'patient_gender') String patientGender,@JsonKey(name: 'patient_dob') String patientDob,@JsonKey(name: 'doctors') Doctor? doctor,@JsonKey(name: 'clinics') Clinic? clinic,@JsonKey(name: 'deleted_at') DateTime? deletedAt,@JsonKey(name: 'attached_record_ids') List<int> attachedRecordIds
});


@override $DoctorCopyWith<$Res>? get doctor;@override $ClinicCopyWith<$Res>? get clinic;

}
/// @nodoc
class __$AppointmentCopyWithImpl<$Res>
    implements _$AppointmentCopyWith<$Res> {
  __$AppointmentCopyWithImpl(this._self, this._then);

  final _Appointment _self;
  final $Res Function(_Appointment) _then;

/// Create a copy of Appointment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? scheduleDate = null,Object? startTime = null,Object? endTime = null,Object? status = null,Object? patientName = null,Object? patientPhone = null,Object? patientEmail = null,Object? patientGender = null,Object? patientDob = null,Object? doctor = freezed,Object? clinic = freezed,Object? deletedAt = freezed,Object? attachedRecordIds = null,}) {
  return _then(_Appointment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,scheduleDate: null == scheduleDate ? _self.scheduleDate : scheduleDate // ignore: cast_nullable_to_non_nullable
as String,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,patientName: null == patientName ? _self.patientName : patientName // ignore: cast_nullable_to_non_nullable
as String,patientPhone: null == patientPhone ? _self.patientPhone : patientPhone // ignore: cast_nullable_to_non_nullable
as String,patientEmail: null == patientEmail ? _self.patientEmail : patientEmail // ignore: cast_nullable_to_non_nullable
as String,patientGender: null == patientGender ? _self.patientGender : patientGender // ignore: cast_nullable_to_non_nullable
as String,patientDob: null == patientDob ? _self.patientDob : patientDob // ignore: cast_nullable_to_non_nullable
as String,doctor: freezed == doctor ? _self.doctor : doctor // ignore: cast_nullable_to_non_nullable
as Doctor?,clinic: freezed == clinic ? _self.clinic : clinic // ignore: cast_nullable_to_non_nullable
as Clinic?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,attachedRecordIds: null == attachedRecordIds ? _self._attachedRecordIds : attachedRecordIds // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

/// Create a copy of Appointment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DoctorCopyWith<$Res>? get doctor {
    if (_self.doctor == null) {
    return null;
  }

  return $DoctorCopyWith<$Res>(_self.doctor!, (value) {
    return _then(_self.copyWith(doctor: value));
  });
}/// Create a copy of Appointment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClinicCopyWith<$Res>? get clinic {
    if (_self.clinic == null) {
    return null;
  }

  return $ClinicCopyWith<$Res>(_self.clinic!, (value) {
    return _then(_self.copyWith(clinic: value));
  });
}
}

// dart format on
