import 'package:freezed_annotation/freezed_annotation.dart';

part 'token_metadata.freezed.dart';
part 'token_metadata.g.dart';

@freezed
class TokenMetadata with _$TokenMetadata {
  const factory TokenMetadata({
    required String mint,
    required String name,
    required String symbol,
    required String uri,
    required int decimals,
    required String supply,
  }) = _TokenMetadata;

  factory TokenMetadata.fromJson(Map<String, dynamic> json) =>
      _$TokenMetadataFromJson(json);
} 