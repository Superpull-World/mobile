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
  AuctionListData? _cachedData;

  AuctionService({
    required WorkflowService workflowService,
    required TokenService tokenService,
    required Ref ref,
  }) : _workflowService = workflowService,
       _tokenService = tokenService,
       _ref = ref {
    // Start periodic refresh every 10 minutes
    startPeriodicRefresh(
      () => getAuctions(page: 1, limit: 10),
      interval: const Duration(minutes: 10),
    );
  }

  AuctionListData? get cachedData => _cachedData;

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
          final auctionsList = workflowResult['queries']?['auctionsResult'] as List<dynamic>;
          final int total = auctionsList.length; // Since we don't have a separate total, use the list length

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

          final listData = AuctionListData(auctions: auctions, total: total);
          _cachedData = listData;
          return listData;
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

  Future<void> createAuction({
    required String name,
    required String description,
    required String imageUrl,
    required double price,
    required String ownerAddress,
    required int maxSupply,
    required int minimumItems,
    required DateTime deadline,
    required String jwt,
    required String tokenMint,
    required Function(String) onStatusUpdate,
  }) async {
    try {
      final unixTimestamp = deadline.millisecondsSinceEpoch ~/ 1000;
      
      final result = await _workflowService.executeWorkflow(
        'createAuction',
        {
          'name': name,
          'description': description,
          'imageUrl': imageUrl,
          'price': price,
          'ownerAddress': ownerAddress,
          'maxSupply': maxSupply,
          'minimumItems': minimumItems,
          'deadline': unixTimestamp,
          'jwt': jwt,
          'tokenMint': tokenMint,
        },
      );

      final workflowId = result['id'] as String;
      bool isComplete = false;
      String finalStatus = '';

      while (!isComplete) {
        try {
          final statusResult = await _workflowService.queryWorkflow(
            workflowId,
            'status',
          );
          final status = statusResult['queries']?['status'] as String? ?? 'unknown';
          finalStatus = status;

          // Map status to user-friendly message
          String displayStatus = switch (status.toLowerCase()) {
            'running' => 'Creating auction...',
            'verifying-jwt' => 'Verifying credentials...',
            'uploading-metadata' => 'Uploading metadata...',
            'creating-merkle-tree' => 'Creating Merkle tree...',
            'initializing-auction' => 'Initializing auction...',
            'creating-collection-nft' => 'Creating collection NFT...',
            'verifying-collection' => 'Verifying collection...',
            'updating-collection-authority' => 'Updating collection authority...',
            'completed' => 'Completed',
            'failed' => 'Failed',
            String s when s.endsWith('-failed') => 'Failed: ${s.split('-').first}',
            _ => 'Processing...',
          };

          onStatusUpdate(displayStatus);

          if (status.toLowerCase() == 'completed') {
            isComplete = true;
            result['status'] = 'success';
            break;
          } else if (status.toLowerCase() == 'failed' || 
                    status.toLowerCase().endsWith('-failed')) {
            isComplete = true;
            result['status'] = 'failed';
            break;
          }

          await Future.delayed(const Duration(seconds: 2));
        } catch (e) {
          print('❌ Error checking workflow status: $e');
          onStatusUpdate('Failed: $e');
          isComplete = true;
          throw e;
        }
      }

      if (result['status'] != 'success') {
        throw Exception(finalStatus);
      }
    } catch (e) {
      print('❌ Error creating auction: $e');
      throw Exception('Failed to create auction: $e');
    }
  }
} 