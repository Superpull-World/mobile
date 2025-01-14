import 'package:superpull_mobile/models/auction.dart';
import 'package:superpull_mobile/services/workflow_service.dart';

class AuctionService {
  final _workflowService = WorkflowService();

  Future<String?> startGetAuctionsWorkflow({
    required int limit,
    required int offset,
  }) async {
    try {
      final result = await _workflowService.executeWorkflow(
        'getAuctions',
        {
          'limit': limit,
          'offset': offset,
        },
      );
      return result['id'] as String?;
    } catch (e) {
      print('Error starting auctions workflow: $e');
      return null;
    }
  }

  Future<WorkflowStatus> getWorkflowStatus(String workflowId) async {
    try {
      final result = await _workflowService.queryWorkflow(workflowId, 'status');
      
      final statusData = result['queries']?['status'];
      if (statusData == null) {
        return WorkflowStatus(
          isCompleted: false,
          isFailed: false,
          message: 'pending',
        );
      }

      final status = statusData.toString();
      return WorkflowStatus(
        isCompleted: status == 'completed',
        isFailed: status == 'failed',
        message: status,
      );
    } catch (e) {
      print('Error getting workflow status: $e');
      return WorkflowStatus(
        isCompleted: false,
        isFailed: true,
        message: e.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> getWorkflowResult(String workflowId) async {
    try {
      final result = await _workflowService.queryWorkflow(workflowId, 'auctionsResult');
      return result;
    } catch (e) {
      print('Error getting workflow result: $e');
      return {'queries': null};
    }
  }

  Future<Auction> getAuctionDetails(String workflowId) async {
    try {
      final workflowResult = await _workflowService.queryWorkflow(workflowId, 'auctionResult');
      return Auction.fromJson(workflowResult['auction'] as Map<String, dynamic>);
    } catch (e) {
      print('Error getting auction details: $e');
      throw Exception('Failed to get auction details: $e');
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