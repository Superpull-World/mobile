import 'dart:convert';
import 'dart:typed_data';
import 'package:solana/solana.dart';
import 'package:solana/dto.dart';
import 'dart:math';
import '../models/balance_data.dart';
import 'refresh_manager.dart';

class BalanceService with RefreshManager<BalanceData> {
  final SolanaClient _client;
  late final Ed25519HDKeyPair _keypair;
  bool _isInitialized = false;
  final Map<String, String> _trackedTokens = {};
  BalanceData? _lastKnownBalances;

  BalanceService._({
    required SolanaClient client,
  }) : _client = client;

  factory BalanceService() {
    final client = SolanaClient(
      rpcUrl: Uri.parse('https://devnet.helius-rpc.com/?api-key=aba47ae5-35c9-4168-bf7c-3f6fcf5cc299'),
      websocketUrl: Uri.parse('wss://devnet.helius-rpc.com/?api-key=aba47ae5-35c9-4168-bf7c-3f6fcf5cc299'),
    );
    return BalanceService._(client: client);
  }

  Future<void> initialize(Ed25519HDKeyPair keypair) async {
    _keypair = keypair;
    _isInitialized = true;
    print('🔑 Balance service initialized with public key: ${_keypair.publicKey.toBase58()}');
    
    // Start with empty balances and begin periodic refresh
    await _fetchBalances();
    startPeriodicRefresh(_fetchBalances);
  }

  void trackToken(String tokenMint) {
    if (_trackedTokens.containsKey(tokenMint)) {
      print('💰 Token $tokenMint already being tracked');
      // Return the cached balance if available
      if (_lastKnownBalances?.tokenBalances.containsKey(tokenMint) ?? false) {
        print('💰 Using cached balance for $tokenMint: ${_lastKnownBalances!.tokenBalances[tokenMint]}');
      }
      return;
    }
    print('💰 Started tracking token: $tokenMint');
    _trackedTokens[tokenMint] = tokenMint;
    // Force a refresh to get the balance for the new token
    forceRefresh(_fetchBalances);
  }

  Future<BalanceData> getBalances({bool forceRefresh = false}) async {
    if (!_isInitialized) {
      throw Exception('Balance service not initialized');
    }

    print('💰 Balance check requested:');
    print('   Force refresh: $forceRefresh');
    print('   Tracked tokens: ${_trackedTokens.length}');

    if (forceRefresh) {
      print('💰 Forcing balance refresh...');
      final freshBalances = await _fetchBalances(forceRefresh: true);
      _lastKnownBalances = freshBalances;
      return await this.forceRefresh(() => Future.value(freshBalances));
    }
    
    final hasCache = hasValidCache;
    print('💰 Cache status: ${hasCache ? 'valid' : 'invalid'}');
    
    // Return last known balances if cache is valid
    if (hasCache && _lastKnownBalances != null) {
      print('💰 Using cached balances');
      return _lastKnownBalances!;
    }
    
    final balances = await getDataWithRefresh(() => _fetchBalances(forceRefresh: false));
    _lastKnownBalances = balances;
    return balances;
  }

  Future<BalanceData> _fetchBalances({bool forceRefresh = false}) async {
    if (!_isInitialized) {
      throw Exception('Balance service not initialized');
    }

    print('💰 Fetching fresh balances...');
    try {
      // Get SOL balance
      final solBalance = await _client.rpcClient.getBalance(
        _keypair.publicKey.toBase58(),
        commitment: Commitment.confirmed,
      );
      print('💰 SOL balance: ${solBalance.value / lamportsPerSol}');

      // Get token balances
      final tokenBalances = <String, double>{};
      
      // Only preserve existing balances if not force refreshing
      if (!forceRefresh && _lastKnownBalances != null) {
        print('💰 Preserving existing balances');
        tokenBalances.addAll(_lastKnownBalances!.tokenBalances);
      } else {
        print('💰 Starting with fresh balances');
      }
      
      // Update balances for tracked tokens
      for (final tokenMint in _trackedTokens.keys) {
        try {
          print('💰 Checking balance for token: $tokenMint');
          final tokenAccounts = await _client.rpcClient.getTokenAccountsByOwner(
            _keypair.publicKey.toBase58(),
            TokenAccountsFilter.byMint(tokenMint),
            encoding: Encoding.jsonParsed,
            commitment: Commitment.confirmed,
          );

          if (tokenAccounts.value.isNotEmpty) {
            final tokenAccount = tokenAccounts.value.first;
            final tokenAccountBalance = await _client.rpcClient.getTokenAccountBalance(tokenAccount.pubkey);
            final amount = tokenAccountBalance.value.uiAmountString;
            if (amount != null) {
              tokenBalances[tokenMint] = double.parse(amount);
              print('💰 Token balance: $amount');
            }
          } else {
            print('💰 No token account found, setting balance to 0');
            tokenBalances[tokenMint] = 0.0;
          }
        } catch (e) {
          print('❌ Error getting token balance for $tokenMint: $e');
          // Only keep last known balance if not force refreshing
          if (!forceRefresh && tokenBalances.containsKey(tokenMint)) {
            print('💰 Keeping last known balance for $tokenMint');
          } else {
            tokenBalances[tokenMint] = 0.0;
          }
        }
      }

      final result = BalanceData(
        solBalance: solBalance.value / lamportsPerSol,
        tokenBalances: tokenBalances,
      );
      print('💰 Balance refresh complete');
      print('   SOL: ${result.solBalance}');
      print('   Tokens: ${result.tokenBalances}');
      return result;
    } catch (e) {
      print('❌ Error fetching balances: $e');
      throw Exception('Failed to fetch balances: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
    _trackedTokens.clear();
    _lastKnownBalances = null;
  }
} 