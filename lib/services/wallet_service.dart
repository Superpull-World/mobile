import 'package:solana/solana.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletService {
  static const String _walletKey = 'wallet_key';
  static const String _firstTimeKey = 'first_time_key';
  final _storage = const FlutterSecureStorage();

  Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstTimeKey) ?? true;
  }

  Future<void> setFirstTime(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstTimeKey, value);
  }

  Future<String> createWallet() async {
    final mnemonic = bip39.generateMnemonic();
    final seed = bip39.mnemonicToSeed(mnemonic);
    final keypair = await Ed25519HDKeyPair.fromSeedWithHdPath(
      seed: seed,
      hdPath: "m/44'/501'/0'/0'",
    );
    
    // Store mnemonic securely
    await _storage.write(key: _walletKey, value: mnemonic);
    
    return mnemonic;
  }

  Future<String?> getMnemonic() async {
    return await _storage.read(key: _walletKey);
  }

  Future<Ed25519HDKeyPair?> getKeypair() async {
    final mnemonic = await getMnemonic();
    if (mnemonic == null) return null;
    
    final seed = bip39.mnemonicToSeed(mnemonic);
    return await Ed25519HDKeyPair.fromSeedWithHdPath(
      seed: seed,
      hdPath: "m/44'/501'/0'/0'",
    );
  }

  Future<String> getWalletAddress() async {
    final keypair = await getKeypair();
    if (keypair == null) {
      throw Exception('No wallet found. Please create a wallet first.');
    }
    return keypair.publicKey.toBase58();
  }
} 