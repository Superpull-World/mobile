import 'package:superpull_mobile/models/auction.dart';
import 'package:superpull_mobile/services/workflow_service.dart';
import 'package:superpull_mobile/services/token_service.dart';
import 'package:superpull_mobile/models/token_metadata.dart';

class AuctionService {
  final _workflowService = WorkflowService();
  final _tokenService = TokenService(workflowService: WorkflowService());

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
      // Get all token metadata first
      final tokens = await _tokenService.getAcceptedTokens();
      
      // Get auction details from workflow
      final workflowResult = await _workflowService.queryWorkflow(workflowId, 'auctionResult');
      final auctionData = workflowResult['auction'] as Map<String, dynamic>;
      
      // Find the token metadata for this auction
      final tokenMint = auctionData['tokenMint'] as String;
      final tokenMetadata = tokens.firstWhere(
        (token) => token.mint == tokenMint,
        orElse: () => TokenMetadata(
          mint: tokenMint,
          name: 'Unknown Token',
          symbol: 'UNKNOWN',
          uri: '',
          decimals: 9,
          supply: '0',
        ),
      );
      
      // Add token metadata to auction data
      auctionData['tokenMetadata'] = tokenMetadata.toJson();
      
      return Auction.fromJson(auctionData);
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