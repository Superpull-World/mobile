import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/balance_provider.dart';
import '../providers/auctions_provider.dart';
import '../providers/token_provider.dart';

final appInitProvider = FutureProvider<void>((ref) async {
  // First, initialize balance service
  final balanceService = await ref.watch(balanceServiceInitProvider.future);
  
  // Then initialize tokens (this will cache them)
  await ref.watch(tokenInitProvider.future);
  
  // Then fetch auctions
  final auctions = await ref.read(auctionsProvider.future);
  
  // Finally, track tokens in balance service
  for (final auction in auctions) {
    balanceService.trackToken(auction.tokenMint);
  }
}); 