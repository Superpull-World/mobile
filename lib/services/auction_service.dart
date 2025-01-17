import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superpull_mobile/models/auction.dart';
import 'package:superpull_mobile/models/token_metadata.dart';
import 'package:superpull_mobile/services/refresh_manager.dart';
import 'package:superpull_mobile/services/workflow_service.dart';
import 'package:superpull_mobile/services/token_service.dart';
import 'package:superpull_mobile/providers/token_provider.dart';

class AuctionListData {
  final List<Auction> auctions;
  final int total;

  const AuctionListData({
    required this.auctions,
    required this.total,
  });
}

class AuctionService with RefreshManager<AuctionListData> {
  final WorkflowService _workflowService;
  final TokenService _tokenService;
  final Ref _ref;

  AuctionService({
    required WorkflowService workflowService,
    required TokenService tokenService,
    required Ref ref,
  }) : _workflowService = workflowService,
       _tokenService = tokenService,
       _ref = ref {
    // Start periodic refresh every 30 seconds
    startPeriodicRefresh(
      () => getAuctions(page: 1, limit: 10),
      interval: const Duration(seconds: 30),
    );
  }

  Future<AuctionListData> getAuctions({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    try {
      print('🌐 Executing workflow for page $page (limit: $limit)');
      final result = await _workflowService.executeWorkflow(
        'getAuctions',
        {
          'page': page,
          'limit': limit,
          if (status != null) 'status': status,
        },
      );
      
      final workflowId = result['id'] as String;
      
      // Poll for workflow result
      while (true) {
        final workflowResult = await _workflowService.queryWorkflow(workflowId, 'auctionsResult');
        final status = workflowResult['queries']?['status'] as String?;
        
        if (status == 'completed') {
          final auctionsData = workflowResult['queries']?['auctionsResult'] as Map<String, dynamic>;
          final List<dynamic> auctionsList = auctionsData['auctions'] as List<dynamic>;
          final int total = auctionsData['total'] as int;

          final auctions = await Future.wait(
            auctionsList.map((auction) async {
              final auctionData = auction as Map<String, dynamic>;
              final tokenMint = auctionData['tokenMint'] as String;
              
              // Get token metadata from provider
              final tokenMetadata = _ref.read(tokenByMintProvider(tokenMint));
              if (tokenMetadata != null) {
                auctionData['tokenMetadata'] = tokenMetadata.toJson();
              }
              
              return Auction.fromJson(auctionData);
            }),
          );

          return AuctionListData(auctions: auctions, total: total);
        } else if (status == 'failed') {
          throw Exception('Workflow failed: ${workflowResult['queries']?['error']}');
        }
        
        await Future.delayed(const Duration(seconds: 1));
      }
    } catch (e) {
      print('❌ Error fetching auctions: $e');
      throw Exception('Failed to fetch auctions: $e');
    }
  }
} 