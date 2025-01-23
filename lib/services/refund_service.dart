import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auction.dart';
import '../services/workflow_service.dart';

class RefundService {
  final WidgetRef ref;
  final WorkflowService _workflowService = WorkflowService();

  RefundService({required this.ref});

  Future<void> refundAuction(Auction auction, String jwt) async {
    try {
      await _workflowService.executeWorkflow(
        'refund',
        {
          'auctionAddress': auction.id,
          'bidderAddress': auction.bids.first.bidder,
          'jwt': jwt,
        },
      );
    } catch (e) {
      throw Exception('Failed to process refund: $e');
    }
  }
} 