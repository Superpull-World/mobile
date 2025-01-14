import 'dart:convert';
import 'package:superpull_mobile/models/token_metadata.dart';
import 'package:superpull_mobile/services/workflow_service.dart';

class TokenService {
  final WorkflowService _workflowService;
  List<TokenMetadata>? _cachedTokens;
  DateTime? _lastFetchTime;
  static const cacheDuration = Duration(minutes: 5);

  TokenService({required WorkflowService workflowService}) 
      : _workflowService = workflowService;

  Future<List<TokenMetadata>> getAcceptedTokens() async {
    print('🔄 Checking token cache status...');
    
    // Return cached data if it's still valid
    if (_cachedTokens != null && _lastFetchTime != null) {
      final age = DateTime.now().difference(_lastFetchTime!);
      if (age < cacheDuration) {
        print('✅ Using cached tokens (age: ${age.inSeconds}s)');
        return _cachedTokens!;
      }
      print('⚠️ Cache expired (age: ${age.inSeconds}s), fetching fresh data...');
    } else {
      print('ℹ️ No cache available, fetching tokens for the first time...');
    }

    try {
      print('🚀 Starting getAcceptedTokenMints workflow...');
      // Execute the workflow
      final result = await _workflowService.executeWorkflow(
        'getAcceptedTokenMints',
        {},
      );
      
      print('📦 Workflow response: $result');

      // Wait for workflow completion and get the result
      final workflowId = result['id'] as String;
      print('🔍 Waiting for workflow completion: $workflowId');
      
      // Poll for workflow result
      while (true) {
        final workflowResult = await _workflowService.queryWorkflow(workflowId, 'result');
        final status = workflowResult['queries']?['status'] as String?;
        
        if (status == 'completed') {
          final data = workflowResult['queries']?['result'] as Map<String, dynamic>;
          print('✅ Workflow completed: $data');
          
          final List<dynamic> tokens = data['tokenMints'];
          print('📝 Received ${tokens.length} tokens from workflow');
          
          _cachedTokens = tokens.map((json) {
            print('🪙 Processing token: ${json['mint']}');
            return TokenMetadata.fromJson(json);
          }).toList();
          
          _lastFetchTime = DateTime.now();
          print('💾 Updated cache with new token data');
          
          return _cachedTokens!;
        } else if (status == 'failed') {
          throw Exception('Workflow failed: ${workflowResult['queries']?['error']}');
        }
        
        print('⏳ Waiting for workflow result... (status: $status)');
        await Future.delayed(const Duration(seconds: 1));
      }
    } catch (e) {
      print('❌ Error fetching tokens: $e');
      // If we have cached data, return it even if expired
      if (_cachedTokens != null) {
        print('⚠️ Falling back to expired cache due to error');
        return _cachedTokens!;
      }
      rethrow;
    }
  }

  void clearCache() {
    print('🗑️ Clearing token cache');
    _cachedTokens = null;
    _lastFetchTime = null;
  }
} 