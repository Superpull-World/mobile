import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superpull_mobile/models/auction.dart';
import 'package:superpull_mobile/services/auction_service.dart';
import 'package:superpull_mobile/services/workflow_service.dart';
import 'package:superpull_mobile/services/token_service.dart';
import 'package:superpull_mobile/providers/token_provider.dart';
import 'package:superpull_mobile/providers/balance_provider.dart';

// Service provider
final auctionServiceProvider = Provider((ref) => AuctionService(
  workflowService: ref.watch(workflowServiceProvider),
  tokenService: ref.watch(tokenServiceProvider),
  ref: ref,
));

// Auctions notifier
class AuctionsNotifier extends AsyncNotifier<List<Auction>> {
  final Map<int, List<Auction>> _pageCache = {};
  int _totalAuctions = 0;
  StreamSubscription? _refreshSubscription;

  @override
  Future<List<Auction>> build() async {
    // Subscribe to auction service updates
    final auctionService = ref.read(auctionServiceProvider);
    _refreshSubscription?.cancel();
    _refreshSubscription = auctionService.dataStream.listen((data) async {
      print('🔄 Received auction update from service');
      _clearCache();
      final auctions = await _loadAuctions(
        page: 1,
        isBackgroundRefresh: true,
      );
      state = AsyncValue.data(auctions);
    });

    ref.onDispose(() {
      _refreshSubscription?.cancel();
    });

    return _loadAuctions();
  }

  List<Auction> _getAllCachedAuctions() {
    final uniqueAuctions = <String, Auction>{};
    final sortedPages = _pageCache.keys.toList()..sort();
    
    // Use a Map to track unique auctions by ID
    for (final page in sortedPages) {
      for (final auction in _pageCache[page]!) {
        uniqueAuctions[auction.id] = auction;
      }
    }
    
    print('📦 Found ${_pageCache.length} pages with ${uniqueAuctions.length} unique auctions');
    if (_pageCache.length > 1) {
      final totalAuctions = _pageCache.values.fold(0, (sum, list) => sum + list.length);
      final duplicates = totalAuctions - uniqueAuctions.length;
      if (duplicates > 0) {
        print('🔍 Removed $duplicates duplicate auctions');
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

  void _clearCache() {
    _pageCache.clear();
    _totalAuctions = 0;
  }

  Future<List<Auction>> _loadAuctions({
    int page = 1,
    int limit = 1000,
    String? status,
    bool isBackgroundRefresh = false,
  }) async {
    try {
      print('🔄 Starting auction fetch (background: $isBackgroundRefresh)');
      
      // First get total from first page
      final firstPage = await ref.read(auctionServiceProvider).getAuctions(
        page: 1,
        limit: limit,
        status: status,
      );
      _totalAuctions = firstPage.total;
      _pageCache[1] = firstPage.auctions;
      
      // Calculate total pages needed
      final totalPages = (_totalAuctions / limit).ceil();
      print('📊 Need to fetch $totalPages pages for $_totalAuctions auctions');
      
      // Fetch all remaining pages in parallel
      if (totalPages > 1) {
        final futures = List.generate(totalPages - 1, (index) {
          final pageNum = index + 2; // Start from page 2
          return ref.read(auctionServiceProvider).getAuctions(
            page: pageNum,
            limit: limit,
            status: status,
          ).then((result) {
            _pageCache[pageNum] = result.auctions;
            print('📥 Got page $pageNum with ${result.auctions.length} auctions');
          });
        });
        
        await Future.wait(futures);
      }

      // Get all cached auctions and sort them
      final allAuctions = _getAllCachedAuctions();
      print('📦 Total auctions before sorting: ${allAuctions.length}');
      _sortAuctions(allAuctions);
      print('✅ Sorting complete');
      return allAuctions;
    } catch (e) {
      print('❌ Error fetching auctions: $e');
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      print('🔄 Starting full refresh');
      _clearCache();
      final auctions = await _loadAuctions(page: 1);
      print('✅ Refresh complete with ${auctions.length} auctions');
      state = AsyncValue.data(auctions);
    } catch (e, st) {
      print('❌ Refresh failed: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refreshAfterBid() async {
    try {
      print('🔄 Starting background refresh after bid');
      // Keep old state while refreshing
      final oldState = state;
      _clearCache();
      final auctions = await _loadAuctions(
        page: 1,
        isBackgroundRefresh: true,
      );
      print('✅ Got ${auctions.length} auctions in background refresh');
      state = AsyncValue.data(auctions);

      // Refresh balances
      final balanceService = ref.read(balanceServiceProvider);
      await balanceService.getBalances(forceRefresh: true);
    } catch (e) {
      print('❌ Background refresh failed: $e');
    }
  }

  Future<void> refreshAfterNewAuction() async {
    await refresh();
  }

  Future<void> loadMore() async {
    // This is now handled by _loadAuctions which loads all pages
  }
}

// Auctions provider
final auctionsProvider = AsyncNotifierProvider<AuctionsNotifier, List<Auction>>(
  () => AuctionsNotifier(),
); 