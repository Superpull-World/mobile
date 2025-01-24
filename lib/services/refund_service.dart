import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auction.dart';
import '../services/workflow_service.dart';
import 'package:flutter/foundation.dart';

class RefundService {
  final WidgetRef ref;
  final WorkflowService _workflowService = WorkflowService();

  RefundService({required this.ref});

  Future<void> refundAuction(Auction auction, String jwt) async {
    try {
      if (kDebugMode) {
        print('🔄 Starting Refund:');
        print('  - Auction: ${auction.id}');
        print('  - Bidder: ${auction.bids.first.bidder}');
      }

      // Start the workflow and get the workflow ID
      final response = await _workflowService.executeWorkflow(
        'refund',
        {
          'auctionAddress': auction.id,
          'bidderAddress': auction.bids.first.bidder,
          'jwt': jwt,
        },
      );
      
      final workflowId = response['id'] as String;
      
      if (kDebugMode) {
        print('✅ Refund Workflow Started:');
        print('  - Workflow ID: $workflowId');
      }
      
      // Wait for the workflow to complete
      await for (final status in _workflowService.queryWorkflowStatus(workflowId)) {
        if (kDebugMode) {
          print('📊 Refund Status Update:');
          print('  - Workflow ID: $workflowId');
          print('  - Status: $status');
        }

        if (status == 'completed') {
          if (kDebugMode) {
            print('✅ Refund Completed Successfully');
          }
          return;
        } else if (status == 'failed') {
          if (kDebugMode) {
            print('❌ Refund Failed');
          }
          throw Exception('Refund workflow failed');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Refund Error:');
        print('  - Error: $e');
      }
      throw Exception('Failed to process refund: $e');
    }
  }
} 