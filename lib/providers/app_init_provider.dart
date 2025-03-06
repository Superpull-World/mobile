import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'service_providers.dart';
import 'creator_provider.dart';
import 'auctions_provider.dart';
import 'token_provider.dart' as token_provider;

// Flag to track if app is initialized by welcome page
final isAuthenticatedProvider = StateProvider<bool>((ref) => false);

final appInitProvider = FutureProvider<void>((ref) async {
  // Check if already authenticated by welcome page
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    // Attempt authentication as a fallback
    final authService = ref.watch(authServiceProvider);
    if (!await authService.isAuthenticated()) {
      // Add a small delay to allow welcome page authentication to complete
      await Future.delayed(const Duration(milliseconds: 500));
      if (!await authService.isAuthenticated()) {
        throw Exception('Not authenticated');
      }
    }
  }

  // Get JWT
  final authService = ref.watch(authServiceProvider);
  final jwt = await authService.getStoredJwt();
  if (jwt == null) {
    // Add a small delay to allow welcome page to store JWT
    await Future.delayed(const Duration(milliseconds: 500));
    final retryJwt = await authService.getStoredJwt();
    if (retryJwt == null) {
      throw Exception('No JWT found');
    }
  }

  print('🔄 Starting app initialization...');

  // Initialize services
  final tokenStateNotifier = ref.read(token_provider.tokenStateProvider.notifier);
  await tokenStateNotifier.initialize();
  print('✅ Tokens loaded');

  // Trigger auction load
  final auctionOps = ref.read(auctionsOperationsProvider);
  await auctionOps.refresh();
  print('✅ Auctions loaded');

  // Verify states
  final creatorState = ref.watch(creatorStateProvider);
  if (creatorState.error != null) {
    throw creatorState.error!;
  }

  final auctionState = ref.watch(auctionStateProvider);
  if (auctionState.error != null) {
    throw auctionState.error!;
  }

  print('✅ App initialization complete');
}); 