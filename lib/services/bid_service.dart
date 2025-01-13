import 'dart:async';
import 'package:superpull_mobile/services/workflow_service.dart';
import 'package:superpull_mobile/services/wallet_service.dart';

class BidService {
  final WorkflowService _workflowService = WorkflowService();
  final WalletService _walletService = WalletService();

  Future<Map<String, dynamic>> startPlaceBidWorkflow({
    required String auctionAddress,
    required double bidAmount,
    required Function(String) onStatusUpdate,
  }) async {
    try {
      // Get the bidder's address from wallet service
      final keypair = await _walletService.getKeypair();
      if (keypair == null) {
        throw Exception('No wallet keypair available');
      }

      final bidderAddress = keypair.publicKey.toBase58();

      // Start the place bid workflow
      final result = await _workflowService.executeWorkflow(
        'placeBid',
        {
          'auctionAddress': auctionAddress,
          'bidderAddress': bidderAddress,
          'bidAmount': bidAmount,
        },
      );

      final workflowId = result['id'] as String;
      String? unsignedTransaction;
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

          // Map status to user-friendly message
          String displayStatus = switch (status) {
            'creating-transaction' => 'Creating bid transaction...',
            'awaiting-signature' => 'Waiting for signature...',
            'submitting-transaction' => 'Submitting bid...',
            'completed' => 'Bid placed successfully',
            'failed' => 'Failed to place bid',
            String s when s.startsWith('failed:') => s,
            _ => status,
          };

          onStatusUpdate(displayStatus);

          // If we're awaiting signature and don't have the transaction yet, get it
          if (status == 'awaiting-signature' && unsignedTransaction == null) {
            final txResult = await _workflowService.queryWorkflow(
              workflowId,
              'unsignedTransaction',
            );
            unsignedTransaction = txResult['queries']?['unsignedTransaction'] as String?;

            if (unsignedTransaction != null) {
              // Sign the transaction using the wallet service
              final signedTx = await _walletService.signTransaction(unsignedTransaction);
              
              // Send the signed transaction back to the workflow
              await _workflowService.signalWorkflow(
                workflowId,
                'signedTransaction',
                signedTx,
              );
            }
          }

          if (status == 'completed' || status == 'failed' || status.startsWith('failed:')) {
            isComplete = true;
            if (status != 'completed') {
              error = status;
            }
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

      // Get the final submission result
      final submissionResult = await _workflowService.queryWorkflow(
        workflowId,
        'submissionResult',
      );

      return submissionResult;
    } catch (e) {
      print('❌ Error in place bid workflow: $e');
      throw Exception('Failed to place bid: $e');
    }
  }

  Future<Map<String, dynamic>> getBidStatus(String workflowId) async {
    try {
      return await _workflowService.queryWorkflow(workflowId, 'submissionResult');
    } catch (e) {
      print('❌ Error getting bid status: $e');
      throw Exception('Failed to get bid status: $e');
    }
  }
} 