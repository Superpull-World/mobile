import 'package:superpull_mobile/models/listing.dart';
import 'package:superpull_mobile/services/workflow_service.dart';

class AuctionService {
  final WorkflowService _workflowService = WorkflowService();

  Future<Map<String, dynamic>> startGetAuctionsWorkflow({
    String? merkleTree,
    String? authority,
    bool? isGraduated,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      return await _workflowService.executeWorkflow(
        'getAuctions',
        {
          'merkleTree': merkleTree,
          'authority': authority,
          'isGraduated': isGraduated,
          'limit': limit,
          'offset': offset,
        },
      );
    } catch (e) {
      print('❌ Error starting auctions workflow: $e');
      throw Exception('Failed to start auctions workflow: $e');
    }
  }

  Future<WorkflowStatus> getWorkflowStatus(String workflowId) async {
    try {
      final result = await _workflowService.queryWorkflow(
        workflowId,
        'status',
      );
      
      final status = result['queries']?['status'] as String? ?? 'unknown';
      return WorkflowStatus(
        isCompleted: status == 'completed',
        isFailed: status.startsWith('failed'),
        message: status,
      );
    } catch (e) {
      print('❌ Error getting workflow status: $e');
      throw Exception('Failed to get workflow status: $e');
    }
  }

  Future<List<Listing>> getWorkflowResult(String workflowId) async {
    try {
      final result = await _workflowService.queryWorkflow(
        workflowId,
        'auctionsResult',
      );

      final auctionsResult = result['queries']?['auctionsResult'] as Map<String, dynamic>?;
      if (auctionsResult == null) {
        throw Exception('No auctions result in workflow response');
      }

      final auctionsData = auctionsResult['auctions'] as List<dynamic>;
      return auctionsData
          .map((auction) => Listing.fromAuction(auction as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error getting workflow result: $e');
      throw Exception('Failed to get workflow result: $e');
    }
  }

  Future<Listing> getAuctionDetails(String auctionAddress) async {
    try {
      final result = await _workflowService.executeWorkflow(
        'getAuctionDetails',
        {'auctionAddress': auctionAddress},
      );

      if (result['result'] == null) {
        throw Exception('No result in workflow response');
      }

      final workflowResult = result['result'] as Map<String, dynamic>;
      if (workflowResult['status'] == 'failed' || workflowResult['auction'] == null) {
        throw Exception(workflowResult['message'] ?? 'Failed to fetch auction details');
      }

      return Listing.fromAuction(workflowResult['auction'] as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error in getAuctionDetails: $e');
      throw Exception('Failed to fetch auction details: $e');
    }
  }
}

class WorkflowStatus {
  final bool isCompleted;
  final bool isFailed;
  final String message;

  const WorkflowStatus({
    required this.isCompleted,
    required this.isFailed,
    required this.message,
  });
} 