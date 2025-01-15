import 'package:freezed_annotation/freezed_annotation.dart';

part 'token_metadata.freezed.dart';
part 'token_metadata.g.dart';

@freezed
class TokenMetadata with _$TokenMetadata {
  const factory TokenMetadata({
    required String mint,
    @Default('Unknown Token') String name,
    @Default('UNKNOWN') String symbol,
    @Default('') String uri,
    required int decimals,
    @Default('0') String supply,
  }) = _TokenMetadata;

  factory TokenMetadata.fromJson(Map<String, dynamic> json) =>
      _$TokenMetadataFromJson(json);
} 