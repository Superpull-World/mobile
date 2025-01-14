import 'dart:convert';
import 'dart:typed_data';
import 'package:solana/solana.dart';
import 'package:solana/dto.dart';
import 'dart:math';

class BalanceService {
  final SolanaClient _client;
  late final Ed25519HDKeyPair _keypair;
  bool _isInitialized = false;

  // New token mint address
  static const String _tokenMint = '2u7t1UoiYF59GS3dYRQHVdAt9e1uap2WqKqKM7FbWFDv';

  BalanceService._({
    required SolanaClient client,
  }) : _client = client;

  factory BalanceService() {
    final client = SolanaClient(
      rpcUrl: Uri.parse('https://api.devnet.solana.com'),
      websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
    );
    return BalanceService._(client: client);
  }

  Future<void> initialize(Ed25519HDKeyPair keypair) async {
    _keypair = keypair;
    _isInitialized = true;
    print('🔑 Balance service initialized with public key: ${_keypair.publicKey.toBase58()}');
  }

  Future<double> getSolBalance() async {
    if (!_isInitialized) {
      print('❌ Balance service not initialized');
      return 0.0;
    }

    try {
      final balance = await _client.rpcClient.getBalance(
        _keypair.publicKey.toBase58(),
        commitment: Commitment.confirmed,
      );
      print('💰 SOL balance: ${balance.value / lamportsPerSol}');
      return balance.value / lamportsPerSol;
    } catch (e) {
      print('❌ Error getting SOL balance: $e');
      throw Exception('Failed to get SOL balance: $e');
    }
  }

  Future<double> getTokenBalance(String tokenMint) async {
    if (!_isInitialized) {
      print('❌ Balance service not initialized');
      return 0.0;
    }

    try {
      print('🔍 Fetching token balance for:');
      print('   Token mint: $tokenMint');
      print('   Owner: ${_keypair.publicKey.toBase58()}');
      
      final tokenAccounts = await _client.rpcClient.getTokenAccountsByOwner(
        _keypair.publicKey.toBase58(),
        TokenAccountsFilter.byMint(tokenMint),
        encoding: Encoding.jsonParsed,
        commitment: Commitment.confirmed,
      );

      if (tokenAccounts.value.isEmpty) {
        print('ℹ️ No token accounts found, returning 0');
        return 0.0;
      }

      final tokenAccount = tokenAccounts.value.first;
      final tokenAccountBalance = await _client.rpcClient.getTokenAccountBalance(tokenAccount.pubkey);
      print('📝 Token account balance response: $tokenAccountBalance');
      
      final amount = tokenAccountBalance.value.uiAmountString;
      if (amount == null) {
        print('❌ No UI amount found in balance');
        return 0.0;
      }

      final adjustedAmount = double.parse(amount);
      print('💎 Token balance: $adjustedAmount');
      return adjustedAmount;
    } catch (e) {
      print('❌ Error getting token balance: $e');
      print('   Stack trace: ${StackTrace.current}');
      throw Exception('Failed to get token balance: $e');
    }
  }
} 