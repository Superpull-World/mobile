import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superpull_mobile/models/auction.dart';
import 'package:superpull_mobile/services/auction_service.dart';
import 'package:superpull_mobile/providers/token_provider.dart';

// Service provider
final auctionServiceProvider = Provider((ref) => AuctionService(
  workflowService: ref.watch(workflowServiceProvider),
  tokenService: ref.watch(tokenServiceProvider),
  ref: ref,
));

// Auction list state
class AuctionsState {
  final List<Auction> auctions;
  final int total;
  final bool isLoading;
  final String? error;

  const AuctionsState({
    required this.auctions,
    required this.total,
    this.isLoading = false,
    this.error,
  });

  AuctionsState copyWith({
    List<Auction>? auctions,
    int? total,
    bool? isLoading,
    String? error,
  }) {
    return AuctionsState(
      auctions: auctions ?? this.auctions,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Auctions notifier
class AuctionsNotifier extends StateNotifier<AuctionsState> {
  final AuctionService _auctionService;
  
  AuctionsNotifier(this._auctionService) : super(const AuctionsState(auctions: [], total: 0));

  Future<void> loadAuctions({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _auctionService.getAuctions(
        page: page,
        limit: limit,
        status: status,
      );
      
      state = state.copyWith(
        auctions: result.auctions,
        total: result.total,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await loadAuctions(page: 1);
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.auctions.length >= state.total) return;
    
    final nextPage = (state.auctions.length ~/ 10) + 1;
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _auctionService.getAuctions(
        page: nextPage,
        limit: 10,
      );
      
      state = state.copyWith(
        auctions: [...state.auctions, ...result.auctions],
        total: result.total,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

// Auctions provider
final auctionsProvider = StateNotifierProvider<AuctionsNotifier, AuctionsState>((ref) {
  final auctionService = ref.watch(auctionServiceProvider);
  return AuctionsNotifier(auctionService);
}); 