import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auction.dart';

// Create a provider to handle token tracking
final tokenTrackingProvider = Provider.family<void, Auction>((ref, auction) {
  // No need to do anything since token service now automatically tracks all tokens
  return;
}); 