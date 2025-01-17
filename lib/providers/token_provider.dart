import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/token_metadata.dart';
import '../services/token_service.dart';
import '../services/workflow_service.dart';

// Service providers
final workflowServiceProvider = Provider((ref) => WorkflowService());

final tokenServiceProvider = Provider((ref) => TokenService(
  workflowService: ref.read(workflowServiceProvider),
));

// Token data provider - cached state
final acceptedTokensProvider = StateProvider<AsyncValue<List<TokenMetadata>>>((ref) {
  return const AsyncValue.loading();
});

// Initialize tokens - called only once during app init
final tokenInitProvider = FutureProvider<void>((ref) async {
  final tokenService = ref.read(tokenServiceProvider);
  final tokens = await tokenService.getAcceptedTokens();
  ref.read(acceptedTokensProvider.notifier).state = AsyncValue.data(tokens);
});

// Get token by mint from cache - throws if not found
final tokenByMintProvider = Provider.family<TokenMetadata, String>((ref, tokenMint) {
  final tokensState = ref.read(acceptedTokensProvider);
  return tokensState.when(
    data: (tokens) => tokens.firstWhere(
      (token) => token.mint == tokenMint,
      orElse: () => throw Exception('Token metadata not found for mint: $tokenMint'),
    ),
    loading: () => throw Exception('Token metadata not loaded yet'),
    error: (error, _) => throw Exception('Failed to load token metadata: $error'),
  );
}); 