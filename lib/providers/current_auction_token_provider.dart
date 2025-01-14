import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/token_metadata.dart';
import '../services/token_service.dart';
import '../services/balance_service.dart';
import 'service_providers.dart';

class AuctionTokenState {
  final TokenMetadata metadata;
  final double? balance;

  const AuctionTokenState({
    required this.metadata,
    this.balance,
  });
}

class CurrentAuctionTokenNotifier extends AsyncNotifier<AuctionTokenState> {
  String? _currentTokenMint;
  
  @override
  Future<AuctionTokenState> build() async {
    // Return empty state initially
    return const AuctionTokenState(
      metadata: TokenMetadata(
        symbol: '',
        name: '',
        decimals: 0,
        mint: '',
        uri: '',
        supply: '0',
      ),
    );
  }

  Future<void> updateToken(String tokenMint) async {
    if (_currentTokenMint == tokenMint) return;
    _currentTokenMint = tokenMint;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final tokenService = ref.read(tokenServiceProvider);
      final balanceService = ref.read(balanceServiceProvider);

      // Get token metadata from accepted tokens
      final tokens = await tokenService.getAcceptedTokens();
      final metadata = tokens.firstWhere(
        (token) => token.mint == tokenMint,
        orElse: () => throw Exception('Token metadata not found for $tokenMint'),
      );
      
      // Fetch token balance
      final balance = await balanceService.getTokenBalance(tokenMint);

      return AuctionTokenState(
        metadata: metadata,
        balance: balance,
      );
    });
  }
}

final currentAuctionTokenProvider = AsyncNotifierProvider<CurrentAuctionTokenNotifier, AuctionTokenState>(
  () => CurrentAuctionTokenNotifier(),
); 