import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class WorkflowService {
  late final String baseUrl;

  WorkflowService() {
    baseUrl = ApiConfig.baseUrl;
    
    if (kDebugMode) {
      print('🌐 Using API URL: $baseUrl');
    }
  }

  void _logRequest(String method, String url, Map<String, dynamic>? body) {
    if (kDebugMode) {
      print('🔄 $method ${url.split('/').last}${body != null ? ' with payload' : ''}');
      if (body != null) print('📦 Payload: $body');
    }
  }

  void _logResponse(String method, String url, http.Response response, {bool verbose = false}) {
    if (!kDebugMode) return;
    
    if (verbose) {
      print('✅ $method ${url.split('/').last}: ${response.statusCode}');
      print('📄 ${response.body}');
    } else {
      final data = json.decode(response.body);
      final status = data['status']?['name'] as String?;
      if (status != null) {
        print('✅ $method ${url.split('/').last}: $status');
      }
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    return {
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> executeWorkflow(
    String workflowType,
    Map<String, dynamic> input,
  ) async {
    try {
      final url = '$baseUrl/workflow/start';
      final body = {
        'name': workflowType,
        'args': [input],
      };

      _logRequest('POST', url, body);

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );

      _logResponse('POST', url, response);

      if (response.statusCode == 404) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Workflow not found in registry');
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to execute workflow: ${response.body}');
      }

      final responseData = json.decode(response.body);
      final workflowId = responseData['id'] as String?;
      if (workflowId == null) {
        throw Exception('No workflow ID in response');
      }

      return responseData;
    } catch (e) {
      print('❌ Error executing workflow: $e');
      throw Exception('Failed to execute workflow: $e');
    }
  }

  Future<Map<String, dynamic>> startCreateAuctionWorkflow({
    required String name,
    required String description,
    required String imageUrl,
    required double price,
    required String ownerAddress,
    required int maxSupply,
    required int minimumItems,
    required DateTime deadline,
    required String jwt,
    required String tokenMint,
    required Function(String) onStatusUpdate,
  }) async {
    try {
      // Convert DateTime to Unix timestamp (seconds since epoch)
      final unixTimestamp = deadline.millisecondsSinceEpoch ~/ 1000;
      
      final result = await executeWorkflow(
        'createAuction',
        {
          'name': name,
          'description': description,
          'imageUrl': imageUrl,
          'price': price,
          'ownerAddress': ownerAddress,
          'maxSupply': maxSupply,
          'minimumItems': minimumItems,
          'deadline': unixTimestamp,
          'jwt': jwt,
          'tokenMint': tokenMint,
        },
      );

      final workflowId = result['id'] as String;
      bool isComplete = false;

      while (!isComplete) {
        try {
          final queryResult = await queryWorkflow(workflowId, 'status');
          final status = queryResult['queries']?['status'] as String? ?? 'unknown';
          
          // Map the status to a more user-friendly message
          String displayStatus = switch (status) {
            'running' => 'Creating auction...',
            'verifying-jwt' => 'Verifying credentials...',
            'uploading-metadata' => 'Uploading metadata...',
            'creating-merkle-tree' => 'Creating Merkle tree...',
            'initializing-auction' => 'Initializing auction...',
            'completed' => 'Completed',
            'failed' => 'Failed',
            _ => status,
          };
          
          onStatusUpdate(displayStatus);
          
          if (status == 'completed' || status == 'failed' || status.startsWith('failed:')) {
            isComplete = true;
          } else {
            await Future.delayed(const Duration(seconds: 2));
          }
        } catch (e) {
          print('❌ Error checking workflow status: $e');
          onStatusUpdate('Failed: $e');
          isComplete = true;
        }
      }

      return result;
    } catch (e) {
      print('❌ Error starting create auction workflow: $e');
      throw Exception('Failed to start create auction workflow: $e');
    }
  }

  Stream<String> queryWorkflowStatus(String workflowId) {
    final controller = StreamController<String>();

    void pollStatus() async {
      while (!controller.isClosed) {
        try {
          final response = await http.get(
            Uri.parse('$baseUrl/workflow/query?id=$workflowId'),
            headers: {'Content-Type': 'application/json'},
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final queries = data['queries'] as Map<String, dynamic>?;
            if (queries != null) {
              final status = queries['status'] as String?;
              if (status != null) {
                controller.add(status);
              }
            }
          }
        } catch (e) {
          controller.addError(e);
        }

        await Future.delayed(const Duration(seconds: 2));
      }
    }

    pollStatus();

    return controller.stream.asBroadcastStream()
      ..listen(
        null,
        onDone: () => controller.close(),
        cancelOnError: false,
      );
  }

  Future<Map<String, dynamic>> queryWorkflow(String workflowId, String queryName) async {
    try {
      final url = '$baseUrl/workflow/query?id=$workflowId&query=$queryName';
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      // Only log verbose output for non-status queries
      _logResponse('GET', url, response, verbose: queryName != 'status');

      if (response.statusCode != 200) {
        throw Exception('Failed to query workflow: ${response.body}');
      }

      return json.decode(response.body);
    } catch (e) {
      print('❌ Error querying workflow: $e');
      throw Exception('Failed to query workflow: $e');
    }
  }

  Future<void> signalWorkflow(
    String workflowId,
    String signalName,
    dynamic signalData,
  ) async {
    try {
      final url = '$baseUrl/workflow/signal';
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode({
          'workflowId': workflowId,
          'name': signalName,
          'args': signalData,
        }),
      );

      _logResponse('POST', url, response);

      if (response.statusCode != 200) {
        throw Exception('Failed to signal workflow: ${response.body}');
      }
    } catch (e) {
      print('❌ Error signaling workflow: $e');
      throw Exception('Failed to signal workflow: $e');
    }
  }
} 