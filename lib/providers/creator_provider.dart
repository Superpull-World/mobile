import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/creator_service.dart';
import '../services/wallet_service.dart';
import '../services/workflow_service.dart';
import 'service_providers.dart';

class CreatorState {
  final List<String>? creators;
  final bool isLoading;
  final String? error;

  const CreatorState({
    this.creators,
    this.isLoading = false,
    this.error,
  });

  CreatorState copyWith({
    List<String>? creators,
    bool? isLoading,
    String? error,
  }) {
    return CreatorState(
      creators: creators ?? this.creators,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CreatorStateNotifier extends StateNotifier<CreatorState> {
  final CreatorService _creatorService;
  
  CreatorStateNotifier(this._creatorService) : super(const CreatorState()) {
    // Initialize creators on startup
    initialize();
  }

  Future<void> initialize() async {
    if (!mounted) return;
    
    try {
      state = state.copyWith(isLoading: true);
      final creators = await _creatorService.getAllowedCreators();
      if (!mounted) return;
      state = CreatorState(creators: creators);
    } catch (e) {
      if (!mounted) return;
      state = CreatorState(error: e.toString());
    }
  }

  List<String>? get creators => state.creators;
}

// Single provider for creator service - kept alive for the entire app session
final creatorServiceProvider = Provider<CreatorService>((ref) {
  final workflowService = ref.watch(workflowServiceProvider);
  final service = CreatorService(workflowService: workflowService);
  
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

// State notifier provider that maintains the creator state - kept alive for the entire app session
final creatorStateProvider = StateNotifierProvider<CreatorStateNotifier, CreatorState>((ref) {
  print('🏗️ Creating CreatorStateNotifier');
  final service = ref.watch(creatorServiceProvider);
  return CreatorStateNotifier(service);
});

// Provider for checking if a wallet is an allowed creator - uses the shared state
final isAllowedCreatorProvider = FutureProvider.autoDispose<bool>((ref) async {
  print('🔍 Checking creator permissions');
  final creatorState = ref.watch(creatorStateProvider);
  final walletService = WalletService();
  
  if (creatorState.isLoading) {
    print('⏳ Creator state is loading');
    throw const AsyncLoading();
  }
  
  if (creatorState.error != null) {
    print('❌ Creator state has error: ${creatorState.error}');
    throw creatorState.error!;
  }
  
  final walletAddress = await walletService.getWalletAddress();
  final isAllowed = creatorState.creators?.contains(walletAddress) ?? false;
  print('✅ Creator permission check complete: $isAllowed');
  return isAllowed;
}); 