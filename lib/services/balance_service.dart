import 'package:solana/solana.dart';
import 'package:solana/dto.dart';
import 'wallet_service.dart';

class BalanceService {
  final WalletService _walletService = WalletService();
  final SolanaClient _client = SolanaClient(
    rpcUrl: Uri.parse('https://api.devnet.solana.com'),
    websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
  );
  
  // USDC token mint address on devnet
  static const String _usdcMint = 'Gh9ZwEmdLJ8DscKNTkTqPbNwLNNBjuSzaG9Vp2KGtKJr';

  Future<double> getSolBalance() async {
    try {
      final keypair = await _walletService.getKeypair();
      if (keypair == null) return 0.0;

      final balance = await _client.rpcClient.getBalance(keypair.publicKey.toBase58());
      return balance.value / lamportsPerSol;
    } catch (e) {
      print('Error fetching SOL balance: $e');
      return 0.0;
    }
  }

  Future<double> getUsdcBalance() async {
    try {
      final keypair = await _walletService.getKeypair();
      if (keypair == null) return 0.0;

      final tokenAccounts = await _client.rpcClient.getTokenAccountsByOwner(
        keypair.publicKey.toBase58(),
        TokenAccountsFilter.byMint(_usdcMint),
      );

      if (tokenAccounts.value.isEmpty) return 0.0;

      final tokenBalance = tokenAccounts.value.first.account.data as Map<String, dynamic>;
      final amount = (tokenBalance['parsed']?['info']?['tokenAmount']?['uiAmount'] as num?)?.toDouble() ?? 0.0;
      return amount;
    } catch (e) {
      print('Error fetching USDC balance: $e');
      return 0.0;
    }
  }
} 