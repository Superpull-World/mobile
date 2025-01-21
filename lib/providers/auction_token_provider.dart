import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superpull_mobile/models/token_metadata.dart';
import 'package:superpull_mobile/services/token_service.dart';
import 'token_provider.dart';

final auctionTokenProvider = StateNotifierProvider<CurrentAuctionTokenNotifier, TokenMetadata?>((ref) {
  final tokenService = ref.watch(tokenServiceProvider);
  return CurrentAuctionTokenNotifier(tokenService);
});

class CurrentAuctionTokenNotifier extends StateNotifier<TokenMetadata?> {
  final TokenService _tokenService;

  CurrentAuctionTokenNotifier(this._tokenService) : super(null);

  Future<void> setTokenMint(String tokenMint) async {
    final tokens = await _tokenService.getAcceptedTokens();
    state = tokens.firstWhere(
      (token) => token.mint == tokenMint,
      orElse: () => TokenMetadata(
        mint: tokenMint,
        name: 'Unknown Token',
        symbol: '',
        uri: '',
        decimals: 0,
        supply: '0',
      ),
    );
  }

  Future<void> refresh() async {
    if (state == null) return;
    final tokens = await _tokenService.getAcceptedTokens();
    state = tokens.firstWhere(
      (token) => token.mint == state!.mint,
      orElse: () => state!,
    );
  }
} 