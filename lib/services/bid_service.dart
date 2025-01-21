import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/workflow_service.dart';
import '../services/wallet_service.dart';
import '../models/auction.dart';
import '../providers/token_provider.dart';

class BidService {
  final _workflowService = WorkflowService();
  final _walletService = WalletService();
  final WidgetRef _ref;

  BidService({required WidgetRef ref}) : _ref = ref;

  Future<void> placeBid(Auction auction) async {
    try {
      // Get the bidder's address from wallet service
      final keypair = await _walletService.getKeypair();
      if (keypair == null) {
        throw Exception('No wallet keypair available');
      }

      final bidderAddress = keypair.publicKey.toBase58();
      
      // Get token metadata from provider
      final tokenMetadata = _ref.read(tokenByMintProvider(auction.tokenMint));
      
      // Calculate the current raw price
      final rawBidAmount = auction.rawCurrentPrice;
      print('📊 Placing bid with raw amount: $rawBidAmount');

      // Start the place bid workflow
      final result = await _workflowService.executeWorkflow(
        'placeBid',
        {
          'auctionAddress': auction.id,
          'bidderAddress': bidderAddress,
          'bidAmount': rawBidAmount.toString(),
          'tokenMint': auction.tokenMint,
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

          // If we're awaiting signature and don't have the transaction yet, get it
          if (status == 'awaiting-signature' && unsignedTransaction == null) {
            final txResult = await _workflowService.queryWorkflow(
              workflowId,
              'unsignedTransaction',
            );
            unsignedTransaction = txResult['queries']?['unsignedTransaction'] as String?;
            print('🔏 Unsigned transaction received');

            if (unsignedTransaction != null) {
              // Sign the transaction using the wallet service
              final signedTx = await _walletService.signTransaction(unsignedTransaction);
              print('✍️ Transaction signed');
              
              // Send the signed transaction back to the workflow
              await _workflowService.signalWorkflow(
                workflowId,
                'signedTransaction',
                signedTx,
              );
              print('📤 Signed transaction sent to workflow');
            }
          }

          if (status == 'completed' || status == 'failed' || status.startsWith('failed:')) {
            // Check submission result before marking as complete
            final submissionResult = await _workflowService.queryWorkflow(
              workflowId,
              'submissionResult',
            );
            
            final result = submissionResult['queries']?['submissionResult'];
            if (result != null) {
              isComplete = true;
              final success = result['success'] as bool? ?? false;
              if (!success) {
                error = result['message'] as String? ?? status;
              }
            } else {
              // If no submission result yet, keep polling
              await Future.delayed(const Duration(seconds: 2));
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

      final success = submissionResult['queries']?['submissionResult']?['success'] ?? false;
      if (!success) {
        throw Exception(submissionResult['queries']?['submissionResult']?['message'] ?? 'Failed to place bid');
      }

      print('✅ Bid placed successfully');
      return; // Return normally on success
    } catch (e) {
      print('❌ Error in place bid workflow: $e');
      throw Exception('Failed to place bid: $e'); // Re-throw the error to be handled by the UI
    }
  }
} 