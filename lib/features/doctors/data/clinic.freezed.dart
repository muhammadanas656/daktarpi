// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'clinic.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Clinic {

 int get id; String get name; String get address;
/// Create a copy of Clinic
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClinicCopyWith<Clinic> get copyWith => _$ClinicCopyWithImpl<Clinic>(this as Clinic, _$identity);

  /// Serializes this Clinic to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Clinic&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.address, address) || other.address == address));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,address);

@override
String toString() {
  return 'Clinic(id: $id, name: $name, address: $address)';
}


}

/// @nodoc
abstract mixin class $ClinicCopyWith<$Res>  {
  factory $ClinicCopyWith(Clinic value, $Res Function(Clinic) _then) = _$ClinicCopyWithImpl;
@useResult
$Res call({
 int id, String name, String address
});




}
/// @nodoc
class _$ClinicCopyWithImpl<$Res>
    implements $ClinicCopyWith<$Res> {
  _$ClinicCopyWithImpl(this._self, this._then);

  final Clinic _self;
  final $Res Function(Clinic) _then;

/// Create a copy of Clinic
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? address = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Clinic].
extension ClinicPatterns on Clinic {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Clinic value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Clinic() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Clinic value)  $default,){
final _that = this;
switch (_that) {
case _Clinic():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Clinic value)?  $default,){
final _that = this;
switch (_that) {
case _Clinic() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  String address)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Clinic() when $default != null:
return $default(_that.id,_that.name,_that.address);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  String address)  $default,) {final _that = this;
switch (_that) {
case _Clinic():
return $default(_that.id,_that.name,_that.address);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  String address)?  $default,) {final _that = this;
switch (_that) {
case _Clinic() when $default != null:
return $default(_that.id,_that.name,_that.address);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Clinic implements Clinic {
  const _Clinic({required this.id, this.name = 'Unknown Clinic', this.address = 'Unknown Address'});
  factory _Clinic.fromJson(Map<String, dynamic> json) => _$ClinicFromJson(json);

@override final  int id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String address;

/// Create a copy of Clinic
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClinicCopyWith<_Clinic> get copyWith => __$ClinicCopyWithImpl<_Clinic>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClinicToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Clinic&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.address, address) || other.address == address));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,address);

@override
String toString() {
  return 'Clinic(id: $id, name: $name, address: $address)';
}


}

/// @nodoc
abstract mixin class _$ClinicCopyWith<$Res> implements $ClinicCopyWith<$Res> {
  factory _$ClinicCopyWith(_Clinic value, $Res Function(_Clinic) _then) = __$ClinicCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, String address
});




}
/// @nodoc
class __$ClinicCopyWithImpl<$Res>
    implements _$ClinicCopyWith<$Res> {
  __$ClinicCopyWithImpl(this._self, this._then);

  final _Clinic _self;
  final $Res Function(_Clinic) _then;

/// Create a copy of Clinic
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? address = null,}) {
  return _then(_Clinic(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
