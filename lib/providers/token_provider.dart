import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superpull_mobile/models/token_metadata.dart';
import 'package:superpull_mobile/services/token_service.dart';
import 'package:superpull_mobile/services/workflow_service.dart';

final workflowServiceProvider = Provider((ref) => WorkflowService());

final tokenServiceProvider = Provider((ref) => TokenService(
      workflowService: ref.watch(workflowServiceProvider),
    ));

final acceptedTokensProvider = FutureProvider<List<TokenMetadata>>((ref) async {
  final tokenService = ref.watch(tokenServiceProvider);
  return tokenService.getAcceptedTokens();
}); 