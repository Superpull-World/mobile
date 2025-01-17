import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wallet_service.dart';

final walletProvider = Provider((ref) => WalletService()); 