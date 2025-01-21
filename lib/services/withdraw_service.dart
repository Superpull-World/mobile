import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/workflow_service.dart';
import '../services/wallet_service.dart';
import '../models/auction.dart';

class WithdrawService {
  final _workflowService = WorkflowService();
  final _walletService = WalletService();
  final WidgetRef _ref;

  WithdrawService({required WidgetRef ref}) : _ref = ref;

  Future<void> withdrawAuction(Auction auction, String jwt) async {
    try {
      // Get the authority's address from wallet service
      final keypair = await _walletService.getKeypair();
      if (keypair == null) {
        throw Exception('No wallet keypair available');
      }

      final authorityAddress = keypair.publicKey.toBase58();
      
      // Verify the caller is the auction authority
      if (auction.authority != authorityAddress) {
        throw Exception('Only the auction authority can withdraw');
      }

      // Start the withdraw auction workflow
      final result = await _workflowService.executeWorkflow(
        'withdrawAuction',
        {
          'auctionAddress': auction.id,
          'authorityAddress': authorityAddress,
          'jwt': jwt,
        },
      );

      final workflowId = result['id'] as String;
      bool isComplete = false;
      String? error;

      while (!isComplete) {
        try {
          // Query workflow status
          final statusResult = await _workflowService.queryWorkflow(
            workflowId,
            'status',
          );
          final status = statusResult['queries']?['status'] as String? ?? 'unknown';

          if (status == 'completed' || status == 'failed' || status.startsWith('failed:')) {
            isComplete = true;
          } else {
            await Future.delayed(const Duration(seconds: 2));
          }
        } catch (e) {
          print('❌ Error checking workflow status: $e');
          error = e.toString();
          isComplete = true;
        }
      }

      if (error != null) {
        throw Exception(error);
      }

      print('✅ Auction withdrawn successfully');
      return; // Return normally on success
    } catch (e) {
      print('❌ Error in withdraw auction workflow: $e');
      throw Exception('Failed to withdraw auction: $e'); // Re-throw the error to be handled by the UI
    }
  }
} 