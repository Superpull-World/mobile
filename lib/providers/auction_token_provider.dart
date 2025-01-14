import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superpull_mobile/models/token_metadata.dart';
import 'package:superpull_mobile/providers/token_provider.dart';
import 'package:superpull_mobile/services/balance_service.dart';
import 'package:superpull_mobile/services/token_service.dart';

// Balance service provider
final balanceServiceProvider = Provider((ref) => BalanceService());

final currentAuctionTokenProvider = StateNotifierProvider<CurrentAuctionTokenNotifier, AsyncValue<AuctionTokenState>>((ref) {
  final balanceService = ref.watch(balanceServiceProvider);
  final tokenService = ref.watch(tokenServiceProvider);
  return CurrentAuctionTokenNotifier(balanceService, tokenService);
});

class AuctionTokenState {
  final TokenMetadata metadata;
  final double? balance;

  const AuctionTokenState({
    required this.metadata,
    this.balance,
  });
}

class CurrentAuctionTokenNotifier extends StateNotifier<AsyncValue<AuctionTokenState>> {
  final BalanceService _balanceService;
  final TokenService _tokenService;

  CurrentAuctionTokenNotifier(this._balanceService, this._tokenService)
      : super(const AsyncValue.loading());

  Future<void> updateForAuction(String tokenMint) async {
    try {
      state = const AsyncValue.loading();
      print('🔄 Updating token info for auction: $tokenMint');

      // Get token metadata
      final tokens = await _tokenService.getAcceptedTokens();
      final metadata = tokens.firstWhere(
        (token) => token.mint == tokenMint,
        orElse: () => throw Exception('Token metadata not found for $tokenMint'),
      );
      print('✅ Found token metadata: ${metadata.symbol}');

      // Get balance
      final balance = await _balanceService.getTokenBalance(tokenMint);
      print('💰 Token balance: $balance');

      state = AsyncValue.data(AuctionTokenState(
        metadata: metadata,
        balance: balance,
      ));
    } catch (error, stack) {
      print('❌ Error updating auction token: $error');
      state = AsyncValue.error(error, stack);
    }
  }

  void reset() {
    state = const AsyncValue.loading();
  }
} 