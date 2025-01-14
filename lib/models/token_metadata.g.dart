// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TokenMetadataImpl _$$TokenMetadataImplFromJson(Map<String, dynamic> json) =>
    _$TokenMetadataImpl(
      mint: json['mint'] as String,
      name: json['name'] as String,
      symbol: json['symbol'] as String,
      uri: json['uri'] as String,
      decimals: (json['decimals'] as num).toInt(),
      supply: json['supply'] as String,
    );

Map<String, dynamic> _$$TokenMetadataImplToJson(_$TokenMetadataImpl instance) =>
    <String, dynamic>{
      'mint': instance.mint,
      'name': instance.name,
      'symbol': instance.symbol,
      'uri': instance.uri,
      'decimals': instance.decimals,
      'supply': instance.supply,
    };
