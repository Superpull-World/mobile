import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BlockchainType {
  solana,
  flow;

  String get displayName => name[0].toUpperCase() + name.substring(1);
}

class ChainService extends ChangeNotifier {
  static const String _chainKey = 'selected_chain';
  BlockchainType _selectedChain = BlockchainType.solana;
  static final ChainService _instance = ChainService._internal();

  ChainService._internal() {
    _loadSelectedChain();
  }

  factory ChainService() {
    return _instance;
  }

  BlockchainType get selectedChain => _selectedChain;

  Future<void> _loadSelectedChain() async {
    final prefs = await SharedPreferences.getInstance();
    final chainName = prefs.getString(_chainKey);
    if (chainName != null) {
      _selectedChain = BlockchainType.values.firstWhere(
        (chain) => chain.name == chainName,
        orElse: () => BlockchainType.solana,
      );
      notifyListeners();
    }
  }

  Future<void> setSelectedChain(BlockchainType chain) async {
    if (_selectedChain != chain) {
      _selectedChain = chain;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chainKey, chain.name);
      notifyListeners();
    }
  }
} 