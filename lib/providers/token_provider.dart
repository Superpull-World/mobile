import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/token_metadata.dart';
import '../services/token_service.dart';
import '../services/workflow_service.dart';
import '../services/auth_service.dart';

// Service providers
final workflowServiceProvider = Provider((ref) => WorkflowService());

final authServiceProvider = Provider((ref) => AuthService());

final tokenServiceProvider = Provider((ref) => TokenService(
  workflowService: ref.watch(workflowServiceProvider),
  authService: ref.watch(authServiceProvider),
));

// Token state class to hold all token-related data
class TokenState {
  final List<TokenMetadata>? tokens;
  final Map<String, String> balances;
  final TokenMetadata? currentAuctionToken;
  final bool isLoading;
  final String? error;

  const TokenState({
    this.tokens,
    this.balances = const {},
    this.currentAuctionToken,
    this.isLoading = false,
    this.error,
  });

  TokenState copyWith({
    List<TokenMetadata>? tokens,
    Map<String, String>? balances,
    TokenMetadata? currentAuctionToken,
    bool? isLoading,
    String? error,
  }) {
    return TokenState(
      tokens: tokens ?? this.tokens,
      balances: balances ?? this.balances,
      currentAuctionToken: currentAuctionToken ?? this.currentAuctionToken,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Token state notifier to manage all token-related state
class TokenStateNotifier extends StateNotifier<TokenState> {
  final TokenService _tokenService;
  
  TokenStateNotifier(this._tokenService) : super(const TokenState()) {
    // Initialize tokens on startup
    initialize();
    
    // Listen for token updates
    _tokenService.dataStream.listen((tokens) {
      if (!mounted) return;
      
      final balances = <String, String>{};
      for (final token in tokens) {
        balances[token.mint] = token.balance;
      }
      
      state = state.copyWith(
        tokens: tokens,
        balances: balances,
      );
    });
  }

  Future<void> initialize() async {
    if (!mounted) return;
    
    try {
      state = state.copyWith(isLoading: true);
      final tokens = await _tokenService.getAcceptedTokens();
      
      if (!mounted) return;
      
      final balances = <String, String>{};
      for (final token in tokens) {
        balances[token.mint] = token.balance;
      }
      
      state = TokenState(
        tokens: tokens,
        balances: balances,
      );
    } catch (e) {
      if (!mounted) return;
      state = TokenState(error: e.toString());
    }
  }

  Future<void> refresh() async {
    if (!mounted) return;
    
    try {
      // Keep existing values while loading
      final currentTokens = state.tokens;
      final currentBalances = state.balances;
      final currentAuctionToken = state.currentAuctionToken;
      
      state = state.copyWith(isLoading: true, error: null);
      
      // Force a new fetch while keeping current state
      final tokens = await _tokenService.forceRefresh(() => _tokenService.getAcceptedTokens());
      if (!mounted) return;
      
      // Only update state if we got new tokens
      if (tokens.isNotEmpty) {
        final balances = <String, String>{};
        for (final token in tokens) {
          balances[token.mint] = token.balance;
        }
        
        state = state.copyWith(
          tokens: tokens,
          balances: balances,
          currentAuctionToken: currentAuctionToken, // Preserve current auction token
          isLoading: false,
        );
      } else {
        // If no new tokens, restore previous state
        state = state.copyWith(
          tokens: currentTokens,
          balances: currentBalances,
          currentAuctionToken: currentAuctionToken,
          isLoading: false,
        );
      }
    } catch (e) {
      print('Error refreshing tokens: $e');
      if (mounted) {
        // Keep current tokens/balances on error
        state = state.copyWith(
          isLoading: false,
          error: e.toString(),
        );
      }
    }
  }

  void updateCurrentAuctionToken(String tokenMint) {
    if (!mounted || state.tokens == null) return;
    
    final token = state.tokens!.firstWhere(
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
    
    state = state.copyWith(currentAuctionToken: token);
  }

  TokenMetadata? get currentAuctionToken => state.currentAuctionToken;
  List<TokenMetadata>? get tokens => state.tokens;
  Map<String, String> get balances => state.balances;
}

// Main token provider that maintains all token state
final tokenStateProvider = StateNotifierProvider<TokenStateNotifier, TokenState>((ref) {
  final service = ref.watch(tokenServiceProvider);
  return TokenStateNotifier(service);
});

// Helper provider to get token by mint
final tokenByMintProvider = Provider.family<TokenMetadata, String>((ref, tokenMint) {
  final tokenState = ref.watch(tokenStateProvider);
  final tokens = tokenState.tokens;
  
  if (tokens == null) {
    return TokenMetadata(
      mint: tokenMint,
      name: 'Unknown Token',
      symbol: '',
      uri: '',
      decimals: 0,
      supply: '0',
    );
  }
  
  return tokens.firstWhere(
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
}); 