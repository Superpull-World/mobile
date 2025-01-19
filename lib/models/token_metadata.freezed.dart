// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'token_metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TokenMetadata _$TokenMetadataFromJson(Map<String, dynamic> json) {
  return _TokenMetadata.fromJson(json);
}

/// @nodoc
mixin _$TokenMetadata {
  String get mint => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get symbol => throw _privateConstructorUsedError;
  String get uri => throw _privateConstructorUsedError;
  int get decimals => throw _privateConstructorUsedError;
  String get supply => throw _privateConstructorUsedError;
  String get balance => throw _privateConstructorUsedError;

  /// Serializes this TokenMetadata to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TokenMetadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TokenMetadataCopyWith<TokenMetadata> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TokenMetadataCopyWith<$Res> {
  factory $TokenMetadataCopyWith(
          TokenMetadata value, $Res Function(TokenMetadata) then) =
      _$TokenMetadataCopyWithImpl<$Res, TokenMetadata>;
  @useResult
  $Res call(
      {String mint,
      String name,
      String symbol,
      String uri,
      int decimals,
      String supply,
      String balance});
}

/// @nodoc
class _$TokenMetadataCopyWithImpl<$Res, $Val extends TokenMetadata>
    implements $TokenMetadataCopyWith<$Res> {
  _$TokenMetadataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TokenMetadata
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mint = null,
    Object? name = null,
    Object? symbol = null,
    Object? uri = null,
    Object? decimals = null,
    Object? supply = null,
    Object? balance = null,
  }) {
    return _then(_value.copyWith(
      mint: null == mint
          ? _value.mint
          : mint // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      symbol: null == symbol
          ? _value.symbol
          : symbol // ignore: cast_nullable_to_non_nullable
              as String,
      uri: null == uri
          ? _value.uri
          : uri // ignore: cast_nullable_to_non_nullable
              as String,
      decimals: null == decimals
          ? _value.decimals
          : decimals // ignore: cast_nullable_to_non_nullable
              as int,
      supply: null == supply
          ? _value.supply
          : supply // ignore: cast_nullable_to_non_nullable
              as String,
      balance: null == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TokenMetadataImplCopyWith<$Res>
    implements $TokenMetadataCopyWith<$Res> {
  factory _$$TokenMetadataImplCopyWith(
          _$TokenMetadataImpl value, $Res Function(_$TokenMetadataImpl) then) =
      __$$TokenMetadataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String mint,
      String name,
      String symbol,
      String uri,
      int decimals,
      String supply,
      String balance});
}

/// @nodoc
class __$$TokenMetadataImplCopyWithImpl<$Res>
    extends _$TokenMetadataCopyWithImpl<$Res, _$TokenMetadataImpl>
    implements _$$TokenMetadataImplCopyWith<$Res> {
  __$$TokenMetadataImplCopyWithImpl(
      _$TokenMetadataImpl _value, $Res Function(_$TokenMetadataImpl) _then)
      : super(_value, _then);

  /// Create a copy of TokenMetadata
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mint = null,
    Object? name = null,
    Object? symbol = null,
    Object? uri = null,
    Object? decimals = null,
    Object? supply = null,
    Object? balance = null,
  }) {
    return _then(_$TokenMetadataImpl(
      mint: null == mint
          ? _value.mint
          : mint // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      symbol: null == symbol
          ? _value.symbol
          : symbol // ignore: cast_nullable_to_non_nullable
              as String,
      uri: null == uri
          ? _value.uri
          : uri // ignore: cast_nullable_to_non_nullable
              as String,
      decimals: null == decimals
          ? _value.decimals
          : decimals // ignore: cast_nullable_to_non_nullable
              as int,
      supply: null == supply
          ? _value.supply
          : supply // ignore: cast_nullable_to_non_nullable
              as String,
      balance: null == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TokenMetadataImpl implements _TokenMetadata {
  const _$TokenMetadataImpl(
      {required this.mint,
      this.name = 'Unknown Token',
      this.symbol = 'UNKNOWN',
      this.uri = '',
      required this.decimals,
      this.supply = '0',
      this.balance = '0'});

  factory _$TokenMetadataImpl.fromJson(Map<String, dynamic> json) =>
      _$$TokenMetadataImplFromJson(json);

  @override
  final String mint;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String symbol;
  @override
  @JsonKey()
  final String uri;
  @override
  final int decimals;
  @override
  @JsonKey()
  final String supply;
  @override
  @JsonKey()
  final String balance;

  @override
  String toString() {
    return 'TokenMetadata(mint: $mint, name: $name, symbol: $symbol, uri: $uri, decimals: $decimals, supply: $supply, balance: $balance)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TokenMetadataImpl &&
            (identical(other.mint, mint) || other.mint == mint) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.symbol, symbol) || other.symbol == symbol) &&
            (identical(other.uri, uri) || other.uri == uri) &&
            (identical(other.decimals, decimals) ||
                other.decimals == decimals) &&
            (identical(other.supply, supply) || other.supply == supply) &&
            (identical(other.balance, balance) || other.balance == balance));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, mint, name, symbol, uri, decimals, supply, balance);

  /// Create a copy of TokenMetadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TokenMetadataImplCopyWith<_$TokenMetadataImpl> get copyWith =>
      __$$TokenMetadataImplCopyWithImpl<_$TokenMetadataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TokenMetadataImplToJson(
      this,
    );
  }
}

abstract class _TokenMetadata implements TokenMetadata {
  const factory _TokenMetadata(
      {required final String mint,
      final String name,
      final String symbol,
      final String uri,
      required final int decimals,
      final String supply,
      final String balance}) = _$TokenMetadataImpl;

  factory _TokenMetadata.fromJson(Map<String, dynamic> json) =
      _$TokenMetadataImpl.fromJson;

  @override
  String get mint;
  @override
  String get name;
  @override
  String get symbol;
  @override
  String get uri;
  @override
  int get decimals;
  @override
  String get supply;
  @override
  String get balance;

  /// Create a copy of TokenMetadata
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TokenMetadataImplCopyWith<_$TokenMetadataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
