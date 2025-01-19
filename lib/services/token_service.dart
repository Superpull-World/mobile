import 'dart:convert';
import 'package:superpull_mobile/models/token_metadata.dart';
import 'package:superpull_mobile/services/workflow_service.dart';
import 'package:superpull_mobile/services/refresh_manager.dart';
import 'package:superpull_mobile/services/wallet_service.dart';
import 'package:superpull_mobile/services/auth_service.dart';

class TokenService with RefreshManager<List<TokenMetadata>> {
  final WorkflowService _workflowService;
  final WalletService _walletService;
  final AuthService _authService;
  static const refreshInterval = Duration(minutes: 30);
  static const cacheExpiration = Duration(minutes: 5);
  List<TokenMetadata>? _cachedTokens;
  DateTime? _lastFetchTime;
  bool _isFetching = false;

  TokenService({
    required WorkflowService workflowService,
    WalletService? walletService,
    required AuthService authService,
  }) : _workflowService = workflowService,
       _walletService = walletService ?? WalletService(),
       _authService = authService {
    // Start periodic refresh every 30 minutes
    startPeriodicRefresh(_fetchTokens, interval: refreshInterval);
  }

  List<TokenMetadata>? get cachedTokens => _cachedTokens;
  
  bool get isCacheValid => _cachedTokens != null && 
    _lastFetchTime != null && 
    DateTime.now().difference(_lastFetchTime!) < cacheExpiration;

  Future<List<TokenMetadata>> getAcceptedTokens() async {
    print('🪙 Token fetch requested');
    
    if (isCacheValid) {
      print('🪙 Returning valid cached tokens (age: ${DateTime.now().difference(_lastFetchTime!).inSeconds}s)');
      return _cachedTokens!;
    }
    
    // If already fetching, wait for the current fetch
    while (_isFetching) {
      print('🪙 Already fetching tokens, waiting...');
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    if (!isCacheValid) {
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
      
      // Get wallet address and JWT
      final keypair = await _walletService.getKeypair();
      if (keypair == null) {
        throw Exception('No wallet found');
      }
      
      final jwt = await _authService.getStoredJwt();
      if (jwt == null) {
        throw Exception('No JWT found');
      }
      
      final result = await _workflowService.executeWorkflow(
        'getAcceptedTokenMints',
        {
          'walletAddress': keypair.publicKey.toBase58(),
          'jwt': jwt,
        },
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
          
          _lastFetchTime = DateTime.now();
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

  @override
  Future<List<TokenMetadata>> forceRefresh(Future<List<TokenMetadata>> Function() fetchFunction) async {
    print('🪙 Force refresh requested');
    
    // Keep old cache until we have new data
    final oldCache = _cachedTokens;
    
    try {
      return await _fetchTokens();
    } catch (e) {
      // Restore old cache on error
      _cachedTokens = oldCache;
      rethrow;
    }
  }
} 