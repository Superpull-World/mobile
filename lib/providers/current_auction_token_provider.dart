import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/token_metadata.dart';
import '../services/token_service.dart';
import 'service_providers.dart';
import 'token_provider.dart' as token_provider;

class AuctionTokenState {
  final TokenMetadata metadata;

  const AuctionTokenState({
    required this.metadata,
  });
}

class CurrentAuctionTokenNotifier extends AsyncNotifier<AuctionTokenState> {
  String? _currentTokenMint;
  
  @override
  Future<AuctionTokenState> build() async {
    // Wait for token state to be initialized
    final tokenState = ref.watch(token_provider.tokenStateProvider);
    if (tokenState.isLoading || tokenState.tokens == null) {
      throw const AsyncLoading();
    }
    
    if (tokenState.error != null) {
      throw tokenState.error!;
    }
    
    if (_currentTokenMint != null) {
      // Find the token in the initialized token state
      final token = tokenState.tokens!.firstWhere(
        (token) => token.mint == _currentTokenMint,
        orElse: () => throw Exception('Token not found: $_currentTokenMint'),
      );
      return AuctionTokenState(metadata: token);
    }
    
    // Return first token as initial state
    return AuctionTokenState(metadata: tokenState.tokens!.first);
  }

  Future<void> updateToken(String tokenMint) async {
    if (_currentTokenMint == tokenMint) return;
    _currentTokenMint = tokenMint;
    
    // Force a rebuild which will use the new token mint
    ref.invalidateSelf();
  }
}

final currentAuctionTokenProvider = AsyncNotifierProvider<CurrentAuctionTokenNotifier, AuctionTokenState>(
  () => CurrentAuctionTokenNotifier(),
); 