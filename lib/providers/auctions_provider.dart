import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superpull_mobile/models/auction.dart';
import 'package:superpull_mobile/services/auction_service.dart';
import 'package:superpull_mobile/services/workflow_service.dart';
import 'package:superpull_mobile/services/token_service.dart';
import 'package:superpull_mobile/providers/token_provider.dart';

// Single instance of auction service that's kept alive for the entire app session
final auctionServiceProvider = Provider<AuctionService>((ref) {
  final service = AuctionService(
    workflowService: ref.watch(workflowServiceProvider),
    tokenService: ref.watch(tokenServiceProvider),
    ref: ref,
  );
  
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

class AuctionState {
  final List<Auction>? auctions;
  final bool isLoading;
  final String? error;
  final int totalAuctions;
  final Map<int, List<Auction>> pageCache;

  const AuctionState({
    this.auctions,
    this.isLoading = false,
    this.error,
    this.totalAuctions = 0,
    this.pageCache = const {},
  });

  AuctionState copyWith({
    List<Auction>? auctions,
    bool? isLoading,
    String? error,
    int? totalAuctions,
    Map<int, List<Auction>>? pageCache,
  }) {
    return AuctionState(
      auctions: auctions ?? this.auctions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      totalAuctions: totalAuctions ?? this.totalAuctions,
      pageCache: pageCache ?? this.pageCache,
    );
  }
}

class AuctionStateNotifier extends StateNotifier<AuctionState> {
  final AuctionService _auctionService;
  StreamSubscription? _refreshSubscription;
  
  AuctionStateNotifier(this._auctionService) : super(const AuctionState()) {
    print('🏗️ Creating AuctionStateNotifier');
    _initialize();
    _subscribeToUpdates();
  }

  void _subscribeToUpdates() {
    _refreshSubscription?.cancel();
    _refreshSubscription = _auctionService.dataStream.listen((data) async {
      print('🔄 Received auction update from service');
      await _loadAuctions(clearCache: true, isBackgroundRefresh: true);
    });
  }

  @override
  void dispose() {
    _refreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    
    try {
      state = state.copyWith(isLoading: true);
      
      // Check if we already have cached auctions from service
      final cachedData = _auctionService.cachedData;
      if (cachedData != null) {
        print('📦 Using cached auctions from service');
        final pageCache = {1: cachedData.auctions};
        state = state.copyWith(
          auctions: cachedData.auctions,
          totalAuctions: cachedData.total,
          pageCache: pageCache,
          isLoading: false,
        );
        return;
      }
      
      await _loadAuctions();
    } catch (e) {
      if (!mounted) return;
      print('❌ Error initializing auctions: $e');
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> _loadAuctions({
    bool clearCache = false,
    bool isBackgroundRefresh = false,
  }) async {
    if (!mounted) return;
    
    try {
      print('🔄 Starting auction fetch (background: $isBackgroundRefresh)');
      
      if (clearCache) {
        state = state.copyWith(
          pageCache: {},
          totalAuctions: 0,
          isLoading: true,
        );
      } else if (state.isLoading) {
        return; // Prevent multiple simultaneous loads
      } else {
        state = state.copyWith(isLoading: true);
      }
      
      // First get total from first page
      final firstPage = await _auctionService.getAuctions(
        page: 1,
        limit: 1000,
      );
      
      if (!mounted) return;
      
      final pageCache = {1: firstPage.auctions};
      final totalPages = (firstPage.total / 1000).ceil();
      print('📊 Need to fetch $totalPages pages for ${firstPage.total} auctions');
      
      // Fetch all remaining pages in parallel
      if (totalPages > 1) {
        final futures = List.generate(totalPages - 1, (index) {
          final pageNum = index + 2; // Start from page 2
          return _auctionService.getAuctions(
            page: pageNum,
            limit: 1000,
          ).then((result) {
            if (mounted) {
              pageCache[pageNum] = result.auctions;
              print('📥 Got page $pageNum with ${result.auctions.length} auctions');
            }
          });
        });
        
        await Future.wait(futures);
      }
      
      if (!mounted) return;
      
      // Get all cached auctions and sort them
      final allAuctions = _getAllAuctions(pageCache);
      _sortAuctions(allAuctions);
      
      state = state.copyWith(
        auctions: allAuctions,
        totalAuctions: firstPage.total,
        pageCache: pageCache,
        isLoading: false,
        error: null,
      );
      
      print('✅ Auction load complete with ${allAuctions.length} auctions');
    } catch (e) {
      if (!mounted) return;
      print('❌ Error loading auctions: $e');
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  List<Auction> _getAllAuctions(Map<int, List<Auction>> pageCache) {
    final uniqueAuctions = <String, Auction>{};
    final sortedPages = pageCache.keys.toList()..sort();
    
    for (final page in sortedPages) {
      for (final auction in pageCache[page]!) {
        uniqueAuctions[auction.id] = auction;
      }
    }
    
    return uniqueAuctions.values.toList();
  }

  void _sortAuctions(List<Auction> auctions) {
    final now = DateTime.now();
    
    // Helper function to calculate progress rate (items per hour)
    double _getProgressRate(Auction auction) {
      // Since we don't have saleStartDate, use time since auction was first seen
      final hoursElapsed = auction.saleEndDate.difference(now).abs().inHours;
      if (hoursElapsed == 0) return 0;
      return auction.currentSupply / hoursElapsed;
    }
    
    // Helper function to calculate probability score
    double _getProbabilityScore(Auction auction) {
      if (auction.saleEndDate.isBefore(now)) return -1; // Ended auctions get lowest priority
      if (auction.currentSupply >= auction.maxSupply) return -1; // Max supply reached gets lowest priority
      if (auction.isGraduated) return 0; // Graduated auctions get second lowest priority
      
      final hoursRemaining = auction.saleEndDate.difference(now).inHours;
      if (hoursRemaining <= 0) return -1;
      
      final progressRate = _getProgressRate(auction);
      if (progressRate <= 0) return 0.1; // Give some small chance for new auctions
      
      // Calculate remaining items needed
      final remainingForMin = auction.minimumItems - auction.currentSupply;
      final remainingForMax = auction.maxSupply - auction.currentSupply;
      
      // Calculate projected final supply based on current rate
      final projectedSupply = auction.currentSupply + (progressRate * hoursRemaining);
      
      // If we haven't reached min supply yet
      if (auction.currentSupply < auction.minimumItems) {
        // Calculate probability of reaching min supply
        final probReachMin = projectedSupply / auction.minimumItems;
        return probReachMin.clamp(0.0, 1.0);
      } 
      // If we've reached min but not max
      else {
        // Calculate probability of reaching max supply
        // Add 1.0 to ensure these rank higher than those not reaching min supply
        final probReachMax = projectedSupply / auction.maxSupply;
        return 1.0 + probReachMax.clamp(0.0, 1.0);
      }
    }

    // Sort auctions by probability score (higher score = higher priority)
    auctions.sort((a, b) {
      final scoreA = _getProbabilityScore(a);
      final scoreB = _getProbabilityScore(b);
      
      // Sort by score in descending order
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }
      
      // If scores are equal, sort by deadline
      return a.saleEndDate.compareTo(b.saleEndDate);
    });
  }

  Future<void> refresh() async {
    await _loadAuctions(clearCache: true);
  }

  Future<void> refreshAfterBid() async {
    await refresh();
  }

  Future<void> refreshAfterNewAuction() async {
    await refresh();
  }
}

// State notifier provider that maintains the auction state
final auctionStateProvider = StateNotifierProvider<AuctionStateNotifier, AuctionState>((ref) {
  final service = ref.watch(auctionServiceProvider);
  return AuctionStateNotifier(service);
});

// Provider for accessing the sorted list of auctions with notifier access
final auctionsProvider = Provider<AsyncValue<List<Auction>>>((ref) {
  final state = ref.watch(auctionStateProvider);
  
  if (state.isLoading && state.auctions == null) {
    return const AsyncValue.loading();
  }
  
  if (state.error != null) {
    return AsyncValue.error(state.error!, StackTrace.current);
  }
  
  if (state.auctions == null) {
    return const AsyncValue.loading();
  }
  
  return AsyncValue.data(state.auctions!);
});

// Provider for auction operations
final auctionsOperationsProvider = Provider<AuctionsOperations>((ref) {
  final stateNotifier = ref.watch(auctionStateProvider.notifier);
  return AuctionsOperations(stateNotifier);
});

// Class to handle auction operations
class AuctionsOperations {
  final AuctionStateNotifier _stateNotifier;
  
  AuctionsOperations(this._stateNotifier);
  
  Future<void> refresh() async {
    await _stateNotifier.refresh();
  }
  
  Future<void> refreshAfterBid() async {
    await _stateNotifier.refreshAfterBid();
  }
  
  Future<void> refreshAfterNewAuction() async {
    await _stateNotifier.refreshAfterNewAuction();
  }
} 