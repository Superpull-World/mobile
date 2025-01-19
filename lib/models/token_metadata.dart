import 'package:freezed_annotation/freezed_annotation.dart';

part 'token_metadata.freezed.dart';
part 'token_metadata.g.dart';

@freezed
class TokenMetadata with _$TokenMetadata {
  const factory TokenMetadata({
    required String mint,
    @Default('Unknown Token') String name,
    @Default('') String symbol,
    @Default('') String uri,
    required int decimals,
    @Default('0') String supply,
    @Default('0') String balance,
  }) = _TokenMetadata;

  factory TokenMetadata.fromJson(Map<String, dynamic> json) =>
      _$TokenMetadataFromJson(json);
} 