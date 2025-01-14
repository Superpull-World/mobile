import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superpull_mobile/models/auction.dart';
import 'package:superpull_mobile/services/auction_service.dart';
import 'dart:async';

final auctionsProvider = AsyncNotifierProvider<AuctionsNotifier, List<Auction>>(() {
  return AuctionsNotifier();
});

class AuctionsNotifier extends AsyncNotifier<List<Auction>> {
  Timer? _refreshTimer;
  static const Duration _refreshInterval = Duration(seconds: 5);
  final _auctionService = AuctionService();

  @override
  Future<List<Auction>> build() async {
    ref.onDispose(() {
      _refreshTimer?.cancel();
    });
    
    // Start background polling
    _startPeriodicRefresh();
    return _fetchAuctions();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      _backgroundRefresh();
    });
  }

  Future<void> _backgroundRefresh() async {
    try {
      final newAuctions = await _fetchAuctions();
      state = AsyncData<List<Auction>>(newAuctions);
    } catch (e) {
      // On error, keep the current state
      print('Background refresh failed: $e');
    }
  }

  List<Auction> _sortAuctions(List<Auction> auctions) {
    // First sort by graduation status
    auctions.sort((a, b) {
      // Non-graduated auctions come first
      if (!a.isGraduated && b.isGraduated) return -1;
      if (a.isGraduated && !b.isGraduated) return 1;

      // Then sort by deadline
      final deadlineCompare = a.saleEndDate.compareTo(b.saleEndDate);
      if (deadlineCompare != 0) return deadlineCompare;

      // Then by remaining capacity (more remaining comes first)
      final aRemaining = a.maxSupply - a.currentSupply;
      final bRemaining = b.maxSupply - b.currentSupply;
      final remainingCompare = bRemaining.compareTo(aRemaining);
      if (remainingCompare != 0) return remainingCompare;

      // Finally by ID for deterministic order
      return a.id.compareTo(b.id);
    });

    return auctions;
  }

  Future<List<Auction>> _fetchAuctions() async {
    try {
      // Start the workflow
      final workflowId = await _auctionService.startGetAuctionsWorkflow(limit: 50, offset: 0);
      if (workflowId == null) {
        print('Error: No workflow ID returned');
        return [];
      }

      // Poll for completion with retries
      int retries = 0;
      const maxRetries = 3;
      
      while (retries < maxRetries) {
        final status = await _auctionService.getWorkflowStatus(workflowId);
        
        if (status.isCompleted) {
          final result = await _auctionService.getWorkflowResult(workflowId);
          
          // Check for valid result structure
          final queries = result['queries'];
          if (queries == null) {
            print('Error: No queries in result');
            return [];
          }

          final auctionsResult = queries['auctionsResult'] as Map<String, dynamic>?;
          if (auctionsResult == null) {
            print('Error: No auctionsResult in queries');
            return [];
          }

          final auctionsList = auctionsResult['auctions'] as List<dynamic>?;
          if (auctionsList == null) {
            print('Error: Invalid or missing auctions array');
            print('Raw result: $result');
            return [];
          }

          print('Found ${auctionsList.length} auctions');

          // Parse and sort auctions
          final List<Auction> parsedAuctions = auctionsList
              .map((auction) => Auction.fromJson(auction as Map<String, dynamic>))
              .toList();

          return _sortAuctions(parsedAuctions);
        }

        if (status.isFailed) {
          print('Workflow failed: ${status.message}');
          return [];
        }

        // Wait before retrying
        await Future.delayed(const Duration(seconds: 1));
        retries++;
      }

      print('Workflow did not complete after $maxRetries retries');
      return [];

    } catch (e, stackTrace) {
      print('Error fetching auctions: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<void> refresh() async {
    // For manual refresh, show loading state but keep previous data visible
    state = AsyncValue<List<Auction>>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _fetchAuctions());
  }
} 