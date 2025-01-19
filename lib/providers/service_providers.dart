import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/token_service.dart';
import '../services/workflow_service.dart';
import '../services/creator_service.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';

final walletServiceProvider = Provider((ref) => WalletService());

final workflowServiceProvider = Provider<WorkflowService>((ref) => WorkflowService());

final authServiceProvider = Provider((ref) => AuthService());

final tokenServiceProvider = Provider((ref) {
  final workflowService = ref.watch(workflowServiceProvider);
  final authService = ref.watch(authServiceProvider);
  return TokenService(
    workflowService: workflowService,
    authService: authService,
  );
});

final creatorServiceProvider = Provider<CreatorService>((ref) {
  final workflowService = ref.watch(workflowServiceProvider);
  return CreatorService(workflowService: workflowService);
}); 