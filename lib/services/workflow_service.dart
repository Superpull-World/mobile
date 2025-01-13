import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class WorkflowService {
  static const String baseUrl = 'http://localhost:5050/api';

  void _logRequest(String method, String url, Map<String, dynamic>? body) {
    print('🌐 API Request: $method $url');
    if (body != null) print('📦 Request body: ${jsonEncode(body)}');
  }

  void _logResponse(String method, String url, http.Response response) {
    print('✅ API Response: $method $url');
    print('📄 Status: ${response.statusCode}');
    print('📄 Body: ${response.body}');
  }

  Future<Map<String, dynamic>> executeWorkflow(
    String workflowType,
    Map<String, dynamic> input,
  ) async {
    try {
      const url = '$baseUrl/workflow/start';
      final body = {
        'name': workflowType,
        'args': [input],
      };

      _logRequest('POST', url, body);

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      _logResponse('POST', url, response);

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

  Future<Map<String, dynamic>> startCreateItemWorkflow({
    required String name,
    required String description,
    required String imageUrl,
    required double price,
    required String ownerAddress,
    required int maxSupply,
    required int minimumItems,
    required String jwt,
    required Function(String) onStatusUpdate,
  }) async {
    try {
      final result = await executeWorkflow(
        'createItem',
        {
          'name': name,
          'description': description,
          'imageUrl': imageUrl,
          'price': price,
          'ownerAddress': ownerAddress,
          'maxSupply': maxSupply,
          'minimumItems': minimumItems,
          'jwt': jwt,
        },
      );

      final workflowId = result['id'] as String;
      bool isComplete = false;
      String? error;

      while (!isComplete) {
        try {
          final queryResult = await queryWorkflow(workflowId, 'status');
          final status = queryResult['queries']?['status'] as String? ?? 'unknown';
          
          // Map the status to a more user-friendly message
          String displayStatus = switch (status) {
            'running' => 'Creating NFT...',
            'verifying-jwt' => 'Verifying credentials...',
            'uploading-metadata' => 'Uploading metadata...',
            'creating-nft' => 'Creating NFT...',
            'creating-merkle-tree' => 'Creating Merkle tree...',
            'initializing-auction' => 'Initializing auction...',
            'completed' => 'Completed',
            'failed' => 'Failed',
            String s when s.startsWith('failed:') => s,
            _ => status,
          };
          
          onStatusUpdate(displayStatus);

          if (status == 'completed') {
            isComplete = true;
          } else if (status == 'failed' || status.startsWith('failed:')) {
            error = status;
            isComplete = true;
          } else {
            await Future.delayed(const Duration(seconds: 2));
          }
        } catch (e) {
          print('Error querying workflow status: $e');
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (error != null) {
        throw Exception(error);
      }

      return result;
    } catch (e) {
      throw Exception('Error in workflow: $e');
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
      final response = await http.get(
        Uri.parse('$baseUrl/workflow/query?id=$workflowId&query=$queryName'),
        headers: {'Content-Type': 'application/json'},
      );

      _logResponse('GET', '$baseUrl/workflow/query?id=$workflowId&query=$queryName', response);

      if (response.statusCode != 200) {
        throw Exception('Failed to query workflow: ${response.body}');
      }

      final responseData = json.decode(response.body) as Map<String, dynamic>;
      
      // Check if this is a status query
      if (queryName == 'status' && responseData['status']?['name'] != null) {
        // Handle the special case for status queries
        return {
          'queries': {
            'status': responseData['status']['name'].toString().toLowerCase(),
          }
        };
      }

      return responseData;
    } catch (e) {
      print('❌ Error querying workflow: $e');
      throw Exception('Failed to query workflow: $e');
    }
  }
} 