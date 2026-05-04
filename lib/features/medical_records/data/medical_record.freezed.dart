// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'medical_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MedicalRecord {

 int get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'record_for') String get recordFor;@JsonKey(name: 'record_type') String get recordType;@JsonKey(name: 'record_date') DateTime get recordDate;@JsonKey(name: 'file_urls', fromJson: _stringListFromJson) List<String> get fileUrls;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'deleted_at') DateTime? get deletedAt;@JsonKey(name: 'locked_until') DateTime? get lockedUntil;
/// Create a copy of MedicalRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MedicalRecordCopyWith<MedicalRecord> get copyWith => _$MedicalRecordCopyWithImpl<MedicalRecord>(this as MedicalRecord, _$identity);

  /// Serializes this MedicalRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MedicalRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.recordFor, recordFor) || other.recordFor == recordFor)&&(identical(other.recordType, recordType) || other.recordType == recordType)&&(identical(other.recordDate, recordDate) || other.recordDate == recordDate)&&const DeepCollectionEquality().equals(other.fileUrls, fileUrls)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.lockedUntil, lockedUntil) || other.lockedUntil == lockedUntil));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,recordFor,recordType,recordDate,const DeepCollectionEquality().hash(fileUrls),createdAt,deletedAt,lockedUntil);

@override
String toString() {
  return 'MedicalRecord(id: $id, userId: $userId, recordFor: $recordFor, recordType: $recordType, recordDate: $recordDate, fileUrls: $fileUrls, createdAt: $createdAt, deletedAt: $deletedAt, lockedUntil: $lockedUntil)';
}


}

/// @nodoc
abstract mixin class $MedicalRecordCopyWith<$Res>  {
  factory $MedicalRecordCopyWith(MedicalRecord value, $Res Function(MedicalRecord) _then) = _$MedicalRecordCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'record_for') String recordFor,@JsonKey(name: 'record_type') String recordType,@JsonKey(name: 'record_date') DateTime recordDate,@JsonKey(name: 'file_urls', fromJson: _stringListFromJson) List<String> fileUrls,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'deleted_at') DateTime? deletedAt,@JsonKey(name: 'locked_until') DateTime? lockedUntil
});




}
/// @nodoc
class _$MedicalRecordCopyWithImpl<$Res>
    implements $MedicalRecordCopyWith<$Res> {
  _$MedicalRecordCopyWithImpl(this._self, this._then);

  final MedicalRecord _self;
  final $Res Function(MedicalRecord) _then;

/// Create a copy of MedicalRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? recordFor = null,Object? recordType = null,Object? recordDate = null,Object? fileUrls = null,Object? createdAt = null,Object? deletedAt = freezed,Object? lockedUntil = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,recordFor: null == recordFor ? _self.recordFor : recordFor // ignore: cast_nullable_to_non_nullable
as String,recordType: null == recordType ? _self.recordType : recordType // ignore: cast_nullable_to_non_nullable
as String,recordDate: null == recordDate ? _self.recordDate : recordDate // ignore: cast_nullable_to_non_nullable
as DateTime,fileUrls: null == fileUrls ? _self.fileUrls : fileUrls // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lockedUntil: freezed == lockedUntil ? _self.lockedUntil : lockedUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [MedicalRecord].
extension MedicalRecordPatterns on MedicalRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MedicalRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MedicalRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MedicalRecord value)  $default,){
final _that = this;
switch (_that) {
case _MedicalRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MedicalRecord value)?  $default,){
final _that = this;
switch (_that) {
case _MedicalRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'record_for')  String recordFor, @JsonKey(name: 'record_type')  String recordType, @JsonKey(name: 'record_date')  DateTime recordDate, @JsonKey(name: 'file_urls', fromJson: _stringListFromJson)  List<String> fileUrls, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'deleted_at')  DateTime? deletedAt, @JsonKey(name: 'locked_until')  DateTime? lockedUntil)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MedicalRecord() when $default != null:
return $default(_that.id,_that.userId,_that.recordFor,_that.recordType,_that.recordDate,_that.fileUrls,_that.createdAt,_that.deletedAt,_that.lockedUntil);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'record_for')  String recordFor, @JsonKey(name: 'record_type')  String recordType, @JsonKey(name: 'record_date')  DateTime recordDate, @JsonKey(name: 'file_urls', fromJson: _stringListFromJson)  List<String> fileUrls, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'deleted_at')  DateTime? deletedAt, @JsonKey(name: 'locked_until')  DateTime? lockedUntil)  $default,) {final _that = this;
switch (_that) {
case _MedicalRecord():
return $default(_that.id,_that.userId,_that.recordFor,_that.recordType,_that.recordDate,_that.fileUrls,_that.createdAt,_that.deletedAt,_that.lockedUntil);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'record_for')  String recordFor, @JsonKey(name: 'record_type')  String recordType, @JsonKey(name: 'record_date')  DateTime recordDate, @JsonKey(name: 'file_urls', fromJson: _stringListFromJson)  List<String> fileUrls, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'deleted_at')  DateTime? deletedAt, @JsonKey(name: 'locked_until')  DateTime? lockedUntil)?  $default,) {final _that = this;
switch (_that) {
case _MedicalRecord() when $default != null:
return $default(_that.id,_that.userId,_that.recordFor,_that.recordType,_that.recordDate,_that.fileUrls,_that.createdAt,_that.deletedAt,_that.lockedUntil);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MedicalRecord implements MedicalRecord {
  const _MedicalRecord({required this.id, @JsonKey(name: 'user_id') required this.userId, @JsonKey(name: 'record_for') required this.recordFor, @JsonKey(name: 'record_type') required this.recordType, @JsonKey(name: 'record_date') required this.recordDate, @JsonKey(name: 'file_urls', fromJson: _stringListFromJson) final  List<String> fileUrls = const <String>[], @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'deleted_at') this.deletedAt, @JsonKey(name: 'locked_until') this.lockedUntil}): _fileUrls = fileUrls;
  factory _MedicalRecord.fromJson(Map<String, dynamic> json) => _$MedicalRecordFromJson(json);

@override final  int id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'record_for') final  String recordFor;
@override@JsonKey(name: 'record_type') final  String recordType;
@override@JsonKey(name: 'record_date') final  DateTime recordDate;
 final  List<String> _fileUrls;
@override@JsonKey(name: 'file_urls', fromJson: _stringListFromJson) List<String> get fileUrls {
  if (_fileUrls is EqualUnmodifiableListView) return _fileUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_fileUrls);
}

@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'deleted_at') final  DateTime? deletedAt;
@override@JsonKey(name: 'locked_until') final  DateTime? lockedUntil;

/// Create a copy of MedicalRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MedicalRecordCopyWith<_MedicalRecord> get copyWith => __$MedicalRecordCopyWithImpl<_MedicalRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MedicalRecordToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MedicalRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.recordFor, recordFor) || other.recordFor == recordFor)&&(identical(other.recordType, recordType) || other.recordType == recordType)&&(identical(other.recordDate, recordDate) || other.recordDate == recordDate)&&const DeepCollectionEquality().equals(other._fileUrls, _fileUrls)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.lockedUntil, lockedUntil) || other.lockedUntil == lockedUntil));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,recordFor,recordType,recordDate,const DeepCollectionEquality().hash(_fileUrls),createdAt,deletedAt,lockedUntil);

@override
String toString() {
  return 'MedicalRecord(id: $id, userId: $userId, recordFor: $recordFor, recordType: $recordType, recordDate: $recordDate, fileUrls: $fileUrls, createdAt: $createdAt, deletedAt: $deletedAt, lockedUntil: $lockedUntil)';
}


}

/// @nodoc
abstract mixin class _$MedicalRecordCopyWith<$Res> implements $MedicalRecordCopyWith<$Res> {
  factory _$MedicalRecordCopyWith(_MedicalRecord value, $Res Function(_MedicalRecord) _then) = __$MedicalRecordCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'record_for') String recordFor,@JsonKey(name: 'record_type') String recordType,@JsonKey(name: 'record_date') DateTime recordDate,@JsonKey(name: 'file_urls', fromJson: _stringListFromJson) List<String> fileUrls,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'deleted_at') DateTime? deletedAt,@JsonKey(name: 'locked_until') DateTime? lockedUntil
});




}
/// @nodoc
class __$MedicalRecordCopyWithImpl<$Res>
    implements _$MedicalRecordCopyWith<$Res> {
  __$MedicalRecordCopyWithImpl(this._self, this._then);

  final _MedicalRecord _self;
  final $Res Function(_MedicalRecord) _then;

/// Create a copy of MedicalRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? recordFor = null,Object? recordType = null,Object? recordDate = null,Object? fileUrls = null,Object? createdAt = null,Object? deletedAt = freezed,Object? lockedUntil = freezed,}) {
  return _then(_MedicalRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,recordFor: null == recordFor ? _self.recordFor : recordFor // ignore: cast_nullable_to_non_nullable
as String,recordType: null == recordType ? _self.recordType : recordType // ignore: cast_nullable_to_non_nullable
as String,recordDate: null == recordDate ? _self.recordDate : recordDate // ignore: cast_nullable_to_non_nullable
as DateTime,fileUrls: null == fileUrls ? _self._fileUrls : fileUrls // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lockedUntil: freezed == lockedUntil ? _self.lockedUntil : lockedUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
