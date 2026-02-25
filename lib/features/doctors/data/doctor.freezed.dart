// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'doctor.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Doctor {

 int get id;@JsonKey(name: 'full_name', defaultValue: 'Unknown Doctor') String get fullName;@JsonKey(name: 'profile_picture_url') String? get profilePictureUrl;@JsonKey(readValue: _readDoctorSpecialty, fromJson: _specialtyFromJson) String get specialty;@JsonKey(fromJson: _doubleFromJson) double get rating;@JsonKey(name: 'reviews_count', fromJson: _intFromJson) int get reviewsCount;@JsonKey(name: 'experience_years', fromJson: _intFromJson) int get experienceYears;@JsonKey(name: 'patients_served', fromJson: _intFromJson) int get patientsServed;@JsonKey(name: 'views_count', fromJson: _intFromJson) int get viewsCount;@JsonKey(name: 'hourly_rate', fromJson: _intFromJson) int get visitPrice; String? get about;@JsonKey(name: 'location') String? get location;@JsonKey(name: 'phone_number') String? get phoneNumber;
/// Create a copy of Doctor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DoctorCopyWith<Doctor> get copyWith => _$DoctorCopyWithImpl<Doctor>(this as Doctor, _$identity);

  /// Serializes this Doctor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Doctor&&(identical(other.id, id) || other.id == id)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.profilePictureUrl, profilePictureUrl) || other.profilePictureUrl == profilePictureUrl)&&(identical(other.specialty, specialty) || other.specialty == specialty)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.reviewsCount, reviewsCount) || other.reviewsCount == reviewsCount)&&(identical(other.experienceYears, experienceYears) || other.experienceYears == experienceYears)&&(identical(other.patientsServed, patientsServed) || other.patientsServed == patientsServed)&&(identical(other.viewsCount, viewsCount) || other.viewsCount == viewsCount)&&(identical(other.visitPrice, visitPrice) || other.visitPrice == visitPrice)&&(identical(other.about, about) || other.about == about)&&(identical(other.location, location) || other.location == location)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fullName,profilePictureUrl,specialty,rating,reviewsCount,experienceYears,patientsServed,viewsCount,visitPrice,about,location,phoneNumber);

@override
String toString() {
  return 'Doctor(id: $id, fullName: $fullName, profilePictureUrl: $profilePictureUrl, specialty: $specialty, rating: $rating, reviewsCount: $reviewsCount, experienceYears: $experienceYears, patientsServed: $patientsServed, viewsCount: $viewsCount, visitPrice: $visitPrice, about: $about, location: $location, phoneNumber: $phoneNumber)';
}


}

/// @nodoc
abstract mixin class $DoctorCopyWith<$Res>  {
  factory $DoctorCopyWith(Doctor value, $Res Function(Doctor) _then) = _$DoctorCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'full_name', defaultValue: 'Unknown Doctor') String fullName,@JsonKey(name: 'profile_picture_url') String? profilePictureUrl,@JsonKey(readValue: _readDoctorSpecialty, fromJson: _specialtyFromJson) String specialty,@JsonKey(fromJson: _doubleFromJson) double rating,@JsonKey(name: 'reviews_count', fromJson: _intFromJson) int reviewsCount,@JsonKey(name: 'experience_years', fromJson: _intFromJson) int experienceYears,@JsonKey(name: 'patients_served', fromJson: _intFromJson) int patientsServed,@JsonKey(name: 'views_count', fromJson: _intFromJson) int viewsCount,@JsonKey(name: 'hourly_rate', fromJson: _intFromJson) int visitPrice, String? about,@JsonKey(name: 'location') String? location,@JsonKey(name: 'phone_number') String? phoneNumber
});




}
/// @nodoc
class _$DoctorCopyWithImpl<$Res>
    implements $DoctorCopyWith<$Res> {
  _$DoctorCopyWithImpl(this._self, this._then);

  final Doctor _self;
  final $Res Function(Doctor) _then;

/// Create a copy of Doctor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? fullName = null,Object? profilePictureUrl = freezed,Object? specialty = null,Object? rating = null,Object? reviewsCount = null,Object? experienceYears = null,Object? patientsServed = null,Object? viewsCount = null,Object? visitPrice = null,Object? about = freezed,Object? location = freezed,Object? phoneNumber = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,profilePictureUrl: freezed == profilePictureUrl ? _self.profilePictureUrl : profilePictureUrl // ignore: cast_nullable_to_non_nullable
as String?,specialty: null == specialty ? _self.specialty : specialty // ignore: cast_nullable_to_non_nullable
as String,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double,reviewsCount: null == reviewsCount ? _self.reviewsCount : reviewsCount // ignore: cast_nullable_to_non_nullable
as int,experienceYears: null == experienceYears ? _self.experienceYears : experienceYears // ignore: cast_nullable_to_non_nullable
as int,patientsServed: null == patientsServed ? _self.patientsServed : patientsServed // ignore: cast_nullable_to_non_nullable
as int,viewsCount: null == viewsCount ? _self.viewsCount : viewsCount // ignore: cast_nullable_to_non_nullable
as int,visitPrice: null == visitPrice ? _self.visitPrice : visitPrice // ignore: cast_nullable_to_non_nullable
as int,about: freezed == about ? _self.about : about // ignore: cast_nullable_to_non_nullable
as String?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Doctor].
extension DoctorPatterns on Doctor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Doctor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Doctor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Doctor value)  $default,){
final _that = this;
switch (_that) {
case _Doctor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Doctor value)?  $default,){
final _that = this;
switch (_that) {
case _Doctor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'full_name', defaultValue: 'Unknown Doctor')  String fullName, @JsonKey(name: 'profile_picture_url')  String? profilePictureUrl, @JsonKey(readValue: _readDoctorSpecialty, fromJson: _specialtyFromJson)  String specialty, @JsonKey(fromJson: _doubleFromJson)  double rating, @JsonKey(name: 'reviews_count', fromJson: _intFromJson)  int reviewsCount, @JsonKey(name: 'experience_years', fromJson: _intFromJson)  int experienceYears, @JsonKey(name: 'patients_served', fromJson: _intFromJson)  int patientsServed, @JsonKey(name: 'views_count', fromJson: _intFromJson)  int viewsCount, @JsonKey(name: 'hourly_rate', fromJson: _intFromJson)  int visitPrice,  String? about, @JsonKey(name: 'location')  String? location, @JsonKey(name: 'phone_number')  String? phoneNumber)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Doctor() when $default != null:
return $default(_that.id,_that.fullName,_that.profilePictureUrl,_that.specialty,_that.rating,_that.reviewsCount,_that.experienceYears,_that.patientsServed,_that.viewsCount,_that.visitPrice,_that.about,_that.location,_that.phoneNumber);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'full_name', defaultValue: 'Unknown Doctor')  String fullName, @JsonKey(name: 'profile_picture_url')  String? profilePictureUrl, @JsonKey(readValue: _readDoctorSpecialty, fromJson: _specialtyFromJson)  String specialty, @JsonKey(fromJson: _doubleFromJson)  double rating, @JsonKey(name: 'reviews_count', fromJson: _intFromJson)  int reviewsCount, @JsonKey(name: 'experience_years', fromJson: _intFromJson)  int experienceYears, @JsonKey(name: 'patients_served', fromJson: _intFromJson)  int patientsServed, @JsonKey(name: 'views_count', fromJson: _intFromJson)  int viewsCount, @JsonKey(name: 'hourly_rate', fromJson: _intFromJson)  int visitPrice,  String? about, @JsonKey(name: 'location')  String? location, @JsonKey(name: 'phone_number')  String? phoneNumber)  $default,) {final _that = this;
switch (_that) {
case _Doctor():
return $default(_that.id,_that.fullName,_that.profilePictureUrl,_that.specialty,_that.rating,_that.reviewsCount,_that.experienceYears,_that.patientsServed,_that.viewsCount,_that.visitPrice,_that.about,_that.location,_that.phoneNumber);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'full_name', defaultValue: 'Unknown Doctor')  String fullName, @JsonKey(name: 'profile_picture_url')  String? profilePictureUrl, @JsonKey(readValue: _readDoctorSpecialty, fromJson: _specialtyFromJson)  String specialty, @JsonKey(fromJson: _doubleFromJson)  double rating, @JsonKey(name: 'reviews_count', fromJson: _intFromJson)  int reviewsCount, @JsonKey(name: 'experience_years', fromJson: _intFromJson)  int experienceYears, @JsonKey(name: 'patients_served', fromJson: _intFromJson)  int patientsServed, @JsonKey(name: 'views_count', fromJson: _intFromJson)  int viewsCount, @JsonKey(name: 'hourly_rate', fromJson: _intFromJson)  int visitPrice,  String? about, @JsonKey(name: 'location')  String? location, @JsonKey(name: 'phone_number')  String? phoneNumber)?  $default,) {final _that = this;
switch (_that) {
case _Doctor() when $default != null:
return $default(_that.id,_that.fullName,_that.profilePictureUrl,_that.specialty,_that.rating,_that.reviewsCount,_that.experienceYears,_that.patientsServed,_that.viewsCount,_that.visitPrice,_that.about,_that.location,_that.phoneNumber);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Doctor extends Doctor {
  const _Doctor({required this.id, @JsonKey(name: 'full_name', defaultValue: 'Unknown Doctor') required this.fullName, @JsonKey(name: 'profile_picture_url') this.profilePictureUrl, @JsonKey(readValue: _readDoctorSpecialty, fromJson: _specialtyFromJson) this.specialty = 'Specialist', @JsonKey(fromJson: _doubleFromJson) this.rating = 0.0, @JsonKey(name: 'reviews_count', fromJson: _intFromJson) this.reviewsCount = 0, @JsonKey(name: 'experience_years', fromJson: _intFromJson) this.experienceYears = 0, @JsonKey(name: 'patients_served', fromJson: _intFromJson) this.patientsServed = 0, @JsonKey(name: 'views_count', fromJson: _intFromJson) this.viewsCount = 0, @JsonKey(name: 'hourly_rate', fromJson: _intFromJson) this.visitPrice = 0, this.about, @JsonKey(name: 'location') this.location, @JsonKey(name: 'phone_number') this.phoneNumber}): super._();
  factory _Doctor.fromJson(Map<String, dynamic> json) => _$DoctorFromJson(json);

@override final  int id;
@override@JsonKey(name: 'full_name', defaultValue: 'Unknown Doctor') final  String fullName;
@override@JsonKey(name: 'profile_picture_url') final  String? profilePictureUrl;
@override@JsonKey(readValue: _readDoctorSpecialty, fromJson: _specialtyFromJson) final  String specialty;
@override@JsonKey(fromJson: _doubleFromJson) final  double rating;
@override@JsonKey(name: 'reviews_count', fromJson: _intFromJson) final  int reviewsCount;
@override@JsonKey(name: 'experience_years', fromJson: _intFromJson) final  int experienceYears;
@override@JsonKey(name: 'patients_served', fromJson: _intFromJson) final  int patientsServed;
@override@JsonKey(name: 'views_count', fromJson: _intFromJson) final  int viewsCount;
@override@JsonKey(name: 'hourly_rate', fromJson: _intFromJson) final  int visitPrice;
@override final  String? about;
@override@JsonKey(name: 'location') final  String? location;
@override@JsonKey(name: 'phone_number') final  String? phoneNumber;

/// Create a copy of Doctor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DoctorCopyWith<_Doctor> get copyWith => __$DoctorCopyWithImpl<_Doctor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DoctorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Doctor&&(identical(other.id, id) || other.id == id)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.profilePictureUrl, profilePictureUrl) || other.profilePictureUrl == profilePictureUrl)&&(identical(other.specialty, specialty) || other.specialty == specialty)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.reviewsCount, reviewsCount) || other.reviewsCount == reviewsCount)&&(identical(other.experienceYears, experienceYears) || other.experienceYears == experienceYears)&&(identical(other.patientsServed, patientsServed) || other.patientsServed == patientsServed)&&(identical(other.viewsCount, viewsCount) || other.viewsCount == viewsCount)&&(identical(other.visitPrice, visitPrice) || other.visitPrice == visitPrice)&&(identical(other.about, about) || other.about == about)&&(identical(other.location, location) || other.location == location)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fullName,profilePictureUrl,specialty,rating,reviewsCount,experienceYears,patientsServed,viewsCount,visitPrice,about,location,phoneNumber);

@override
String toString() {
  return 'Doctor(id: $id, fullName: $fullName, profilePictureUrl: $profilePictureUrl, specialty: $specialty, rating: $rating, reviewsCount: $reviewsCount, experienceYears: $experienceYears, patientsServed: $patientsServed, viewsCount: $viewsCount, visitPrice: $visitPrice, about: $about, location: $location, phoneNumber: $phoneNumber)';
}


}

/// @nodoc
abstract mixin class _$DoctorCopyWith<$Res> implements $DoctorCopyWith<$Res> {
  factory _$DoctorCopyWith(_Doctor value, $Res Function(_Doctor) _then) = __$DoctorCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'full_name', defaultValue: 'Unknown Doctor') String fullName,@JsonKey(name: 'profile_picture_url') String? profilePictureUrl,@JsonKey(readValue: _readDoctorSpecialty, fromJson: _specialtyFromJson) String specialty,@JsonKey(fromJson: _doubleFromJson) double rating,@JsonKey(name: 'reviews_count', fromJson: _intFromJson) int reviewsCount,@JsonKey(name: 'experience_years', fromJson: _intFromJson) int experienceYears,@JsonKey(name: 'patients_served', fromJson: _intFromJson) int patientsServed,@JsonKey(name: 'views_count', fromJson: _intFromJson) int viewsCount,@JsonKey(name: 'hourly_rate', fromJson: _intFromJson) int visitPrice, String? about,@JsonKey(name: 'location') String? location,@JsonKey(name: 'phone_number') String? phoneNumber
});




}
/// @nodoc
class __$DoctorCopyWithImpl<$Res>
    implements _$DoctorCopyWith<$Res> {
  __$DoctorCopyWithImpl(this._self, this._then);

  final _Doctor _self;
  final $Res Function(_Doctor) _then;

/// Create a copy of Doctor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fullName = null,Object? profilePictureUrl = freezed,Object? specialty = null,Object? rating = null,Object? reviewsCount = null,Object? experienceYears = null,Object? patientsServed = null,Object? viewsCount = null,Object? visitPrice = null,Object? about = freezed,Object? location = freezed,Object? phoneNumber = freezed,}) {
  return _then(_Doctor(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,profilePictureUrl: freezed == profilePictureUrl ? _self.profilePictureUrl : profilePictureUrl // ignore: cast_nullable_to_non_nullable
as String?,specialty: null == specialty ? _self.specialty : specialty // ignore: cast_nullable_to_non_nullable
as String,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double,reviewsCount: null == reviewsCount ? _self.reviewsCount : reviewsCount // ignore: cast_nullable_to_non_nullable
as int,experienceYears: null == experienceYears ? _self.experienceYears : experienceYears // ignore: cast_nullable_to_non_nullable
as int,patientsServed: null == patientsServed ? _self.patientsServed : patientsServed // ignore: cast_nullable_to_non_nullable
as int,viewsCount: null == viewsCount ? _self.viewsCount : viewsCount // ignore: cast_nullable_to_non_nullable
as int,visitPrice: null == visitPrice ? _self.visitPrice : visitPrice // ignore: cast_nullable_to_non_nullable
as int,about: freezed == about ? _self.about : about // ignore: cast_nullable_to_non_nullable
as String?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
