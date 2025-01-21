import 'package:superpull_mobile/services/workflow_service.dart';
import 'package:superpull_mobile/services/refresh_manager.dart';

class CreatorService with RefreshManager<List<String>> {
  final WorkflowService _workflowService;
  static const refreshInterval = Duration(minutes: 30);
  static const cacheExpiration = Duration(minutes: 5);
  List<String>? _cachedCreators;
  DateTime? _lastFetchTime;
  bool _isFetching = false;

  CreatorService({required WorkflowService workflowService}) 
      : _workflowService = workflowService {
    // Start periodic refresh every 30 minutes
    startPeriodicRefresh(_fetchCreators, interval: refreshInterval);
  }

  @override
  void dispose() {
    stopPeriodicRefresh();
  }

  List<String>? get cachedCreators => _cachedCreators;
  
  bool get isCacheValid => _cachedCreators != null && 
    _lastFetchTime != null && 
    DateTime.now().difference(_lastFetchTime!) < cacheExpiration;

  bool get _isCacheValid => isCacheValid;

  Future<List<String>> getAllowedCreators() async {
    print('👥 Creators fetch requested');
    if (_isCacheValid) {
      print('👥 Returning cached creators (age: ${DateTime.now().difference(_lastFetchTime!).inSeconds}s)');
      return _cachedCreators!;
    }
    
    // If already fetching, wait for the current fetch
    while (_isFetching) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // Cache expired or doesn't exist, fetch fresh data
    return _fetchCreators();
  }

  Future<List<String>> _fetchCreators() async {
    if (_isFetching) {
      throw Exception('Already fetching creators');
    }

    _isFetching = true;
    try {
      print('👥 Fetching fresh creator data...');
      final result = await _workflowService.executeWorkflow(
        'getAllowedCreators',
        {},
      );
      
      final workflowId = result['id'] as String;
      print('👥 Waiting for workflow completion: $workflowId');
      
      while (true) {
        final workflowResult = await _workflowService.queryWorkflow(workflowId, 'creatorsResult');
        final status = workflowResult['queries']?['status'] as String?;
        
        if (status == 'completed') {
          final data = workflowResult['queries']?['creatorsResult'] as Map<String, dynamic>;
          final List<dynamic> creators = data['creators'] as List<dynamic>;
          print('👥 Received ${creators.length} creators');
          
          _cachedCreators = creators.cast<String>();
          _lastFetchTime = DateTime.now();
          
          print('👥 Creator refresh complete');
          return _cachedCreators!;
        } else if (status == 'failed') {
          throw Exception('Workflow failed: ${workflowResult['queries']?['error']}');
        }
        
        await Future.delayed(const Duration(seconds: 1));
      }
    } catch (e) {
      print('❌ Error fetching creators: $e');
      rethrow;
    } finally {
      _isFetching = false;
    }
  }
} 