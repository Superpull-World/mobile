import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/token_service.dart';
import '../services/balance_service.dart';
import '../services/workflow_service.dart';

final workflowServiceProvider = Provider<WorkflowService>((ref) => WorkflowService());

final tokenServiceProvider = Provider<TokenService>((ref) {
  final workflowService = ref.watch(workflowServiceProvider);
  return TokenService(workflowService: workflowService);
});

final balanceServiceProvider = Provider<BalanceService>((ref) => BalanceService()); 