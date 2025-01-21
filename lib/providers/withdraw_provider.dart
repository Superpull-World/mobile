import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/withdraw_service.dart';

// Create a provider that takes a WidgetRef and returns a WithdrawService
final withdrawServiceProvider = Provider.family<WithdrawService, WidgetRef>(
  (ref, widgetRef) => WithdrawService(ref: widgetRef),
); 