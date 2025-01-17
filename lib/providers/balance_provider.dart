import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../services/balance_service.dart';
import '../services/wallet_service.dart';
import '../models/balance_data.dart' show BalanceData;
import '../providers/auctions_provider.dart';

final walletServiceProvider = Provider((ref) => WalletService());

// Create a provider to handle balance service initialization
final balanceServiceInitProvider = FutureProvider<BalanceService>((ref) async {
  final walletService = ref.watch(walletServiceProvider);
  final balanceService = BalanceService();
  
  final keypair = await walletService.getKeypair();
  if (keypair != null) {
    await balanceService.initialize(keypair);
  }
  return balanceService;
});

final balanceServiceProvider = Provider((ref) {
  final balanceService = ref.watch(balanceServiceInitProvider).value;
  if (balanceService == null) return BalanceService(); // Return dummy service if not initialized
  
  final Set<String> trackedTokens = {};
  
  // Track tokens from auctions only after initialization
  ref.listen(auctionsProvider, (previous, next) {
    next.whenData((auctions) {
      for (final auction in auctions) {
        if (!trackedTokens.contains(auction.tokenMint)) {
          trackedTokens.add(auction.tokenMint);
          balanceService.trackToken(auction.tokenMint);
        }
      }
    });
  });

  return balanceService;
});

// Create a state notifier to handle balance updates
class BalanceNotifier extends StateNotifier<AsyncValue<BalanceData>> {
  final Ref ref;
  StreamSubscription? _balanceSubscription;
  
  BalanceNotifier(this.ref) : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final balanceServiceAsync = ref.read(balanceServiceInitProvider);
      
      // Listen to balance service initialization
      ref.listen(balanceServiceInitProvider, (previous, next) {
        next.whenData((balanceService) {
          // Cancel existing subscription if any
          _balanceSubscription?.cancel();
          
          // Subscribe to balance updates
          _balanceSubscription = balanceService.dataStream.listen((balances) {
            if (mounted) {
              state = AsyncValue.data(balances);
            }
          });
          
          _fetchBalances();
        });
      });

      // Initial fetch if service is already available
      balanceServiceAsync.whenData((balanceService) {
        // Subscribe to balance updates
        _balanceSubscription = balanceService.dataStream.listen((balances) {
          if (mounted) {
            state = AsyncValue.data(balances);
          }
        });
        
        _fetchBalances();
      });
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchBalances() async {
    try {
      // Only set loading state on initial fetch
      if (state is! AsyncData) {
        state = const AsyncValue.loading();
      }
      final balanceService = await ref.read(balanceServiceInitProvider.future);
      final balances = await balanceService.getBalances(forceRefresh: true);
      if (mounted) {
        state = AsyncValue.data(balances);
      }
    } catch (e) {
      if (mounted) {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  Future<void> refresh() async {
    try {
      final balanceService = await ref.read(balanceServiceInitProvider.future);
      // Don't set loading state to avoid UI flicker
      final balances = await balanceService.getBalances(forceRefresh: true);
      if (mounted) {
        state = AsyncValue.data(balances);
      }
    } catch (e) {
      if (mounted) {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }
}

final balanceProvider = StateNotifierProvider<BalanceNotifier, AsyncValue<BalanceData>>((ref) {
  return BalanceNotifier(ref);
}); 