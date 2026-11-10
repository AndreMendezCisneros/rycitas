// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'modelos.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TratamientoRef {

 int get id; String get nombre;
/// Create a copy of TratamientoRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TratamientoRefCopyWith<TratamientoRef> get copyWith => _$TratamientoRefCopyWithImpl<TratamientoRef>(this as TratamientoRef, _$identity);

  /// Serializes this TratamientoRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TratamientoRef&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre);

@override
String toString() {
  return 'TratamientoRef(id: $id, nombre: $nombre)';
}


}

/// @nodoc
abstract mixin class $TratamientoRefCopyWith<$Res>  {
  factory $TratamientoRefCopyWith(TratamientoRef value, $Res Function(TratamientoRef) _then) = _$TratamientoRefCopyWithImpl;
@useResult
$Res call({
 int id, String nombre
});




}
/// @nodoc
class _$TratamientoRefCopyWithImpl<$Res>
    implements $TratamientoRefCopyWith<$Res> {
  _$TratamientoRefCopyWithImpl(this._self, this._then);

  final TratamientoRef _self;
  final $Res Function(TratamientoRef) _then;

/// Create a copy of TratamientoRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? nombre = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TratamientoRef].
extension TratamientoRefPatterns on TratamientoRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TratamientoRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TratamientoRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TratamientoRef value)  $default,){
final _that = this;
switch (_that) {
case _TratamientoRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TratamientoRef value)?  $default,){
final _that = this;
switch (_that) {
case _TratamientoRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String nombre)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TratamientoRef() when $default != null:
return $default(_that.id,_that.nombre);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String nombre)  $default,) {final _that = this;
switch (_that) {
case _TratamientoRef():
return $default(_that.id,_that.nombre);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String nombre)?  $default,) {final _that = this;
switch (_that) {
case _TratamientoRef() when $default != null:
return $default(_that.id,_that.nombre);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TratamientoRef implements TratamientoRef {
  const _TratamientoRef({required this.id, required this.nombre});
  factory _TratamientoRef.fromJson(Map<String, dynamic> json) => _$TratamientoRefFromJson(json);

@override final  int id;
@override final  String nombre;

/// Create a copy of TratamientoRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TratamientoRefCopyWith<_TratamientoRef> get copyWith => __$TratamientoRefCopyWithImpl<_TratamientoRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TratamientoRefToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TratamientoRef&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre);

@override
String toString() {
  return 'TratamientoRef(id: $id, nombre: $nombre)';
}


}

/// @nodoc
abstract mixin class _$TratamientoRefCopyWith<$Res> implements $TratamientoRefCopyWith<$Res> {
  factory _$TratamientoRefCopyWith(_TratamientoRef value, $Res Function(_TratamientoRef) _then) = __$TratamientoRefCopyWithImpl;
@override @useResult
$Res call({
 int id, String nombre
});




}
/// @nodoc
class __$TratamientoRefCopyWithImpl<$Res>
    implements _$TratamientoRefCopyWith<$Res> {
  __$TratamientoRefCopyWithImpl(this._self, this._then);

  final _TratamientoRef _self;
  final $Res Function(_TratamientoRef) _then;

/// Create a copy of TratamientoRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? nombre = null,}) {
  return _then(_TratamientoRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ProfesionalRef {

 int get id; String get nombre;
/// Create a copy of ProfesionalRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfesionalRefCopyWith<ProfesionalRef> get copyWith => _$ProfesionalRefCopyWithImpl<ProfesionalRef>(this as ProfesionalRef, _$identity);

  /// Serializes this ProfesionalRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfesionalRef&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre);

@override
String toString() {
  return 'ProfesionalRef(id: $id, nombre: $nombre)';
}


}

/// @nodoc
abstract mixin class $ProfesionalRefCopyWith<$Res>  {
  factory $ProfesionalRefCopyWith(ProfesionalRef value, $Res Function(ProfesionalRef) _then) = _$ProfesionalRefCopyWithImpl;
@useResult
$Res call({
 int id, String nombre
});




}
/// @nodoc
class _$ProfesionalRefCopyWithImpl<$Res>
    implements $ProfesionalRefCopyWith<$Res> {
  _$ProfesionalRefCopyWithImpl(this._self, this._then);

  final ProfesionalRef _self;
  final $Res Function(ProfesionalRef) _then;

/// Create a copy of ProfesionalRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? nombre = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfesionalRef].
extension ProfesionalRefPatterns on ProfesionalRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfesionalRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfesionalRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfesionalRef value)  $default,){
final _that = this;
switch (_that) {
case _ProfesionalRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfesionalRef value)?  $default,){
final _that = this;
switch (_that) {
case _ProfesionalRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String nombre)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfesionalRef() when $default != null:
return $default(_that.id,_that.nombre);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String nombre)  $default,) {final _that = this;
switch (_that) {
case _ProfesionalRef():
return $default(_that.id,_that.nombre);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String nombre)?  $default,) {final _that = this;
switch (_that) {
case _ProfesionalRef() when $default != null:
return $default(_that.id,_that.nombre);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfesionalRef implements ProfesionalRef {
  const _ProfesionalRef({required this.id, required this.nombre});
  factory _ProfesionalRef.fromJson(Map<String, dynamic> json) => _$ProfesionalRefFromJson(json);

@override final  int id;
@override final  String nombre;

/// Create a copy of ProfesionalRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfesionalRefCopyWith<_ProfesionalRef> get copyWith => __$ProfesionalRefCopyWithImpl<_ProfesionalRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfesionalRefToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfesionalRef&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre);

@override
String toString() {
  return 'ProfesionalRef(id: $id, nombre: $nombre)';
}


}

/// @nodoc
abstract mixin class _$ProfesionalRefCopyWith<$Res> implements $ProfesionalRefCopyWith<$Res> {
  factory _$ProfesionalRefCopyWith(_ProfesionalRef value, $Res Function(_ProfesionalRef) _then) = __$ProfesionalRefCopyWithImpl;
@override @useResult
$Res call({
 int id, String nombre
});




}
/// @nodoc
class __$ProfesionalRefCopyWithImpl<$Res>
    implements _$ProfesionalRefCopyWith<$Res> {
  __$ProfesionalRefCopyWithImpl(this._self, this._then);

  final _ProfesionalRef _self;
  final $Res Function(_ProfesionalRef) _then;

/// Create a copy of ProfesionalRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? nombre = null,}) {
  return _then(_ProfesionalRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$CuponCita {

 String get codigo; String get titulo; String get descuento;
/// Create a copy of CuponCita
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CuponCitaCopyWith<CuponCita> get copyWith => _$CuponCitaCopyWithImpl<CuponCita>(this as CuponCita, _$identity);

  /// Serializes this CuponCita to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CuponCita&&(identical(other.codigo, codigo) || other.codigo == codigo)&&(identical(other.titulo, titulo) || other.titulo == titulo)&&(identical(other.descuento, descuento) || other.descuento == descuento));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,codigo,titulo,descuento);

@override
String toString() {
  return 'CuponCita(codigo: $codigo, titulo: $titulo, descuento: $descuento)';
}


}

/// @nodoc
abstract mixin class $CuponCitaCopyWith<$Res>  {
  factory $CuponCitaCopyWith(CuponCita value, $Res Function(CuponCita) _then) = _$CuponCitaCopyWithImpl;
@useResult
$Res call({
 String codigo, String titulo, String descuento
});




}
/// @nodoc
class _$CuponCitaCopyWithImpl<$Res>
    implements $CuponCitaCopyWith<$Res> {
  _$CuponCitaCopyWithImpl(this._self, this._then);

  final CuponCita _self;
  final $Res Function(CuponCita) _then;

/// Create a copy of CuponCita
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? codigo = null,Object? titulo = null,Object? descuento = null,}) {
  return _then(_self.copyWith(
codigo: null == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as String,titulo: null == titulo ? _self.titulo : titulo // ignore: cast_nullable_to_non_nullable
as String,descuento: null == descuento ? _self.descuento : descuento // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CuponCita].
extension CuponCitaPatterns on CuponCita {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CuponCita value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CuponCita() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CuponCita value)  $default,){
final _that = this;
switch (_that) {
case _CuponCita():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CuponCita value)?  $default,){
final _that = this;
switch (_that) {
case _CuponCita() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String codigo,  String titulo,  String descuento)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CuponCita() when $default != null:
return $default(_that.codigo,_that.titulo,_that.descuento);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String codigo,  String titulo,  String descuento)  $default,) {final _that = this;
switch (_that) {
case _CuponCita():
return $default(_that.codigo,_that.titulo,_that.descuento);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String codigo,  String titulo,  String descuento)?  $default,) {final _that = this;
switch (_that) {
case _CuponCita() when $default != null:
return $default(_that.codigo,_that.titulo,_that.descuento);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CuponCita implements CuponCita {
  const _CuponCita({required this.codigo, required this.titulo, this.descuento = ''});
  factory _CuponCita.fromJson(Map<String, dynamic> json) => _$CuponCitaFromJson(json);

@override final  String codigo;
@override final  String titulo;
@override@JsonKey() final  String descuento;

/// Create a copy of CuponCita
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CuponCitaCopyWith<_CuponCita> get copyWith => __$CuponCitaCopyWithImpl<_CuponCita>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CuponCitaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CuponCita&&(identical(other.codigo, codigo) || other.codigo == codigo)&&(identical(other.titulo, titulo) || other.titulo == titulo)&&(identical(other.descuento, descuento) || other.descuento == descuento));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,codigo,titulo,descuento);

@override
String toString() {
  return 'CuponCita(codigo: $codigo, titulo: $titulo, descuento: $descuento)';
}


}

/// @nodoc
abstract mixin class _$CuponCitaCopyWith<$Res> implements $CuponCitaCopyWith<$Res> {
  factory _$CuponCitaCopyWith(_CuponCita value, $Res Function(_CuponCita) _then) = __$CuponCitaCopyWithImpl;
@override @useResult
$Res call({
 String codigo, String titulo, String descuento
});




}
/// @nodoc
class __$CuponCitaCopyWithImpl<$Res>
    implements _$CuponCitaCopyWith<$Res> {
  __$CuponCitaCopyWithImpl(this._self, this._then);

  final _CuponCita _self;
  final $Res Function(_CuponCita) _then;

/// Create a copy of CuponCita
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? codigo = null,Object? titulo = null,Object? descuento = null,}) {
  return _then(_CuponCita(
codigo: null == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as String,titulo: null == titulo ? _self.titulo : titulo // ignore: cast_nullable_to_non_nullable
as String,descuento: null == descuento ? _self.descuento : descuento // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PacienteRef {

 int get id; String get nombre; String get celular; int get inasistencias;
/// Create a copy of PacienteRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PacienteRefCopyWith<PacienteRef> get copyWith => _$PacienteRefCopyWithImpl<PacienteRef>(this as PacienteRef, _$identity);

  /// Serializes this PacienteRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PacienteRef&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.celular, celular) || other.celular == celular)&&(identical(other.inasistencias, inasistencias) || other.inasistencias == inasistencias));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre,celular,inasistencias);

@override
String toString() {
  return 'PacienteRef(id: $id, nombre: $nombre, celular: $celular, inasistencias: $inasistencias)';
}


}

/// @nodoc
abstract mixin class $PacienteRefCopyWith<$Res>  {
  factory $PacienteRefCopyWith(PacienteRef value, $Res Function(PacienteRef) _then) = _$PacienteRefCopyWithImpl;
@useResult
$Res call({
 int id, String nombre, String celular, int inasistencias
});




}
/// @nodoc
class _$PacienteRefCopyWithImpl<$Res>
    implements $PacienteRefCopyWith<$Res> {
  _$PacienteRefCopyWithImpl(this._self, this._then);

  final PacienteRef _self;
  final $Res Function(PacienteRef) _then;

/// Create a copy of PacienteRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? nombre = null,Object? celular = null,Object? inasistencias = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,celular: null == celular ? _self.celular : celular // ignore: cast_nullable_to_non_nullable
as String,inasistencias: null == inasistencias ? _self.inasistencias : inasistencias // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PacienteRef].
extension PacienteRefPatterns on PacienteRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PacienteRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PacienteRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PacienteRef value)  $default,){
final _that = this;
switch (_that) {
case _PacienteRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PacienteRef value)?  $default,){
final _that = this;
switch (_that) {
case _PacienteRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String nombre,  String celular,  int inasistencias)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PacienteRef() when $default != null:
return $default(_that.id,_that.nombre,_that.celular,_that.inasistencias);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String nombre,  String celular,  int inasistencias)  $default,) {final _that = this;
switch (_that) {
case _PacienteRef():
return $default(_that.id,_that.nombre,_that.celular,_that.inasistencias);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String nombre,  String celular,  int inasistencias)?  $default,) {final _that = this;
switch (_that) {
case _PacienteRef() when $default != null:
return $default(_that.id,_that.nombre,_that.celular,_that.inasistencias);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PacienteRef implements PacienteRef {
  const _PacienteRef({required this.id, required this.nombre, required this.celular, this.inasistencias = 0});
  factory _PacienteRef.fromJson(Map<String, dynamic> json) => _$PacienteRefFromJson(json);

@override final  int id;
@override final  String nombre;
@override final  String celular;
@override@JsonKey() final  int inasistencias;

/// Create a copy of PacienteRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PacienteRefCopyWith<_PacienteRef> get copyWith => __$PacienteRefCopyWithImpl<_PacienteRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PacienteRefToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PacienteRef&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.celular, celular) || other.celular == celular)&&(identical(other.inasistencias, inasistencias) || other.inasistencias == inasistencias));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre,celular,inasistencias);

@override
String toString() {
  return 'PacienteRef(id: $id, nombre: $nombre, celular: $celular, inasistencias: $inasistencias)';
}


}

/// @nodoc
abstract mixin class _$PacienteRefCopyWith<$Res> implements $PacienteRefCopyWith<$Res> {
  factory _$PacienteRefCopyWith(_PacienteRef value, $Res Function(_PacienteRef) _then) = __$PacienteRefCopyWithImpl;
@override @useResult
$Res call({
 int id, String nombre, String celular, int inasistencias
});




}
/// @nodoc
class __$PacienteRefCopyWithImpl<$Res>
    implements _$PacienteRefCopyWith<$Res> {
  __$PacienteRefCopyWithImpl(this._self, this._then);

  final _PacienteRef _self;
  final $Res Function(_PacienteRef) _then;

/// Create a copy of PacienteRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? nombre = null,Object? celular = null,Object? inasistencias = null,}) {
  return _then(_PacienteRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,celular: null == celular ? _self.celular : celular // ignore: cast_nullable_to_non_nullable
as String,inasistencias: null == inasistencias ? _self.inasistencias : inasistencias // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$Cita {

 int get id; String get estado; String get estadoTexto; String get origen; String get inicio; String get fin; String? get inicioEstimado; String? get finEstimado; int get retrasoMin; int get minutosExtra; String? get inicioReal; String? get finReal; String? get recordatorioEnviadoEn; bool? get asistenciaConfirmada;/// «Llegó»: el cliente está en la sala de espera.
 String? get llegadaEn; ProfesionalRef? get profesional;/// Precios en céntimos. El ofrecido lo propone el cliente (precio ofertable); el acordado lo fija el negocio.
 int? get precioReferencia; int? get precioOfrecido; int? get precioAcordado; String? get precioTexto;/// Solo en /citas/recordatorios: el WhatsApp con el recordatorio ya escrito.
 String? get whatsappUrl; TratamientoRef get tratamiento; PacienteRef get paciente;/// Cupón que el cliente eligió al reservar desde la app.
 CuponCita? get cupon;
/// Create a copy of Cita
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CitaCopyWith<Cita> get copyWith => _$CitaCopyWithImpl<Cita>(this as Cita, _$identity);

  /// Serializes this Cita to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Cita&&(identical(other.id, id) || other.id == id)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.estadoTexto, estadoTexto) || other.estadoTexto == estadoTexto)&&(identical(other.origen, origen) || other.origen == origen)&&(identical(other.inicio, inicio) || other.inicio == inicio)&&(identical(other.fin, fin) || other.fin == fin)&&(identical(other.inicioEstimado, inicioEstimado) || other.inicioEstimado == inicioEstimado)&&(identical(other.finEstimado, finEstimado) || other.finEstimado == finEstimado)&&(identical(other.retrasoMin, retrasoMin) || other.retrasoMin == retrasoMin)&&(identical(other.minutosExtra, minutosExtra) || other.minutosExtra == minutosExtra)&&(identical(other.inicioReal, inicioReal) || other.inicioReal == inicioReal)&&(identical(other.finReal, finReal) || other.finReal == finReal)&&(identical(other.recordatorioEnviadoEn, recordatorioEnviadoEn) || other.recordatorioEnviadoEn == recordatorioEnviadoEn)&&(identical(other.asistenciaConfirmada, asistenciaConfirmada) || other.asistenciaConfirmada == asistenciaConfirmada)&&(identical(other.llegadaEn, llegadaEn) || other.llegadaEn == llegadaEn)&&(identical(other.profesional, profesional) || other.profesional == profesional)&&(identical(other.precioReferencia, precioReferencia) || other.precioReferencia == precioReferencia)&&(identical(other.precioOfrecido, precioOfrecido) || other.precioOfrecido == precioOfrecido)&&(identical(other.precioAcordado, precioAcordado) || other.precioAcordado == precioAcordado)&&(identical(other.precioTexto, precioTexto) || other.precioTexto == precioTexto)&&(identical(other.whatsappUrl, whatsappUrl) || other.whatsappUrl == whatsappUrl)&&(identical(other.tratamiento, tratamiento) || other.tratamiento == tratamiento)&&(identical(other.paciente, paciente) || other.paciente == paciente)&&(identical(other.cupon, cupon) || other.cupon == cupon));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,estado,estadoTexto,origen,inicio,fin,inicioEstimado,finEstimado,retrasoMin,minutosExtra,inicioReal,finReal,recordatorioEnviadoEn,asistenciaConfirmada,llegadaEn,profesional,precioReferencia,precioOfrecido,precioAcordado,precioTexto,whatsappUrl,tratamiento,paciente,cupon]);

@override
String toString() {
  return 'Cita(id: $id, estado: $estado, estadoTexto: $estadoTexto, origen: $origen, inicio: $inicio, fin: $fin, inicioEstimado: $inicioEstimado, finEstimado: $finEstimado, retrasoMin: $retrasoMin, minutosExtra: $minutosExtra, inicioReal: $inicioReal, finReal: $finReal, recordatorioEnviadoEn: $recordatorioEnviadoEn, asistenciaConfirmada: $asistenciaConfirmada, llegadaEn: $llegadaEn, profesional: $profesional, precioReferencia: $precioReferencia, precioOfrecido: $precioOfrecido, precioAcordado: $precioAcordado, precioTexto: $precioTexto, whatsappUrl: $whatsappUrl, tratamiento: $tratamiento, paciente: $paciente, cupon: $cupon)';
}


}

/// @nodoc
abstract mixin class $CitaCopyWith<$Res>  {
  factory $CitaCopyWith(Cita value, $Res Function(Cita) _then) = _$CitaCopyWithImpl;
@useResult
$Res call({
 int id, String estado, String estadoTexto, String origen, String inicio, String fin, String? inicioEstimado, String? finEstimado, int retrasoMin, int minutosExtra, String? inicioReal, String? finReal, String? recordatorioEnviadoEn, bool? asistenciaConfirmada, String? llegadaEn, ProfesionalRef? profesional, int? precioReferencia, int? precioOfrecido, int? precioAcordado, String? precioTexto, String? whatsappUrl, TratamientoRef tratamiento, PacienteRef paciente, CuponCita? cupon
});


$ProfesionalRefCopyWith<$Res>? get profesional;$TratamientoRefCopyWith<$Res> get tratamiento;$PacienteRefCopyWith<$Res> get paciente;$CuponCitaCopyWith<$Res>? get cupon;

}
/// @nodoc
class _$CitaCopyWithImpl<$Res>
    implements $CitaCopyWith<$Res> {
  _$CitaCopyWithImpl(this._self, this._then);

  final Cita _self;
  final $Res Function(Cita) _then;

/// Create a copy of Cita
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? estado = null,Object? estadoTexto = null,Object? origen = null,Object? inicio = null,Object? fin = null,Object? inicioEstimado = freezed,Object? finEstimado = freezed,Object? retrasoMin = null,Object? minutosExtra = null,Object? inicioReal = freezed,Object? finReal = freezed,Object? recordatorioEnviadoEn = freezed,Object? asistenciaConfirmada = freezed,Object? llegadaEn = freezed,Object? profesional = freezed,Object? precioReferencia = freezed,Object? precioOfrecido = freezed,Object? precioAcordado = freezed,Object? precioTexto = freezed,Object? whatsappUrl = freezed,Object? tratamiento = null,Object? paciente = null,Object? cupon = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,estadoTexto: null == estadoTexto ? _self.estadoTexto : estadoTexto // ignore: cast_nullable_to_non_nullable
as String,origen: null == origen ? _self.origen : origen // ignore: cast_nullable_to_non_nullable
as String,inicio: null == inicio ? _self.inicio : inicio // ignore: cast_nullable_to_non_nullable
as String,fin: null == fin ? _self.fin : fin // ignore: cast_nullable_to_non_nullable
as String,inicioEstimado: freezed == inicioEstimado ? _self.inicioEstimado : inicioEstimado // ignore: cast_nullable_to_non_nullable
as String?,finEstimado: freezed == finEstimado ? _self.finEstimado : finEstimado // ignore: cast_nullable_to_non_nullable
as String?,retrasoMin: null == retrasoMin ? _self.retrasoMin : retrasoMin // ignore: cast_nullable_to_non_nullable
as int,minutosExtra: null == minutosExtra ? _self.minutosExtra : minutosExtra // ignore: cast_nullable_to_non_nullable
as int,inicioReal: freezed == inicioReal ? _self.inicioReal : inicioReal // ignore: cast_nullable_to_non_nullable
as String?,finReal: freezed == finReal ? _self.finReal : finReal // ignore: cast_nullable_to_non_nullable
as String?,recordatorioEnviadoEn: freezed == recordatorioEnviadoEn ? _self.recordatorioEnviadoEn : recordatorioEnviadoEn // ignore: cast_nullable_to_non_nullable
as String?,asistenciaConfirmada: freezed == asistenciaConfirmada ? _self.asistenciaConfirmada : asistenciaConfirmada // ignore: cast_nullable_to_non_nullable
as bool?,llegadaEn: freezed == llegadaEn ? _self.llegadaEn : llegadaEn // ignore: cast_nullable_to_non_nullable
as String?,profesional: freezed == profesional ? _self.profesional : profesional // ignore: cast_nullable_to_non_nullable
as ProfesionalRef?,precioReferencia: freezed == precioReferencia ? _self.precioReferencia : precioReferencia // ignore: cast_nullable_to_non_nullable
as int?,precioOfrecido: freezed == precioOfrecido ? _self.precioOfrecido : precioOfrecido // ignore: cast_nullable_to_non_nullable
as int?,precioAcordado: freezed == precioAcordado ? _self.precioAcordado : precioAcordado // ignore: cast_nullable_to_non_nullable
as int?,precioTexto: freezed == precioTexto ? _self.precioTexto : precioTexto // ignore: cast_nullable_to_non_nullable
as String?,whatsappUrl: freezed == whatsappUrl ? _self.whatsappUrl : whatsappUrl // ignore: cast_nullable_to_non_nullable
as String?,tratamiento: null == tratamiento ? _self.tratamiento : tratamiento // ignore: cast_nullable_to_non_nullable
as TratamientoRef,paciente: null == paciente ? _self.paciente : paciente // ignore: cast_nullable_to_non_nullable
as PacienteRef,cupon: freezed == cupon ? _self.cupon : cupon // ignore: cast_nullable_to_non_nullable
as CuponCita?,
  ));
}
/// Create a copy of Cita
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfesionalRefCopyWith<$Res>? get profesional {
    if (_self.profesional == null) {
    return null;
  }

  return $ProfesionalRefCopyWith<$Res>(_self.profesional!, (value) {
    return _then(_self.copyWith(profesional: value));
  });
}/// Create a copy of Cita
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TratamientoRefCopyWith<$Res> get tratamiento {
  
  return $TratamientoRefCopyWith<$Res>(_self.tratamiento, (value) {
    return _then(_self.copyWith(tratamiento: value));
  });
}/// Create a copy of Cita
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PacienteRefCopyWith<$Res> get paciente {
  
  return $PacienteRefCopyWith<$Res>(_self.paciente, (value) {
    return _then(_self.copyWith(paciente: value));
  });
}/// Create a copy of Cita
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CuponCitaCopyWith<$Res>? get cupon {
    if (_self.cupon == null) {
    return null;
  }

  return $CuponCitaCopyWith<$Res>(_self.cupon!, (value) {
    return _then(_self.copyWith(cupon: value));
  });
}
}


/// Adds pattern-matching-related methods to [Cita].
extension CitaPatterns on Cita {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Cita value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Cita() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Cita value)  $default,){
final _that = this;
switch (_that) {
case _Cita():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Cita value)?  $default,){
final _that = this;
switch (_that) {
case _Cita() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String estado,  String estadoTexto,  String origen,  String inicio,  String fin,  String? inicioEstimado,  String? finEstimado,  int retrasoMin,  int minutosExtra,  String? inicioReal,  String? finReal,  String? recordatorioEnviadoEn,  bool? asistenciaConfirmada,  String? llegadaEn,  ProfesionalRef? profesional,  int? precioReferencia,  int? precioOfrecido,  int? precioAcordado,  String? precioTexto,  String? whatsappUrl,  TratamientoRef tratamiento,  PacienteRef paciente,  CuponCita? cupon)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Cita() when $default != null:
return $default(_that.id,_that.estado,_that.estadoTexto,_that.origen,_that.inicio,_that.fin,_that.inicioEstimado,_that.finEstimado,_that.retrasoMin,_that.minutosExtra,_that.inicioReal,_that.finReal,_that.recordatorioEnviadoEn,_that.asistenciaConfirmada,_that.llegadaEn,_that.profesional,_that.precioReferencia,_that.precioOfrecido,_that.precioAcordado,_that.precioTexto,_that.whatsappUrl,_that.tratamiento,_that.paciente,_that.cupon);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String estado,  String estadoTexto,  String origen,  String inicio,  String fin,  String? inicioEstimado,  String? finEstimado,  int retrasoMin,  int minutosExtra,  String? inicioReal,  String? finReal,  String? recordatorioEnviadoEn,  bool? asistenciaConfirmada,  String? llegadaEn,  ProfesionalRef? profesional,  int? precioReferencia,  int? precioOfrecido,  int? precioAcordado,  String? precioTexto,  String? whatsappUrl,  TratamientoRef tratamiento,  PacienteRef paciente,  CuponCita? cupon)  $default,) {final _that = this;
switch (_that) {
case _Cita():
return $default(_that.id,_that.estado,_that.estadoTexto,_that.origen,_that.inicio,_that.fin,_that.inicioEstimado,_that.finEstimado,_that.retrasoMin,_that.minutosExtra,_that.inicioReal,_that.finReal,_that.recordatorioEnviadoEn,_that.asistenciaConfirmada,_that.llegadaEn,_that.profesional,_that.precioReferencia,_that.precioOfrecido,_that.precioAcordado,_that.precioTexto,_that.whatsappUrl,_that.tratamiento,_that.paciente,_that.cupon);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String estado,  String estadoTexto,  String origen,  String inicio,  String fin,  String? inicioEstimado,  String? finEstimado,  int retrasoMin,  int minutosExtra,  String? inicioReal,  String? finReal,  String? recordatorioEnviadoEn,  bool? asistenciaConfirmada,  String? llegadaEn,  ProfesionalRef? profesional,  int? precioReferencia,  int? precioOfrecido,  int? precioAcordado,  String? precioTexto,  String? whatsappUrl,  TratamientoRef tratamiento,  PacienteRef paciente,  CuponCita? cupon)?  $default,) {final _that = this;
switch (_that) {
case _Cita() when $default != null:
return $default(_that.id,_that.estado,_that.estadoTexto,_that.origen,_that.inicio,_that.fin,_that.inicioEstimado,_that.finEstimado,_that.retrasoMin,_that.minutosExtra,_that.inicioReal,_that.finReal,_that.recordatorioEnviadoEn,_that.asistenciaConfirmada,_that.llegadaEn,_that.profesional,_that.precioReferencia,_that.precioOfrecido,_that.precioAcordado,_that.precioTexto,_that.whatsappUrl,_that.tratamiento,_that.paciente,_that.cupon);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Cita extends Cita {
  const _Cita({required this.id, required this.estado, required this.estadoTexto, this.origen = 'web', required this.inicio, required this.fin, this.inicioEstimado, this.finEstimado, this.retrasoMin = 0, this.minutosExtra = 0, this.inicioReal, this.finReal, this.recordatorioEnviadoEn, this.asistenciaConfirmada, this.llegadaEn, this.profesional, this.precioReferencia, this.precioOfrecido, this.precioAcordado, this.precioTexto, this.whatsappUrl, required this.tratamiento, required this.paciente, this.cupon}): super._();
  factory _Cita.fromJson(Map<String, dynamic> json) => _$CitaFromJson(json);

@override final  int id;
@override final  String estado;
@override final  String estadoTexto;
@override@JsonKey() final  String origen;
@override final  String inicio;
@override final  String fin;
@override final  String? inicioEstimado;
@override final  String? finEstimado;
@override@JsonKey() final  int retrasoMin;
@override@JsonKey() final  int minutosExtra;
@override final  String? inicioReal;
@override final  String? finReal;
@override final  String? recordatorioEnviadoEn;
@override final  bool? asistenciaConfirmada;
/// «Llegó»: el cliente está en la sala de espera.
@override final  String? llegadaEn;
@override final  ProfesionalRef? profesional;
/// Precios en céntimos. El ofrecido lo propone el cliente (precio ofertable); el acordado lo fija el negocio.
@override final  int? precioReferencia;
@override final  int? precioOfrecido;
@override final  int? precioAcordado;
@override final  String? precioTexto;
/// Solo en /citas/recordatorios: el WhatsApp con el recordatorio ya escrito.
@override final  String? whatsappUrl;
@override final  TratamientoRef tratamiento;
@override final  PacienteRef paciente;
/// Cupón que el cliente eligió al reservar desde la app.
@override final  CuponCita? cupon;

/// Create a copy of Cita
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CitaCopyWith<_Cita> get copyWith => __$CitaCopyWithImpl<_Cita>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CitaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Cita&&(identical(other.id, id) || other.id == id)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.estadoTexto, estadoTexto) || other.estadoTexto == estadoTexto)&&(identical(other.origen, origen) || other.origen == origen)&&(identical(other.inicio, inicio) || other.inicio == inicio)&&(identical(other.fin, fin) || other.fin == fin)&&(identical(other.inicioEstimado, inicioEstimado) || other.inicioEstimado == inicioEstimado)&&(identical(other.finEstimado, finEstimado) || other.finEstimado == finEstimado)&&(identical(other.retrasoMin, retrasoMin) || other.retrasoMin == retrasoMin)&&(identical(other.minutosExtra, minutosExtra) || other.minutosExtra == minutosExtra)&&(identical(other.inicioReal, inicioReal) || other.inicioReal == inicioReal)&&(identical(other.finReal, finReal) || other.finReal == finReal)&&(identical(other.recordatorioEnviadoEn, recordatorioEnviadoEn) || other.recordatorioEnviadoEn == recordatorioEnviadoEn)&&(identical(other.asistenciaConfirmada, asistenciaConfirmada) || other.asistenciaConfirmada == asistenciaConfirmada)&&(identical(other.llegadaEn, llegadaEn) || other.llegadaEn == llegadaEn)&&(identical(other.profesional, profesional) || other.profesional == profesional)&&(identical(other.precioReferencia, precioReferencia) || other.precioReferencia == precioReferencia)&&(identical(other.precioOfrecido, precioOfrecido) || other.precioOfrecido == precioOfrecido)&&(identical(other.precioAcordado, precioAcordado) || other.precioAcordado == precioAcordado)&&(identical(other.precioTexto, precioTexto) || other.precioTexto == precioTexto)&&(identical(other.whatsappUrl, whatsappUrl) || other.whatsappUrl == whatsappUrl)&&(identical(other.tratamiento, tratamiento) || other.tratamiento == tratamiento)&&(identical(other.paciente, paciente) || other.paciente == paciente)&&(identical(other.cupon, cupon) || other.cupon == cupon));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,estado,estadoTexto,origen,inicio,fin,inicioEstimado,finEstimado,retrasoMin,minutosExtra,inicioReal,finReal,recordatorioEnviadoEn,asistenciaConfirmada,llegadaEn,profesional,precioReferencia,precioOfrecido,precioAcordado,precioTexto,whatsappUrl,tratamiento,paciente,cupon]);

@override
String toString() {
  return 'Cita(id: $id, estado: $estado, estadoTexto: $estadoTexto, origen: $origen, inicio: $inicio, fin: $fin, inicioEstimado: $inicioEstimado, finEstimado: $finEstimado, retrasoMin: $retrasoMin, minutosExtra: $minutosExtra, inicioReal: $inicioReal, finReal: $finReal, recordatorioEnviadoEn: $recordatorioEnviadoEn, asistenciaConfirmada: $asistenciaConfirmada, llegadaEn: $llegadaEn, profesional: $profesional, precioReferencia: $precioReferencia, precioOfrecido: $precioOfrecido, precioAcordado: $precioAcordado, precioTexto: $precioTexto, whatsappUrl: $whatsappUrl, tratamiento: $tratamiento, paciente: $paciente, cupon: $cupon)';
}


}

/// @nodoc
abstract mixin class _$CitaCopyWith<$Res> implements $CitaCopyWith<$Res> {
  factory _$CitaCopyWith(_Cita value, $Res Function(_Cita) _then) = __$CitaCopyWithImpl;
@override @useResult
$Res call({
 int id, String estado, String estadoTexto, String origen, String inicio, String fin, String? inicioEstimado, String? finEstimado, int retrasoMin, int minutosExtra, String? inicioReal, String? finReal, String? recordatorioEnviadoEn, bool? asistenciaConfirmada, String? llegadaEn, ProfesionalRef? profesional, int? precioReferencia, int? precioOfrecido, int? precioAcordado, String? precioTexto, String? whatsappUrl, TratamientoRef tratamiento, PacienteRef paciente, CuponCita? cupon
});


@override $ProfesionalRefCopyWith<$Res>? get profesional;@override $TratamientoRefCopyWith<$Res> get tratamiento;@override $PacienteRefCopyWith<$Res> get paciente;@override $CuponCitaCopyWith<$Res>? get cupon;

}
/// @nodoc
class __$CitaCopyWithImpl<$Res>
    implements _$CitaCopyWith<$Res> {
  __$CitaCopyWithImpl(this._self, this._then);

  final _Cita _self;
  final $Res Function(_Cita) _then;

/// Create a copy of Cita
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? estado = null,Object? estadoTexto = null,Object? origen = null,Object? inicio = null,Object? fin = null,Object? inicioEstimado = freezed,Object? finEstimado = freezed,Object? retrasoMin = null,Object? minutosExtra = null,Object? inicioReal = freezed,Object? finReal = freezed,Object? recordatorioEnviadoEn = freezed,Object? asistenciaConfirmada = freezed,Object? llegadaEn = freezed,Object? profesional = freezed,Object? precioReferencia = freezed,Object? precioOfrecido = freezed,Object? precioAcordado = freezed,Object? precioTexto = freezed,Object? whatsappUrl = freezed,Object? tratamiento = null,Object? paciente = null,Object? cupon = freezed,}) {
  return _then(_Cita(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,estadoTexto: null == estadoTexto ? _self.estadoTexto : estadoTexto // ignore: cast_nullable_to_non_nullable
as String,origen: null == origen ? _self.origen : origen // ignore: cast_nullable_to_non_nullable
as String,inicio: null == inicio ? _self.inicio : inicio // ignore: cast_nullable_to_non_nullable
as String,fin: null == fin ? _self.fin : fin // ignore: cast_nullable_to_non_nullable
as String,inicioEstimado: freezed == inicioEstimado ? _self.inicioEstimado : inicioEstimado // ignore: cast_nullable_to_non_nullable
as String?,finEstimado: freezed == finEstimado ? _self.finEstimado : finEstimado // ignore: cast_nullable_to_non_nullable
as String?,retrasoMin: null == retrasoMin ? _self.retrasoMin : retrasoMin // ignore: cast_nullable_to_non_nullable
as int,minutosExtra: null == minutosExtra ? _self.minutosExtra : minutosExtra // ignore: cast_nullable_to_non_nullable
as int,inicioReal: freezed == inicioReal ? _self.inicioReal : inicioReal // ignore: cast_nullable_to_non_nullable
as String?,finReal: freezed == finReal ? _self.finReal : finReal // ignore: cast_nullable_to_non_nullable
as String?,recordatorioEnviadoEn: freezed == recordatorioEnviadoEn ? _self.recordatorioEnviadoEn : recordatorioEnviadoEn // ignore: cast_nullable_to_non_nullable
as String?,asistenciaConfirmada: freezed == asistenciaConfirmada ? _self.asistenciaConfirmada : asistenciaConfirmada // ignore: cast_nullable_to_non_nullable
as bool?,llegadaEn: freezed == llegadaEn ? _self.llegadaEn : llegadaEn // ignore: cast_nullable_to_non_nullable
as String?,profesional: freezed == profesional ? _self.profesional : profesional // ignore: cast_nullable_to_non_nullable
as ProfesionalRef?,precioReferencia: freezed == precioReferencia ? _self.precioReferencia : precioReferencia // ignore: cast_nullable_to_non_nullable
as int?,precioOfrecido: freezed == precioOfrecido ? _self.precioOfrecido : precioOfrecido // ignore: cast_nullable_to_non_nullable
as int?,precioAcordado: freezed == precioAcordado ? _self.precioAcordado : precioAcordado // ignore: cast_nullable_to_non_nullable
as int?,precioTexto: freezed == precioTexto ? _self.precioTexto : precioTexto // ignore: cast_nullable_to_non_nullable
as String?,whatsappUrl: freezed == whatsappUrl ? _self.whatsappUrl : whatsappUrl // ignore: cast_nullable_to_non_nullable
as String?,tratamiento: null == tratamiento ? _self.tratamiento : tratamiento // ignore: cast_nullable_to_non_nullable
as TratamientoRef,paciente: null == paciente ? _self.paciente : paciente // ignore: cast_nullable_to_non_nullable
as PacienteRef,cupon: freezed == cupon ? _self.cupon : cupon // ignore: cast_nullable_to_non_nullable
as CuponCita?,
  ));
}

/// Create a copy of Cita
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfesionalRefCopyWith<$Res>? get profesional {
    if (_self.profesional == null) {
    return null;
  }

  return $ProfesionalRefCopyWith<$Res>(_self.profesional!, (value) {
    return _then(_self.copyWith(profesional: value));
  });
}/// Create a copy of Cita
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TratamientoRefCopyWith<$Res> get tratamiento {
  
  return $TratamientoRefCopyWith<$Res>(_self.tratamiento, (value) {
    return _then(_self.copyWith(tratamiento: value));
  });
}/// Create a copy of Cita
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PacienteRefCopyWith<$Res> get paciente {
  
  return $PacienteRefCopyWith<$Res>(_self.paciente, (value) {
    return _then(_self.copyWith(paciente: value));
  });
}/// Create a copy of Cita
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CuponCitaCopyWith<$Res>? get cupon {
    if (_self.cupon == null) {
    return null;
  }

  return $CuponCitaCopyWith<$Res>(_self.cupon!, (value) {
    return _then(_self.copyWith(cupon: value));
  });
}
}


/// @nodoc
mixin _$Hueco {

 String get inicio; String get fin;
/// Create a copy of Hueco
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HuecoCopyWith<Hueco> get copyWith => _$HuecoCopyWithImpl<Hueco>(this as Hueco, _$identity);

  /// Serializes this Hueco to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Hueco&&(identical(other.inicio, inicio) || other.inicio == inicio)&&(identical(other.fin, fin) || other.fin == fin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,inicio,fin);

@override
String toString() {
  return 'Hueco(inicio: $inicio, fin: $fin)';
}


}

/// @nodoc
abstract mixin class $HuecoCopyWith<$Res>  {
  factory $HuecoCopyWith(Hueco value, $Res Function(Hueco) _then) = _$HuecoCopyWithImpl;
@useResult
$Res call({
 String inicio, String fin
});




}
/// @nodoc
class _$HuecoCopyWithImpl<$Res>
    implements $HuecoCopyWith<$Res> {
  _$HuecoCopyWithImpl(this._self, this._then);

  final Hueco _self;
  final $Res Function(Hueco) _then;

/// Create a copy of Hueco
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? inicio = null,Object? fin = null,}) {
  return _then(_self.copyWith(
inicio: null == inicio ? _self.inicio : inicio // ignore: cast_nullable_to_non_nullable
as String,fin: null == fin ? _self.fin : fin // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Hueco].
extension HuecoPatterns on Hueco {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Hueco value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Hueco() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Hueco value)  $default,){
final _that = this;
switch (_that) {
case _Hueco():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Hueco value)?  $default,){
final _that = this;
switch (_that) {
case _Hueco() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String inicio,  String fin)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Hueco() when $default != null:
return $default(_that.inicio,_that.fin);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String inicio,  String fin)  $default,) {final _that = this;
switch (_that) {
case _Hueco():
return $default(_that.inicio,_that.fin);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String inicio,  String fin)?  $default,) {final _that = this;
switch (_that) {
case _Hueco() when $default != null:
return $default(_that.inicio,_that.fin);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Hueco implements Hueco {
  const _Hueco({required this.inicio, required this.fin});
  factory _Hueco.fromJson(Map<String, dynamic> json) => _$HuecoFromJson(json);

@override final  String inicio;
@override final  String fin;

/// Create a copy of Hueco
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HuecoCopyWith<_Hueco> get copyWith => __$HuecoCopyWithImpl<_Hueco>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HuecoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Hueco&&(identical(other.inicio, inicio) || other.inicio == inicio)&&(identical(other.fin, fin) || other.fin == fin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,inicio,fin);

@override
String toString() {
  return 'Hueco(inicio: $inicio, fin: $fin)';
}


}

/// @nodoc
abstract mixin class _$HuecoCopyWith<$Res> implements $HuecoCopyWith<$Res> {
  factory _$HuecoCopyWith(_Hueco value, $Res Function(_Hueco) _then) = __$HuecoCopyWithImpl;
@override @useResult
$Res call({
 String inicio, String fin
});




}
/// @nodoc
class __$HuecoCopyWithImpl<$Res>
    implements _$HuecoCopyWith<$Res> {
  __$HuecoCopyWithImpl(this._self, this._then);

  final _Hueco _self;
  final $Res Function(_Hueco) _then;

/// Create a copy of Hueco
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? inicio = null,Object? fin = null,}) {
  return _then(_Hueco(
inicio: null == inicio ? _self.inicio : inicio // ignore: cast_nullable_to_non_nullable
as String,fin: null == fin ? _self.fin : fin // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$Turno {

 String get nombre; int get desde; int get hasta; int get citas; int get porConfirmar;
/// Create a copy of Turno
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TurnoCopyWith<Turno> get copyWith => _$TurnoCopyWithImpl<Turno>(this as Turno, _$identity);

  /// Serializes this Turno to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Turno&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.desde, desde) || other.desde == desde)&&(identical(other.hasta, hasta) || other.hasta == hasta)&&(identical(other.citas, citas) || other.citas == citas)&&(identical(other.porConfirmar, porConfirmar) || other.porConfirmar == porConfirmar));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,nombre,desde,hasta,citas,porConfirmar);

@override
String toString() {
  return 'Turno(nombre: $nombre, desde: $desde, hasta: $hasta, citas: $citas, porConfirmar: $porConfirmar)';
}


}

/// @nodoc
abstract mixin class $TurnoCopyWith<$Res>  {
  factory $TurnoCopyWith(Turno value, $Res Function(Turno) _then) = _$TurnoCopyWithImpl;
@useResult
$Res call({
 String nombre, int desde, int hasta, int citas, int porConfirmar
});




}
/// @nodoc
class _$TurnoCopyWithImpl<$Res>
    implements $TurnoCopyWith<$Res> {
  _$TurnoCopyWithImpl(this._self, this._then);

  final Turno _self;
  final $Res Function(Turno) _then;

/// Create a copy of Turno
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nombre = null,Object? desde = null,Object? hasta = null,Object? citas = null,Object? porConfirmar = null,}) {
  return _then(_self.copyWith(
nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,desde: null == desde ? _self.desde : desde // ignore: cast_nullable_to_non_nullable
as int,hasta: null == hasta ? _self.hasta : hasta // ignore: cast_nullable_to_non_nullable
as int,citas: null == citas ? _self.citas : citas // ignore: cast_nullable_to_non_nullable
as int,porConfirmar: null == porConfirmar ? _self.porConfirmar : porConfirmar // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Turno].
extension TurnoPatterns on Turno {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Turno value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Turno() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Turno value)  $default,){
final _that = this;
switch (_that) {
case _Turno():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Turno value)?  $default,){
final _that = this;
switch (_that) {
case _Turno() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String nombre,  int desde,  int hasta,  int citas,  int porConfirmar)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Turno() when $default != null:
return $default(_that.nombre,_that.desde,_that.hasta,_that.citas,_that.porConfirmar);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String nombre,  int desde,  int hasta,  int citas,  int porConfirmar)  $default,) {final _that = this;
switch (_that) {
case _Turno():
return $default(_that.nombre,_that.desde,_that.hasta,_that.citas,_that.porConfirmar);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String nombre,  int desde,  int hasta,  int citas,  int porConfirmar)?  $default,) {final _that = this;
switch (_that) {
case _Turno() when $default != null:
return $default(_that.nombre,_that.desde,_that.hasta,_that.citas,_that.porConfirmar);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Turno extends Turno {
  const _Turno({required this.nombre, required this.desde, required this.hasta, this.citas = 0, this.porConfirmar = 0}): super._();
  factory _Turno.fromJson(Map<String, dynamic> json) => _$TurnoFromJson(json);

@override final  String nombre;
@override final  int desde;
@override final  int hasta;
@override@JsonKey() final  int citas;
@override@JsonKey() final  int porConfirmar;

/// Create a copy of Turno
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TurnoCopyWith<_Turno> get copyWith => __$TurnoCopyWithImpl<_Turno>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TurnoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Turno&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.desde, desde) || other.desde == desde)&&(identical(other.hasta, hasta) || other.hasta == hasta)&&(identical(other.citas, citas) || other.citas == citas)&&(identical(other.porConfirmar, porConfirmar) || other.porConfirmar == porConfirmar));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,nombre,desde,hasta,citas,porConfirmar);

@override
String toString() {
  return 'Turno(nombre: $nombre, desde: $desde, hasta: $hasta, citas: $citas, porConfirmar: $porConfirmar)';
}


}

/// @nodoc
abstract mixin class _$TurnoCopyWith<$Res> implements $TurnoCopyWith<$Res> {
  factory _$TurnoCopyWith(_Turno value, $Res Function(_Turno) _then) = __$TurnoCopyWithImpl;
@override @useResult
$Res call({
 String nombre, int desde, int hasta, int citas, int porConfirmar
});




}
/// @nodoc
class __$TurnoCopyWithImpl<$Res>
    implements _$TurnoCopyWith<$Res> {
  __$TurnoCopyWithImpl(this._self, this._then);

  final _Turno _self;
  final $Res Function(_Turno) _then;

/// Create a copy of Turno
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nombre = null,Object? desde = null,Object? hasta = null,Object? citas = null,Object? porConfirmar = null,}) {
  return _then(_Turno(
nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,desde: null == desde ? _self.desde : desde // ignore: cast_nullable_to_non_nullable
as int,hasta: null == hasta ? _self.hasta : hasta // ignore: cast_nullable_to_non_nullable
as int,citas: null == citas ? _self.citas : citas // ignore: cast_nullable_to_non_nullable
as int,porConfirmar: null == porConfirmar ? _self.porConfirmar : porConfirmar // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$Agenda {

 String get fecha; int get retrasoMin; int get porAprobar; List<Cita> get citas; List<Hueco> get huecos; List<Turno> get turnos; String? get generadoEn;
/// Create a copy of Agenda
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgendaCopyWith<Agenda> get copyWith => _$AgendaCopyWithImpl<Agenda>(this as Agenda, _$identity);

  /// Serializes this Agenda to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Agenda&&(identical(other.fecha, fecha) || other.fecha == fecha)&&(identical(other.retrasoMin, retrasoMin) || other.retrasoMin == retrasoMin)&&(identical(other.porAprobar, porAprobar) || other.porAprobar == porAprobar)&&const DeepCollectionEquality().equals(other.citas, citas)&&const DeepCollectionEquality().equals(other.huecos, huecos)&&const DeepCollectionEquality().equals(other.turnos, turnos)&&(identical(other.generadoEn, generadoEn) || other.generadoEn == generadoEn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fecha,retrasoMin,porAprobar,const DeepCollectionEquality().hash(citas),const DeepCollectionEquality().hash(huecos),const DeepCollectionEquality().hash(turnos),generadoEn);

@override
String toString() {
  return 'Agenda(fecha: $fecha, retrasoMin: $retrasoMin, porAprobar: $porAprobar, citas: $citas, huecos: $huecos, turnos: $turnos, generadoEn: $generadoEn)';
}


}

/// @nodoc
abstract mixin class $AgendaCopyWith<$Res>  {
  factory $AgendaCopyWith(Agenda value, $Res Function(Agenda) _then) = _$AgendaCopyWithImpl;
@useResult
$Res call({
 String fecha, int retrasoMin, int porAprobar, List<Cita> citas, List<Hueco> huecos, List<Turno> turnos, String? generadoEn
});




}
/// @nodoc
class _$AgendaCopyWithImpl<$Res>
    implements $AgendaCopyWith<$Res> {
  _$AgendaCopyWithImpl(this._self, this._then);

  final Agenda _self;
  final $Res Function(Agenda) _then;

/// Create a copy of Agenda
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fecha = null,Object? retrasoMin = null,Object? porAprobar = null,Object? citas = null,Object? huecos = null,Object? turnos = null,Object? generadoEn = freezed,}) {
  return _then(_self.copyWith(
fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as String,retrasoMin: null == retrasoMin ? _self.retrasoMin : retrasoMin // ignore: cast_nullable_to_non_nullable
as int,porAprobar: null == porAprobar ? _self.porAprobar : porAprobar // ignore: cast_nullable_to_non_nullable
as int,citas: null == citas ? _self.citas : citas // ignore: cast_nullable_to_non_nullable
as List<Cita>,huecos: null == huecos ? _self.huecos : huecos // ignore: cast_nullable_to_non_nullable
as List<Hueco>,turnos: null == turnos ? _self.turnos : turnos // ignore: cast_nullable_to_non_nullable
as List<Turno>,generadoEn: freezed == generadoEn ? _self.generadoEn : generadoEn // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Agenda].
extension AgendaPatterns on Agenda {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Agenda value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Agenda() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Agenda value)  $default,){
final _that = this;
switch (_that) {
case _Agenda():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Agenda value)?  $default,){
final _that = this;
switch (_that) {
case _Agenda() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fecha,  int retrasoMin,  int porAprobar,  List<Cita> citas,  List<Hueco> huecos,  List<Turno> turnos,  String? generadoEn)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Agenda() when $default != null:
return $default(_that.fecha,_that.retrasoMin,_that.porAprobar,_that.citas,_that.huecos,_that.turnos,_that.generadoEn);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fecha,  int retrasoMin,  int porAprobar,  List<Cita> citas,  List<Hueco> huecos,  List<Turno> turnos,  String? generadoEn)  $default,) {final _that = this;
switch (_that) {
case _Agenda():
return $default(_that.fecha,_that.retrasoMin,_that.porAprobar,_that.citas,_that.huecos,_that.turnos,_that.generadoEn);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fecha,  int retrasoMin,  int porAprobar,  List<Cita> citas,  List<Hueco> huecos,  List<Turno> turnos,  String? generadoEn)?  $default,) {final _that = this;
switch (_that) {
case _Agenda() when $default != null:
return $default(_that.fecha,_that.retrasoMin,_that.porAprobar,_that.citas,_that.huecos,_that.turnos,_that.generadoEn);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Agenda implements Agenda {
  const _Agenda({required this.fecha, this.retrasoMin = 0, this.porAprobar = 0, final  List<Cita> citas = const [], final  List<Hueco> huecos = const [], final  List<Turno> turnos = const [], this.generadoEn}): _citas = citas,_huecos = huecos,_turnos = turnos;
  factory _Agenda.fromJson(Map<String, dynamic> json) => _$AgendaFromJson(json);

@override final  String fecha;
@override@JsonKey() final  int retrasoMin;
@override@JsonKey() final  int porAprobar;
 final  List<Cita> _citas;
@override@JsonKey() List<Cita> get citas {
  if (_citas is EqualUnmodifiableListView) return _citas;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_citas);
}

 final  List<Hueco> _huecos;
@override@JsonKey() List<Hueco> get huecos {
  if (_huecos is EqualUnmodifiableListView) return _huecos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_huecos);
}

 final  List<Turno> _turnos;
@override@JsonKey() List<Turno> get turnos {
  if (_turnos is EqualUnmodifiableListView) return _turnos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_turnos);
}

@override final  String? generadoEn;

/// Create a copy of Agenda
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgendaCopyWith<_Agenda> get copyWith => __$AgendaCopyWithImpl<_Agenda>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgendaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Agenda&&(identical(other.fecha, fecha) || other.fecha == fecha)&&(identical(other.retrasoMin, retrasoMin) || other.retrasoMin == retrasoMin)&&(identical(other.porAprobar, porAprobar) || other.porAprobar == porAprobar)&&const DeepCollectionEquality().equals(other._citas, _citas)&&const DeepCollectionEquality().equals(other._huecos, _huecos)&&const DeepCollectionEquality().equals(other._turnos, _turnos)&&(identical(other.generadoEn, generadoEn) || other.generadoEn == generadoEn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fecha,retrasoMin,porAprobar,const DeepCollectionEquality().hash(_citas),const DeepCollectionEquality().hash(_huecos),const DeepCollectionEquality().hash(_turnos),generadoEn);

@override
String toString() {
  return 'Agenda(fecha: $fecha, retrasoMin: $retrasoMin, porAprobar: $porAprobar, citas: $citas, huecos: $huecos, turnos: $turnos, generadoEn: $generadoEn)';
}


}

/// @nodoc
abstract mixin class _$AgendaCopyWith<$Res> implements $AgendaCopyWith<$Res> {
  factory _$AgendaCopyWith(_Agenda value, $Res Function(_Agenda) _then) = __$AgendaCopyWithImpl;
@override @useResult
$Res call({
 String fecha, int retrasoMin, int porAprobar, List<Cita> citas, List<Hueco> huecos, List<Turno> turnos, String? generadoEn
});




}
/// @nodoc
class __$AgendaCopyWithImpl<$Res>
    implements _$AgendaCopyWith<$Res> {
  __$AgendaCopyWithImpl(this._self, this._then);

  final _Agenda _self;
  final $Res Function(_Agenda) _then;

/// Create a copy of Agenda
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fecha = null,Object? retrasoMin = null,Object? porAprobar = null,Object? citas = null,Object? huecos = null,Object? turnos = null,Object? generadoEn = freezed,}) {
  return _then(_Agenda(
fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as String,retrasoMin: null == retrasoMin ? _self.retrasoMin : retrasoMin // ignore: cast_nullable_to_non_nullable
as int,porAprobar: null == porAprobar ? _self.porAprobar : porAprobar // ignore: cast_nullable_to_non_nullable
as int,citas: null == citas ? _self._citas : citas // ignore: cast_nullable_to_non_nullable
as List<Cita>,huecos: null == huecos ? _self._huecos : huecos // ignore: cast_nullable_to_non_nullable
as List<Hueco>,turnos: null == turnos ? _self._turnos : turnos // ignore: cast_nullable_to_non_nullable
as List<Turno>,generadoEn: freezed == generadoEn ? _self.generadoEn : generadoEn // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Bloqueo {

 int get id; String get inicio; String get fin; String get motivo;
/// Create a copy of Bloqueo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BloqueoCopyWith<Bloqueo> get copyWith => _$BloqueoCopyWithImpl<Bloqueo>(this as Bloqueo, _$identity);

  /// Serializes this Bloqueo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Bloqueo&&(identical(other.id, id) || other.id == id)&&(identical(other.inicio, inicio) || other.inicio == inicio)&&(identical(other.fin, fin) || other.fin == fin)&&(identical(other.motivo, motivo) || other.motivo == motivo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,inicio,fin,motivo);

@override
String toString() {
  return 'Bloqueo(id: $id, inicio: $inicio, fin: $fin, motivo: $motivo)';
}


}

/// @nodoc
abstract mixin class $BloqueoCopyWith<$Res>  {
  factory $BloqueoCopyWith(Bloqueo value, $Res Function(Bloqueo) _then) = _$BloqueoCopyWithImpl;
@useResult
$Res call({
 int id, String inicio, String fin, String motivo
});




}
/// @nodoc
class _$BloqueoCopyWithImpl<$Res>
    implements $BloqueoCopyWith<$Res> {
  _$BloqueoCopyWithImpl(this._self, this._then);

  final Bloqueo _self;
  final $Res Function(Bloqueo) _then;

/// Create a copy of Bloqueo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? inicio = null,Object? fin = null,Object? motivo = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,inicio: null == inicio ? _self.inicio : inicio // ignore: cast_nullable_to_non_nullable
as String,fin: null == fin ? _self.fin : fin // ignore: cast_nullable_to_non_nullable
as String,motivo: null == motivo ? _self.motivo : motivo // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Bloqueo].
extension BloqueoPatterns on Bloqueo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Bloqueo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Bloqueo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Bloqueo value)  $default,){
final _that = this;
switch (_that) {
case _Bloqueo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Bloqueo value)?  $default,){
final _that = this;
switch (_that) {
case _Bloqueo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String inicio,  String fin,  String motivo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Bloqueo() when $default != null:
return $default(_that.id,_that.inicio,_that.fin,_that.motivo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String inicio,  String fin,  String motivo)  $default,) {final _that = this;
switch (_that) {
case _Bloqueo():
return $default(_that.id,_that.inicio,_that.fin,_that.motivo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String inicio,  String fin,  String motivo)?  $default,) {final _that = this;
switch (_that) {
case _Bloqueo() when $default != null:
return $default(_that.id,_that.inicio,_that.fin,_that.motivo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Bloqueo implements Bloqueo {
  const _Bloqueo({required this.id, required this.inicio, required this.fin, this.motivo = ''});
  factory _Bloqueo.fromJson(Map<String, dynamic> json) => _$BloqueoFromJson(json);

@override final  int id;
@override final  String inicio;
@override final  String fin;
@override@JsonKey() final  String motivo;

/// Create a copy of Bloqueo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BloqueoCopyWith<_Bloqueo> get copyWith => __$BloqueoCopyWithImpl<_Bloqueo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BloqueoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Bloqueo&&(identical(other.id, id) || other.id == id)&&(identical(other.inicio, inicio) || other.inicio == inicio)&&(identical(other.fin, fin) || other.fin == fin)&&(identical(other.motivo, motivo) || other.motivo == motivo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,inicio,fin,motivo);

@override
String toString() {
  return 'Bloqueo(id: $id, inicio: $inicio, fin: $fin, motivo: $motivo)';
}


}

/// @nodoc
abstract mixin class _$BloqueoCopyWith<$Res> implements $BloqueoCopyWith<$Res> {
  factory _$BloqueoCopyWith(_Bloqueo value, $Res Function(_Bloqueo) _then) = __$BloqueoCopyWithImpl;
@override @useResult
$Res call({
 int id, String inicio, String fin, String motivo
});




}
/// @nodoc
class __$BloqueoCopyWithImpl<$Res>
    implements _$BloqueoCopyWith<$Res> {
  __$BloqueoCopyWithImpl(this._self, this._then);

  final _Bloqueo _self;
  final $Res Function(_Bloqueo) _then;

/// Create a copy of Bloqueo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? inicio = null,Object? fin = null,Object? motivo = null,}) {
  return _then(_Bloqueo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,inicio: null == inicio ? _self.inicio : inicio // ignore: cast_nullable_to_non_nullable
as String,fin: null == fin ? _self.fin : fin // ignore: cast_nullable_to_non_nullable
as String,motivo: null == motivo ? _self.motivo : motivo // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$DiaSemana {

 String get fecha; List<Cita> get citas; List<Bloqueo> get bloqueos; List<Turno> get turnos;
/// Create a copy of DiaSemana
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaSemanaCopyWith<DiaSemana> get copyWith => _$DiaSemanaCopyWithImpl<DiaSemana>(this as DiaSemana, _$identity);

  /// Serializes this DiaSemana to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaSemana&&(identical(other.fecha, fecha) || other.fecha == fecha)&&const DeepCollectionEquality().equals(other.citas, citas)&&const DeepCollectionEquality().equals(other.bloqueos, bloqueos)&&const DeepCollectionEquality().equals(other.turnos, turnos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fecha,const DeepCollectionEquality().hash(citas),const DeepCollectionEquality().hash(bloqueos),const DeepCollectionEquality().hash(turnos));

@override
String toString() {
  return 'DiaSemana(fecha: $fecha, citas: $citas, bloqueos: $bloqueos, turnos: $turnos)';
}


}

/// @nodoc
abstract mixin class $DiaSemanaCopyWith<$Res>  {
  factory $DiaSemanaCopyWith(DiaSemana value, $Res Function(DiaSemana) _then) = _$DiaSemanaCopyWithImpl;
@useResult
$Res call({
 String fecha, List<Cita> citas, List<Bloqueo> bloqueos, List<Turno> turnos
});




}
/// @nodoc
class _$DiaSemanaCopyWithImpl<$Res>
    implements $DiaSemanaCopyWith<$Res> {
  _$DiaSemanaCopyWithImpl(this._self, this._then);

  final DiaSemana _self;
  final $Res Function(DiaSemana) _then;

/// Create a copy of DiaSemana
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fecha = null,Object? citas = null,Object? bloqueos = null,Object? turnos = null,}) {
  return _then(_self.copyWith(
fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as String,citas: null == citas ? _self.citas : citas // ignore: cast_nullable_to_non_nullable
as List<Cita>,bloqueos: null == bloqueos ? _self.bloqueos : bloqueos // ignore: cast_nullable_to_non_nullable
as List<Bloqueo>,turnos: null == turnos ? _self.turnos : turnos // ignore: cast_nullable_to_non_nullable
as List<Turno>,
  ));
}

}


/// Adds pattern-matching-related methods to [DiaSemana].
extension DiaSemanaPatterns on DiaSemana {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiaSemana value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiaSemana() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiaSemana value)  $default,){
final _that = this;
switch (_that) {
case _DiaSemana():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiaSemana value)?  $default,){
final _that = this;
switch (_that) {
case _DiaSemana() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fecha,  List<Cita> citas,  List<Bloqueo> bloqueos,  List<Turno> turnos)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiaSemana() when $default != null:
return $default(_that.fecha,_that.citas,_that.bloqueos,_that.turnos);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fecha,  List<Cita> citas,  List<Bloqueo> bloqueos,  List<Turno> turnos)  $default,) {final _that = this;
switch (_that) {
case _DiaSemana():
return $default(_that.fecha,_that.citas,_that.bloqueos,_that.turnos);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fecha,  List<Cita> citas,  List<Bloqueo> bloqueos,  List<Turno> turnos)?  $default,) {final _that = this;
switch (_that) {
case _DiaSemana() when $default != null:
return $default(_that.fecha,_that.citas,_that.bloqueos,_that.turnos);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DiaSemana implements DiaSemana {
  const _DiaSemana({required this.fecha, final  List<Cita> citas = const [], final  List<Bloqueo> bloqueos = const [], final  List<Turno> turnos = const []}): _citas = citas,_bloqueos = bloqueos,_turnos = turnos;
  factory _DiaSemana.fromJson(Map<String, dynamic> json) => _$DiaSemanaFromJson(json);

@override final  String fecha;
 final  List<Cita> _citas;
@override@JsonKey() List<Cita> get citas {
  if (_citas is EqualUnmodifiableListView) return _citas;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_citas);
}

 final  List<Bloqueo> _bloqueos;
@override@JsonKey() List<Bloqueo> get bloqueos {
  if (_bloqueos is EqualUnmodifiableListView) return _bloqueos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bloqueos);
}

 final  List<Turno> _turnos;
@override@JsonKey() List<Turno> get turnos {
  if (_turnos is EqualUnmodifiableListView) return _turnos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_turnos);
}


/// Create a copy of DiaSemana
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiaSemanaCopyWith<_DiaSemana> get copyWith => __$DiaSemanaCopyWithImpl<_DiaSemana>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DiaSemanaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiaSemana&&(identical(other.fecha, fecha) || other.fecha == fecha)&&const DeepCollectionEquality().equals(other._citas, _citas)&&const DeepCollectionEquality().equals(other._bloqueos, _bloqueos)&&const DeepCollectionEquality().equals(other._turnos, _turnos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fecha,const DeepCollectionEquality().hash(_citas),const DeepCollectionEquality().hash(_bloqueos),const DeepCollectionEquality().hash(_turnos));

@override
String toString() {
  return 'DiaSemana(fecha: $fecha, citas: $citas, bloqueos: $bloqueos, turnos: $turnos)';
}


}

/// @nodoc
abstract mixin class _$DiaSemanaCopyWith<$Res> implements $DiaSemanaCopyWith<$Res> {
  factory _$DiaSemanaCopyWith(_DiaSemana value, $Res Function(_DiaSemana) _then) = __$DiaSemanaCopyWithImpl;
@override @useResult
$Res call({
 String fecha, List<Cita> citas, List<Bloqueo> bloqueos, List<Turno> turnos
});




}
/// @nodoc
class __$DiaSemanaCopyWithImpl<$Res>
    implements _$DiaSemanaCopyWith<$Res> {
  __$DiaSemanaCopyWithImpl(this._self, this._then);

  final _DiaSemana _self;
  final $Res Function(_DiaSemana) _then;

/// Create a copy of DiaSemana
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fecha = null,Object? citas = null,Object? bloqueos = null,Object? turnos = null,}) {
  return _then(_DiaSemana(
fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as String,citas: null == citas ? _self._citas : citas // ignore: cast_nullable_to_non_nullable
as List<Cita>,bloqueos: null == bloqueos ? _self._bloqueos : bloqueos // ignore: cast_nullable_to_non_nullable
as List<Bloqueo>,turnos: null == turnos ? _self._turnos : turnos // ignore: cast_nullable_to_non_nullable
as List<Turno>,
  ));
}


}


/// @nodoc
mixin _$DiaMes {

 String get fecha; int get citas; int get porConfirmar; bool get bloqueo;
/// Create a copy of DiaMes
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaMesCopyWith<DiaMes> get copyWith => _$DiaMesCopyWithImpl<DiaMes>(this as DiaMes, _$identity);

  /// Serializes this DiaMes to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaMes&&(identical(other.fecha, fecha) || other.fecha == fecha)&&(identical(other.citas, citas) || other.citas == citas)&&(identical(other.porConfirmar, porConfirmar) || other.porConfirmar == porConfirmar)&&(identical(other.bloqueo, bloqueo) || other.bloqueo == bloqueo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fecha,citas,porConfirmar,bloqueo);

@override
String toString() {
  return 'DiaMes(fecha: $fecha, citas: $citas, porConfirmar: $porConfirmar, bloqueo: $bloqueo)';
}


}

/// @nodoc
abstract mixin class $DiaMesCopyWith<$Res>  {
  factory $DiaMesCopyWith(DiaMes value, $Res Function(DiaMes) _then) = _$DiaMesCopyWithImpl;
@useResult
$Res call({
 String fecha, int citas, int porConfirmar, bool bloqueo
});




}
/// @nodoc
class _$DiaMesCopyWithImpl<$Res>
    implements $DiaMesCopyWith<$Res> {
  _$DiaMesCopyWithImpl(this._self, this._then);

  final DiaMes _self;
  final $Res Function(DiaMes) _then;

/// Create a copy of DiaMes
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fecha = null,Object? citas = null,Object? porConfirmar = null,Object? bloqueo = null,}) {
  return _then(_self.copyWith(
fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as String,citas: null == citas ? _self.citas : citas // ignore: cast_nullable_to_non_nullable
as int,porConfirmar: null == porConfirmar ? _self.porConfirmar : porConfirmar // ignore: cast_nullable_to_non_nullable
as int,bloqueo: null == bloqueo ? _self.bloqueo : bloqueo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DiaMes].
extension DiaMesPatterns on DiaMes {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiaMes value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiaMes() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiaMes value)  $default,){
final _that = this;
switch (_that) {
case _DiaMes():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiaMes value)?  $default,){
final _that = this;
switch (_that) {
case _DiaMes() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fecha,  int citas,  int porConfirmar,  bool bloqueo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiaMes() when $default != null:
return $default(_that.fecha,_that.citas,_that.porConfirmar,_that.bloqueo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fecha,  int citas,  int porConfirmar,  bool bloqueo)  $default,) {final _that = this;
switch (_that) {
case _DiaMes():
return $default(_that.fecha,_that.citas,_that.porConfirmar,_that.bloqueo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fecha,  int citas,  int porConfirmar,  bool bloqueo)?  $default,) {final _that = this;
switch (_that) {
case _DiaMes() when $default != null:
return $default(_that.fecha,_that.citas,_that.porConfirmar,_that.bloqueo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DiaMes implements DiaMes {
  const _DiaMes({required this.fecha, this.citas = 0, this.porConfirmar = 0, this.bloqueo = false});
  factory _DiaMes.fromJson(Map<String, dynamic> json) => _$DiaMesFromJson(json);

@override final  String fecha;
@override@JsonKey() final  int citas;
@override@JsonKey() final  int porConfirmar;
@override@JsonKey() final  bool bloqueo;

/// Create a copy of DiaMes
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiaMesCopyWith<_DiaMes> get copyWith => __$DiaMesCopyWithImpl<_DiaMes>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DiaMesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiaMes&&(identical(other.fecha, fecha) || other.fecha == fecha)&&(identical(other.citas, citas) || other.citas == citas)&&(identical(other.porConfirmar, porConfirmar) || other.porConfirmar == porConfirmar)&&(identical(other.bloqueo, bloqueo) || other.bloqueo == bloqueo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fecha,citas,porConfirmar,bloqueo);

@override
String toString() {
  return 'DiaMes(fecha: $fecha, citas: $citas, porConfirmar: $porConfirmar, bloqueo: $bloqueo)';
}


}

/// @nodoc
abstract mixin class _$DiaMesCopyWith<$Res> implements $DiaMesCopyWith<$Res> {
  factory _$DiaMesCopyWith(_DiaMes value, $Res Function(_DiaMes) _then) = __$DiaMesCopyWithImpl;
@override @useResult
$Res call({
 String fecha, int citas, int porConfirmar, bool bloqueo
});




}
/// @nodoc
class __$DiaMesCopyWithImpl<$Res>
    implements _$DiaMesCopyWith<$Res> {
  __$DiaMesCopyWithImpl(this._self, this._then);

  final _DiaMes _self;
  final $Res Function(_DiaMes) _then;

/// Create a copy of DiaMes
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fecha = null,Object? citas = null,Object? porConfirmar = null,Object? bloqueo = null,}) {
  return _then(_DiaMes(
fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as String,citas: null == citas ? _self.citas : citas // ignore: cast_nullable_to_non_nullable
as int,porConfirmar: null == porConfirmar ? _self.porConfirmar : porConfirmar // ignore: cast_nullable_to_non_nullable
as int,bloqueo: null == bloqueo ? _self.bloqueo : bloqueo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$Siguiente {

 int get citaId; String get paciente; String get inicio; String get whatsappUrl;
/// Create a copy of Siguiente
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SiguienteCopyWith<Siguiente> get copyWith => _$SiguienteCopyWithImpl<Siguiente>(this as Siguiente, _$identity);

  /// Serializes this Siguiente to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Siguiente&&(identical(other.citaId, citaId) || other.citaId == citaId)&&(identical(other.paciente, paciente) || other.paciente == paciente)&&(identical(other.inicio, inicio) || other.inicio == inicio)&&(identical(other.whatsappUrl, whatsappUrl) || other.whatsappUrl == whatsappUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,citaId,paciente,inicio,whatsappUrl);

@override
String toString() {
  return 'Siguiente(citaId: $citaId, paciente: $paciente, inicio: $inicio, whatsappUrl: $whatsappUrl)';
}


}

/// @nodoc
abstract mixin class $SiguienteCopyWith<$Res>  {
  factory $SiguienteCopyWith(Siguiente value, $Res Function(Siguiente) _then) = _$SiguienteCopyWithImpl;
@useResult
$Res call({
 int citaId, String paciente, String inicio, String whatsappUrl
});




}
/// @nodoc
class _$SiguienteCopyWithImpl<$Res>
    implements $SiguienteCopyWith<$Res> {
  _$SiguienteCopyWithImpl(this._self, this._then);

  final Siguiente _self;
  final $Res Function(Siguiente) _then;

/// Create a copy of Siguiente
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? citaId = null,Object? paciente = null,Object? inicio = null,Object? whatsappUrl = null,}) {
  return _then(_self.copyWith(
citaId: null == citaId ? _self.citaId : citaId // ignore: cast_nullable_to_non_nullable
as int,paciente: null == paciente ? _self.paciente : paciente // ignore: cast_nullable_to_non_nullable
as String,inicio: null == inicio ? _self.inicio : inicio // ignore: cast_nullable_to_non_nullable
as String,whatsappUrl: null == whatsappUrl ? _self.whatsappUrl : whatsappUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Siguiente].
extension SiguientePatterns on Siguiente {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Siguiente value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Siguiente() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Siguiente value)  $default,){
final _that = this;
switch (_that) {
case _Siguiente():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Siguiente value)?  $default,){
final _that = this;
switch (_that) {
case _Siguiente() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int citaId,  String paciente,  String inicio,  String whatsappUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Siguiente() when $default != null:
return $default(_that.citaId,_that.paciente,_that.inicio,_that.whatsappUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int citaId,  String paciente,  String inicio,  String whatsappUrl)  $default,) {final _that = this;
switch (_that) {
case _Siguiente():
return $default(_that.citaId,_that.paciente,_that.inicio,_that.whatsappUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int citaId,  String paciente,  String inicio,  String whatsappUrl)?  $default,) {final _that = this;
switch (_that) {
case _Siguiente() when $default != null:
return $default(_that.citaId,_that.paciente,_that.inicio,_that.whatsappUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Siguiente implements Siguiente {
  const _Siguiente({required this.citaId, required this.paciente, required this.inicio, required this.whatsappUrl});
  factory _Siguiente.fromJson(Map<String, dynamic> json) => _$SiguienteFromJson(json);

@override final  int citaId;
@override final  String paciente;
@override final  String inicio;
@override final  String whatsappUrl;

/// Create a copy of Siguiente
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SiguienteCopyWith<_Siguiente> get copyWith => __$SiguienteCopyWithImpl<_Siguiente>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SiguienteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Siguiente&&(identical(other.citaId, citaId) || other.citaId == citaId)&&(identical(other.paciente, paciente) || other.paciente == paciente)&&(identical(other.inicio, inicio) || other.inicio == inicio)&&(identical(other.whatsappUrl, whatsappUrl) || other.whatsappUrl == whatsappUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,citaId,paciente,inicio,whatsappUrl);

@override
String toString() {
  return 'Siguiente(citaId: $citaId, paciente: $paciente, inicio: $inicio, whatsappUrl: $whatsappUrl)';
}


}

/// @nodoc
abstract mixin class _$SiguienteCopyWith<$Res> implements $SiguienteCopyWith<$Res> {
  factory _$SiguienteCopyWith(_Siguiente value, $Res Function(_Siguiente) _then) = __$SiguienteCopyWithImpl;
@override @useResult
$Res call({
 int citaId, String paciente, String inicio, String whatsappUrl
});




}
/// @nodoc
class __$SiguienteCopyWithImpl<$Res>
    implements _$SiguienteCopyWith<$Res> {
  __$SiguienteCopyWithImpl(this._self, this._then);

  final _Siguiente _self;
  final $Res Function(_Siguiente) _then;

/// Create a copy of Siguiente
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? citaId = null,Object? paciente = null,Object? inicio = null,Object? whatsappUrl = null,}) {
  return _then(_Siguiente(
citaId: null == citaId ? _self.citaId : citaId // ignore: cast_nullable_to_non_nullable
as int,paciente: null == paciente ? _self.paciente : paciente // ignore: cast_nullable_to_non_nullable
as String,inicio: null == inicio ? _self.inicio : inicio // ignore: cast_nullable_to_non_nullable
as String,whatsappUrl: null == whatsappUrl ? _self.whatsappUrl : whatsappUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$DiaLibre {

 String get fecha; List<String> get horas;
/// Create a copy of DiaLibre
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiaLibreCopyWith<DiaLibre> get copyWith => _$DiaLibreCopyWithImpl<DiaLibre>(this as DiaLibre, _$identity);

  /// Serializes this DiaLibre to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaLibre&&(identical(other.fecha, fecha) || other.fecha == fecha)&&const DeepCollectionEquality().equals(other.horas, horas));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fecha,const DeepCollectionEquality().hash(horas));

@override
String toString() {
  return 'DiaLibre(fecha: $fecha, horas: $horas)';
}


}

/// @nodoc
abstract mixin class $DiaLibreCopyWith<$Res>  {
  factory $DiaLibreCopyWith(DiaLibre value, $Res Function(DiaLibre) _then) = _$DiaLibreCopyWithImpl;
@useResult
$Res call({
 String fecha, List<String> horas
});




}
/// @nodoc
class _$DiaLibreCopyWithImpl<$Res>
    implements $DiaLibreCopyWith<$Res> {
  _$DiaLibreCopyWithImpl(this._self, this._then);

  final DiaLibre _self;
  final $Res Function(DiaLibre) _then;

/// Create a copy of DiaLibre
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fecha = null,Object? horas = null,}) {
  return _then(_self.copyWith(
fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as String,horas: null == horas ? _self.horas : horas // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [DiaLibre].
extension DiaLibrePatterns on DiaLibre {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiaLibre value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiaLibre() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiaLibre value)  $default,){
final _that = this;
switch (_that) {
case _DiaLibre():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiaLibre value)?  $default,){
final _that = this;
switch (_that) {
case _DiaLibre() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fecha,  List<String> horas)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiaLibre() when $default != null:
return $default(_that.fecha,_that.horas);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fecha,  List<String> horas)  $default,) {final _that = this;
switch (_that) {
case _DiaLibre():
return $default(_that.fecha,_that.horas);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fecha,  List<String> horas)?  $default,) {final _that = this;
switch (_that) {
case _DiaLibre() when $default != null:
return $default(_that.fecha,_that.horas);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DiaLibre implements DiaLibre {
  const _DiaLibre({required this.fecha, required final  List<String> horas}): _horas = horas;
  factory _DiaLibre.fromJson(Map<String, dynamic> json) => _$DiaLibreFromJson(json);

@override final  String fecha;
 final  List<String> _horas;
@override List<String> get horas {
  if (_horas is EqualUnmodifiableListView) return _horas;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_horas);
}


/// Create a copy of DiaLibre
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiaLibreCopyWith<_DiaLibre> get copyWith => __$DiaLibreCopyWithImpl<_DiaLibre>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DiaLibreToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiaLibre&&(identical(other.fecha, fecha) || other.fecha == fecha)&&const DeepCollectionEquality().equals(other._horas, _horas));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fecha,const DeepCollectionEquality().hash(_horas));

@override
String toString() {
  return 'DiaLibre(fecha: $fecha, horas: $horas)';
}


}

/// @nodoc
abstract mixin class _$DiaLibreCopyWith<$Res> implements $DiaLibreCopyWith<$Res> {
  factory _$DiaLibreCopyWith(_DiaLibre value, $Res Function(_DiaLibre) _then) = __$DiaLibreCopyWithImpl;
@override @useResult
$Res call({
 String fecha, List<String> horas
});




}
/// @nodoc
class __$DiaLibreCopyWithImpl<$Res>
    implements _$DiaLibreCopyWith<$Res> {
  __$DiaLibreCopyWithImpl(this._self, this._then);

  final _DiaLibre _self;
  final $Res Function(_DiaLibre) _then;

/// Create a copy of DiaLibre
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fecha = null,Object? horas = null,}) {
  return _then(_DiaLibre(
fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as String,horas: null == horas ? _self._horas : horas // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$Tramo {

 int get diaSemana; String get horaInicio; String get horaFin;
/// Create a copy of Tramo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TramoCopyWith<Tramo> get copyWith => _$TramoCopyWithImpl<Tramo>(this as Tramo, _$identity);

  /// Serializes this Tramo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Tramo&&(identical(other.diaSemana, diaSemana) || other.diaSemana == diaSemana)&&(identical(other.horaInicio, horaInicio) || other.horaInicio == horaInicio)&&(identical(other.horaFin, horaFin) || other.horaFin == horaFin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,diaSemana,horaInicio,horaFin);

@override
String toString() {
  return 'Tramo(diaSemana: $diaSemana, horaInicio: $horaInicio, horaFin: $horaFin)';
}


}

/// @nodoc
abstract mixin class $TramoCopyWith<$Res>  {
  factory $TramoCopyWith(Tramo value, $Res Function(Tramo) _then) = _$TramoCopyWithImpl;
@useResult
$Res call({
 int diaSemana, String horaInicio, String horaFin
});




}
/// @nodoc
class _$TramoCopyWithImpl<$Res>
    implements $TramoCopyWith<$Res> {
  _$TramoCopyWithImpl(this._self, this._then);

  final Tramo _self;
  final $Res Function(Tramo) _then;

/// Create a copy of Tramo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? diaSemana = null,Object? horaInicio = null,Object? horaFin = null,}) {
  return _then(_self.copyWith(
diaSemana: null == diaSemana ? _self.diaSemana : diaSemana // ignore: cast_nullable_to_non_nullable
as int,horaInicio: null == horaInicio ? _self.horaInicio : horaInicio // ignore: cast_nullable_to_non_nullable
as String,horaFin: null == horaFin ? _self.horaFin : horaFin // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Tramo].
extension TramoPatterns on Tramo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Tramo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Tramo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Tramo value)  $default,){
final _that = this;
switch (_that) {
case _Tramo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Tramo value)?  $default,){
final _that = this;
switch (_that) {
case _Tramo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int diaSemana,  String horaInicio,  String horaFin)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Tramo() when $default != null:
return $default(_that.diaSemana,_that.horaInicio,_that.horaFin);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int diaSemana,  String horaInicio,  String horaFin)  $default,) {final _that = this;
switch (_that) {
case _Tramo():
return $default(_that.diaSemana,_that.horaInicio,_that.horaFin);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int diaSemana,  String horaInicio,  String horaFin)?  $default,) {final _that = this;
switch (_that) {
case _Tramo() when $default != null:
return $default(_that.diaSemana,_that.horaInicio,_that.horaFin);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Tramo implements Tramo {
  const _Tramo({required this.diaSemana, required this.horaInicio, required this.horaFin});
  factory _Tramo.fromJson(Map<String, dynamic> json) => _$TramoFromJson(json);

@override final  int diaSemana;
@override final  String horaInicio;
@override final  String horaFin;

/// Create a copy of Tramo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TramoCopyWith<_Tramo> get copyWith => __$TramoCopyWithImpl<_Tramo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TramoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Tramo&&(identical(other.diaSemana, diaSemana) || other.diaSemana == diaSemana)&&(identical(other.horaInicio, horaInicio) || other.horaInicio == horaInicio)&&(identical(other.horaFin, horaFin) || other.horaFin == horaFin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,diaSemana,horaInicio,horaFin);

@override
String toString() {
  return 'Tramo(diaSemana: $diaSemana, horaInicio: $horaInicio, horaFin: $horaFin)';
}


}

/// @nodoc
abstract mixin class _$TramoCopyWith<$Res> implements $TramoCopyWith<$Res> {
  factory _$TramoCopyWith(_Tramo value, $Res Function(_Tramo) _then) = __$TramoCopyWithImpl;
@override @useResult
$Res call({
 int diaSemana, String horaInicio, String horaFin
});




}
/// @nodoc
class __$TramoCopyWithImpl<$Res>
    implements _$TramoCopyWith<$Res> {
  __$TramoCopyWithImpl(this._self, this._then);

  final _Tramo _self;
  final $Res Function(_Tramo) _then;

/// Create a copy of Tramo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? diaSemana = null,Object? horaInicio = null,Object? horaFin = null,}) {
  return _then(_Tramo(
diaSemana: null == diaSemana ? _self.diaSemana : diaSemana // ignore: cast_nullable_to_non_nullable
as int,horaInicio: null == horaInicio ? _self.horaInicio : horaInicio // ignore: cast_nullable_to_non_nullable
as String,horaFin: null == horaFin ? _self.horaFin : horaFin // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$Tratamiento {

 int? get id; String get nombre; String get motivoPaciente; String get descripcion; String get indicaciones; int get duracionMin; int get margenMin; String? get precioDesde; bool get reservable; bool get visible; int get orden;/// Mediana de lo que de verdad duraron las últimas citas terminadas (Iniciar → Terminar).
 int? get duracionRealMin; int get duracionRealCitas;
/// Create a copy of Tratamiento
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TratamientoCopyWith<Tratamiento> get copyWith => _$TratamientoCopyWithImpl<Tratamiento>(this as Tratamiento, _$identity);

  /// Serializes this Tratamiento to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Tratamiento&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.motivoPaciente, motivoPaciente) || other.motivoPaciente == motivoPaciente)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.indicaciones, indicaciones) || other.indicaciones == indicaciones)&&(identical(other.duracionMin, duracionMin) || other.duracionMin == duracionMin)&&(identical(other.margenMin, margenMin) || other.margenMin == margenMin)&&(identical(other.precioDesde, precioDesde) || other.precioDesde == precioDesde)&&(identical(other.reservable, reservable) || other.reservable == reservable)&&(identical(other.visible, visible) || other.visible == visible)&&(identical(other.orden, orden) || other.orden == orden)&&(identical(other.duracionRealMin, duracionRealMin) || other.duracionRealMin == duracionRealMin)&&(identical(other.duracionRealCitas, duracionRealCitas) || other.duracionRealCitas == duracionRealCitas));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre,motivoPaciente,descripcion,indicaciones,duracionMin,margenMin,precioDesde,reservable,visible,orden,duracionRealMin,duracionRealCitas);

@override
String toString() {
  return 'Tratamiento(id: $id, nombre: $nombre, motivoPaciente: $motivoPaciente, descripcion: $descripcion, indicaciones: $indicaciones, duracionMin: $duracionMin, margenMin: $margenMin, precioDesde: $precioDesde, reservable: $reservable, visible: $visible, orden: $orden, duracionRealMin: $duracionRealMin, duracionRealCitas: $duracionRealCitas)';
}


}

/// @nodoc
abstract mixin class $TratamientoCopyWith<$Res>  {
  factory $TratamientoCopyWith(Tratamiento value, $Res Function(Tratamiento) _then) = _$TratamientoCopyWithImpl;
@useResult
$Res call({
 int? id, String nombre, String motivoPaciente, String descripcion, String indicaciones, int duracionMin, int margenMin, String? precioDesde, bool reservable, bool visible, int orden, int? duracionRealMin, int duracionRealCitas
});




}
/// @nodoc
class _$TratamientoCopyWithImpl<$Res>
    implements $TratamientoCopyWith<$Res> {
  _$TratamientoCopyWithImpl(this._self, this._then);

  final Tratamiento _self;
  final $Res Function(Tratamiento) _then;

/// Create a copy of Tratamiento
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? nombre = null,Object? motivoPaciente = null,Object? descripcion = null,Object? indicaciones = null,Object? duracionMin = null,Object? margenMin = null,Object? precioDesde = freezed,Object? reservable = null,Object? visible = null,Object? orden = null,Object? duracionRealMin = freezed,Object? duracionRealCitas = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,motivoPaciente: null == motivoPaciente ? _self.motivoPaciente : motivoPaciente // ignore: cast_nullable_to_non_nullable
as String,descripcion: null == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String,indicaciones: null == indicaciones ? _self.indicaciones : indicaciones // ignore: cast_nullable_to_non_nullable
as String,duracionMin: null == duracionMin ? _self.duracionMin : duracionMin // ignore: cast_nullable_to_non_nullable
as int,margenMin: null == margenMin ? _self.margenMin : margenMin // ignore: cast_nullable_to_non_nullable
as int,precioDesde: freezed == precioDesde ? _self.precioDesde : precioDesde // ignore: cast_nullable_to_non_nullable
as String?,reservable: null == reservable ? _self.reservable : reservable // ignore: cast_nullable_to_non_nullable
as bool,visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,orden: null == orden ? _self.orden : orden // ignore: cast_nullable_to_non_nullable
as int,duracionRealMin: freezed == duracionRealMin ? _self.duracionRealMin : duracionRealMin // ignore: cast_nullable_to_non_nullable
as int?,duracionRealCitas: null == duracionRealCitas ? _self.duracionRealCitas : duracionRealCitas // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Tratamiento].
extension TratamientoPatterns on Tratamiento {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Tratamiento value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Tratamiento() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Tratamiento value)  $default,){
final _that = this;
switch (_that) {
case _Tratamiento():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Tratamiento value)?  $default,){
final _that = this;
switch (_that) {
case _Tratamiento() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  String nombre,  String motivoPaciente,  String descripcion,  String indicaciones,  int duracionMin,  int margenMin,  String? precioDesde,  bool reservable,  bool visible,  int orden,  int? duracionRealMin,  int duracionRealCitas)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Tratamiento() when $default != null:
return $default(_that.id,_that.nombre,_that.motivoPaciente,_that.descripcion,_that.indicaciones,_that.duracionMin,_that.margenMin,_that.precioDesde,_that.reservable,_that.visible,_that.orden,_that.duracionRealMin,_that.duracionRealCitas);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  String nombre,  String motivoPaciente,  String descripcion,  String indicaciones,  int duracionMin,  int margenMin,  String? precioDesde,  bool reservable,  bool visible,  int orden,  int? duracionRealMin,  int duracionRealCitas)  $default,) {final _that = this;
switch (_that) {
case _Tratamiento():
return $default(_that.id,_that.nombre,_that.motivoPaciente,_that.descripcion,_that.indicaciones,_that.duracionMin,_that.margenMin,_that.precioDesde,_that.reservable,_that.visible,_that.orden,_that.duracionRealMin,_that.duracionRealCitas);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  String nombre,  String motivoPaciente,  String descripcion,  String indicaciones,  int duracionMin,  int margenMin,  String? precioDesde,  bool reservable,  bool visible,  int orden,  int? duracionRealMin,  int duracionRealCitas)?  $default,) {final _that = this;
switch (_that) {
case _Tratamiento() when $default != null:
return $default(_that.id,_that.nombre,_that.motivoPaciente,_that.descripcion,_that.indicaciones,_that.duracionMin,_that.margenMin,_that.precioDesde,_that.reservable,_that.visible,_that.orden,_that.duracionRealMin,_that.duracionRealCitas);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Tratamiento implements Tratamiento {
  const _Tratamiento({this.id, required this.nombre, this.motivoPaciente = '', this.descripcion = '', this.indicaciones = '', this.duracionMin = 30, this.margenMin = 0, this.precioDesde, this.reservable = true, this.visible = true, this.orden = 0, this.duracionRealMin, this.duracionRealCitas = 0});
  factory _Tratamiento.fromJson(Map<String, dynamic> json) => _$TratamientoFromJson(json);

@override final  int? id;
@override final  String nombre;
@override@JsonKey() final  String motivoPaciente;
@override@JsonKey() final  String descripcion;
@override@JsonKey() final  String indicaciones;
@override@JsonKey() final  int duracionMin;
@override@JsonKey() final  int margenMin;
@override final  String? precioDesde;
@override@JsonKey() final  bool reservable;
@override@JsonKey() final  bool visible;
@override@JsonKey() final  int orden;
/// Mediana de lo que de verdad duraron las últimas citas terminadas (Iniciar → Terminar).
@override final  int? duracionRealMin;
@override@JsonKey() final  int duracionRealCitas;

/// Create a copy of Tratamiento
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TratamientoCopyWith<_Tratamiento> get copyWith => __$TratamientoCopyWithImpl<_Tratamiento>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TratamientoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Tratamiento&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.motivoPaciente, motivoPaciente) || other.motivoPaciente == motivoPaciente)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.indicaciones, indicaciones) || other.indicaciones == indicaciones)&&(identical(other.duracionMin, duracionMin) || other.duracionMin == duracionMin)&&(identical(other.margenMin, margenMin) || other.margenMin == margenMin)&&(identical(other.precioDesde, precioDesde) || other.precioDesde == precioDesde)&&(identical(other.reservable, reservable) || other.reservable == reservable)&&(identical(other.visible, visible) || other.visible == visible)&&(identical(other.orden, orden) || other.orden == orden)&&(identical(other.duracionRealMin, duracionRealMin) || other.duracionRealMin == duracionRealMin)&&(identical(other.duracionRealCitas, duracionRealCitas) || other.duracionRealCitas == duracionRealCitas));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre,motivoPaciente,descripcion,indicaciones,duracionMin,margenMin,precioDesde,reservable,visible,orden,duracionRealMin,duracionRealCitas);

@override
String toString() {
  return 'Tratamiento(id: $id, nombre: $nombre, motivoPaciente: $motivoPaciente, descripcion: $descripcion, indicaciones: $indicaciones, duracionMin: $duracionMin, margenMin: $margenMin, precioDesde: $precioDesde, reservable: $reservable, visible: $visible, orden: $orden, duracionRealMin: $duracionRealMin, duracionRealCitas: $duracionRealCitas)';
}


}

/// @nodoc
abstract mixin class _$TratamientoCopyWith<$Res> implements $TratamientoCopyWith<$Res> {
  factory _$TratamientoCopyWith(_Tratamiento value, $Res Function(_Tratamiento) _then) = __$TratamientoCopyWithImpl;
@override @useResult
$Res call({
 int? id, String nombre, String motivoPaciente, String descripcion, String indicaciones, int duracionMin, int margenMin, String? precioDesde, bool reservable, bool visible, int orden, int? duracionRealMin, int duracionRealCitas
});




}
/// @nodoc
class __$TratamientoCopyWithImpl<$Res>
    implements _$TratamientoCopyWith<$Res> {
  __$TratamientoCopyWithImpl(this._self, this._then);

  final _Tratamiento _self;
  final $Res Function(_Tratamiento) _then;

/// Create a copy of Tratamiento
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? nombre = null,Object? motivoPaciente = null,Object? descripcion = null,Object? indicaciones = null,Object? duracionMin = null,Object? margenMin = null,Object? precioDesde = freezed,Object? reservable = null,Object? visible = null,Object? orden = null,Object? duracionRealMin = freezed,Object? duracionRealCitas = null,}) {
  return _then(_Tratamiento(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,motivoPaciente: null == motivoPaciente ? _self.motivoPaciente : motivoPaciente // ignore: cast_nullable_to_non_nullable
as String,descripcion: null == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String,indicaciones: null == indicaciones ? _self.indicaciones : indicaciones // ignore: cast_nullable_to_non_nullable
as String,duracionMin: null == duracionMin ? _self.duracionMin : duracionMin // ignore: cast_nullable_to_non_nullable
as int,margenMin: null == margenMin ? _self.margenMin : margenMin // ignore: cast_nullable_to_non_nullable
as int,precioDesde: freezed == precioDesde ? _self.precioDesde : precioDesde // ignore: cast_nullable_to_non_nullable
as String?,reservable: null == reservable ? _self.reservable : reservable // ignore: cast_nullable_to_non_nullable
as bool,visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,orden: null == orden ? _self.orden : orden // ignore: cast_nullable_to_non_nullable
as int,duracionRealMin: freezed == duracionRealMin ? _self.duracionRealMin : duracionRealMin // ignore: cast_nullable_to_non_nullable
as int?,duracionRealCitas: null == duracionRealCitas ? _self.duracionRealCitas : duracionRealCitas // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$Paciente {

 int get id; String get nombre; String get celular; int get inasistencias; bool get bloqueado; bool get verificado; List<Cita> get citas;
/// Create a copy of Paciente
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PacienteCopyWith<Paciente> get copyWith => _$PacienteCopyWithImpl<Paciente>(this as Paciente, _$identity);

  /// Serializes this Paciente to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Paciente&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.celular, celular) || other.celular == celular)&&(identical(other.inasistencias, inasistencias) || other.inasistencias == inasistencias)&&(identical(other.bloqueado, bloqueado) || other.bloqueado == bloqueado)&&(identical(other.verificado, verificado) || other.verificado == verificado)&&const DeepCollectionEquality().equals(other.citas, citas));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre,celular,inasistencias,bloqueado,verificado,const DeepCollectionEquality().hash(citas));

@override
String toString() {
  return 'Paciente(id: $id, nombre: $nombre, celular: $celular, inasistencias: $inasistencias, bloqueado: $bloqueado, verificado: $verificado, citas: $citas)';
}


}

/// @nodoc
abstract mixin class $PacienteCopyWith<$Res>  {
  factory $PacienteCopyWith(Paciente value, $Res Function(Paciente) _then) = _$PacienteCopyWithImpl;
@useResult
$Res call({
 int id, String nombre, String celular, int inasistencias, bool bloqueado, bool verificado, List<Cita> citas
});




}
/// @nodoc
class _$PacienteCopyWithImpl<$Res>
    implements $PacienteCopyWith<$Res> {
  _$PacienteCopyWithImpl(this._self, this._then);

  final Paciente _self;
  final $Res Function(Paciente) _then;

/// Create a copy of Paciente
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? nombre = null,Object? celular = null,Object? inasistencias = null,Object? bloqueado = null,Object? verificado = null,Object? citas = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,celular: null == celular ? _self.celular : celular // ignore: cast_nullable_to_non_nullable
as String,inasistencias: null == inasistencias ? _self.inasistencias : inasistencias // ignore: cast_nullable_to_non_nullable
as int,bloqueado: null == bloqueado ? _self.bloqueado : bloqueado // ignore: cast_nullable_to_non_nullable
as bool,verificado: null == verificado ? _self.verificado : verificado // ignore: cast_nullable_to_non_nullable
as bool,citas: null == citas ? _self.citas : citas // ignore: cast_nullable_to_non_nullable
as List<Cita>,
  ));
}

}


/// Adds pattern-matching-related methods to [Paciente].
extension PacientePatterns on Paciente {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Paciente value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Paciente() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Paciente value)  $default,){
final _that = this;
switch (_that) {
case _Paciente():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Paciente value)?  $default,){
final _that = this;
switch (_that) {
case _Paciente() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String nombre,  String celular,  int inasistencias,  bool bloqueado,  bool verificado,  List<Cita> citas)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Paciente() when $default != null:
return $default(_that.id,_that.nombre,_that.celular,_that.inasistencias,_that.bloqueado,_that.verificado,_that.citas);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String nombre,  String celular,  int inasistencias,  bool bloqueado,  bool verificado,  List<Cita> citas)  $default,) {final _that = this;
switch (_that) {
case _Paciente():
return $default(_that.id,_that.nombre,_that.celular,_that.inasistencias,_that.bloqueado,_that.verificado,_that.citas);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String nombre,  String celular,  int inasistencias,  bool bloqueado,  bool verificado,  List<Cita> citas)?  $default,) {final _that = this;
switch (_that) {
case _Paciente() when $default != null:
return $default(_that.id,_that.nombre,_that.celular,_that.inasistencias,_that.bloqueado,_that.verificado,_that.citas);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Paciente implements Paciente {
  const _Paciente({required this.id, required this.nombre, required this.celular, this.inasistencias = 0, this.bloqueado = false, this.verificado = false, final  List<Cita> citas = const []}): _citas = citas;
  factory _Paciente.fromJson(Map<String, dynamic> json) => _$PacienteFromJson(json);

@override final  int id;
@override final  String nombre;
@override final  String celular;
@override@JsonKey() final  int inasistencias;
@override@JsonKey() final  bool bloqueado;
@override@JsonKey() final  bool verificado;
 final  List<Cita> _citas;
@override@JsonKey() List<Cita> get citas {
  if (_citas is EqualUnmodifiableListView) return _citas;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_citas);
}


/// Create a copy of Paciente
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PacienteCopyWith<_Paciente> get copyWith => __$PacienteCopyWithImpl<_Paciente>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PacienteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Paciente&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.celular, celular) || other.celular == celular)&&(identical(other.inasistencias, inasistencias) || other.inasistencias == inasistencias)&&(identical(other.bloqueado, bloqueado) || other.bloqueado == bloqueado)&&(identical(other.verificado, verificado) || other.verificado == verificado)&&const DeepCollectionEquality().equals(other._citas, _citas));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre,celular,inasistencias,bloqueado,verificado,const DeepCollectionEquality().hash(_citas));

@override
String toString() {
  return 'Paciente(id: $id, nombre: $nombre, celular: $celular, inasistencias: $inasistencias, bloqueado: $bloqueado, verificado: $verificado, citas: $citas)';
}


}

/// @nodoc
abstract mixin class _$PacienteCopyWith<$Res> implements $PacienteCopyWith<$Res> {
  factory _$PacienteCopyWith(_Paciente value, $Res Function(_Paciente) _then) = __$PacienteCopyWithImpl;
@override @useResult
$Res call({
 int id, String nombre, String celular, int inasistencias, bool bloqueado, bool verificado, List<Cita> citas
});




}
/// @nodoc
class __$PacienteCopyWithImpl<$Res>
    implements _$PacienteCopyWith<$Res> {
  __$PacienteCopyWithImpl(this._self, this._then);

  final _Paciente _self;
  final $Res Function(_Paciente) _then;

/// Create a copy of Paciente
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? nombre = null,Object? celular = null,Object? inasistencias = null,Object? bloqueado = null,Object? verificado = null,Object? citas = null,}) {
  return _then(_Paciente(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,celular: null == celular ? _self.celular : celular // ignore: cast_nullable_to_non_nullable
as String,inasistencias: null == inasistencias ? _self.inasistencias : inasistencias // ignore: cast_nullable_to_non_nullable
as int,bloqueado: null == bloqueado ? _self.bloqueado : bloqueado // ignore: cast_nullable_to_non_nullable
as bool,verificado: null == verificado ? _self.verificado : verificado // ignore: cast_nullable_to_non_nullable
as bool,citas: null == citas ? _self._citas : citas // ignore: cast_nullable_to_non_nullable
as List<Cita>,
  ));
}


}

// dart format on
