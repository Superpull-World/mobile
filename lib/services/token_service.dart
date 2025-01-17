import 'dart:convert';
import 'package:superpull_mobile/models/token_metadata.dart';
import 'package:superpull_mobile/services/workflow_service.dart';
import 'package:superpull_mobile/services/refresh_manager.dart';

class TokenService with RefreshManager<List<TokenMetadata>> {
  final WorkflowService _workflowService;
  static const refreshInterval = Duration(minutes: 30);
  List<TokenMetadata>? _cachedTokens;
  bool _isFetching = false;

  TokenService({required WorkflowService workflowService}) 
      : _workflowService = workflowService {
    // Start periodic refresh every 30 minutes
    startPeriodicRefresh(_fetchTokens, interval: refreshInterval);
  }

  Future<List<TokenMetadata>> getAcceptedTokens() async {
    print('🪙 Token fetch requested');
    if (_cachedTokens != null) {
      print('🪙 Returning cached tokens');
      return _cachedTokens!;
    }
    
    // If already fetching, wait for the current fetch
    while (_isFetching) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    if (_cachedTokens == null) {
      return _fetchTokens();
    }
    
    return _cachedTokens!;
  }

  Future<List<TokenMetadata>> _fetchTokens() async {
    if (_isFetching) {
      print('🪙 Already fetching tokens, waiting...');
      while (_isFetching) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _cachedTokens!;
    }

    _isFetching = true;
    try {
      print('🪙 Fetching fresh token data...');
      final result = await _workflowService.executeWorkflow(
        'getAcceptedTokenMints',
        {},
      );
      
      final workflowId = result['id'] as String;
      print('🪙 Waiting for workflow completion: $workflowId');
      
      while (true) {
        final workflowResult = await _workflowService.queryWorkflow(workflowId, 'tokenMintsResult');
        final status = workflowResult['queries']?['status'] as String?;
        
        if (status == 'completed') {
          final data = workflowResult['queries']?['tokenMintsResult'] as Map<String, dynamic>;
          final List<dynamic> tokens = data['tokenMints'] as List<dynamic>;
          print('🪙 Received ${tokens.length} tokens');
          
          _cachedTokens = tokens.map((json) {
            return TokenMetadata.fromJson(json as Map<String, dynamic>);
          }).toList();
          
          print('🪙 Token refresh complete');
          return _cachedTokens!;
        } else if (status == 'failed') {
          throw Exception('Workflow failed: ${workflowResult['queries']?['error']}');
        }
        
        await Future.delayed(const Duration(seconds: 1));
      }
    } catch (e) {
      print('❌ Error fetching tokens: $e');
      rethrow;
    } finally {
      _isFetching = false;
    }
  }
} 