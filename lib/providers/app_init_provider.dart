import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'service_providers.dart';
import 'creator_provider.dart';
import 'auctions_provider.dart';
import 'token_provider.dart' as token_provider;

final appInitProvider = FutureProvider<void>((ref) async {
  // First check authentication
  final authService = ref.watch(authServiceProvider);
  if (!await authService.isAuthenticated()) {
    throw Exception('Not authenticated');
  }

  // Get JWT
  final jwt = await authService.getStoredJwt();
  if (jwt == null) {
    throw Exception('No JWT found');
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