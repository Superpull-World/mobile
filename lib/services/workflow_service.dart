import 'dart:convert';
import 'package:http/http.dart' as http;

class WorkflowService {
  // TODO: Move this to a configuration file
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

  Future<Map<String, dynamic>> _queryWorkflow(String workflowId) async {
    final url = '$baseUrl/workflow/query?id=$workflowId';
    _logRequest('GET', url, null);

    final response = await http.get(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
    );

    _logResponse('GET', url, response);

    if (response.statusCode != 200) {
      throw Exception('Failed to query workflow: ${response.body}');
    }

    return json.decode(response.body);
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
      final url = '$baseUrl/workflow/start';
      final body = {
        'name': 'createItem',
        'args': [{
          'name': name,
          'description': description,
          'imageUrl': imageUrl,
          'price': price,
          'ownerAddress': ownerAddress,
          'maxSupply': maxSupply,
          'minimumItems': minimumItems,
          'jwt': jwt,
        }]
      };

      _logRequest('POST', url, body);

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: json.encode(body),
      );

      _logResponse('POST', url, response);

      if (response.statusCode != 200) {
        throw Exception('Failed to start workflow: ${response.body}');
      }

      final responseData = json.decode(response.body);
      final workflowId = responseData['id'] as String?;
      if (workflowId == null) {
        throw Exception('No workflow ID in response');
      }

      // Poll for workflow completion
      while (true) {
        final queryData = await _queryWorkflow(workflowId);
        final queries = queryData['queries'] as Map<String, dynamic>?;
        if (queries == null) continue;

        final state = queries['status'] as String?;
        if (state == null) continue;

        onStatusUpdate(state);

        // Check for completion
        if (state == 'completed') {
          return {
            'status': 'success',
            'workflowId': workflowId,
          };
        } else if (state.contains('failed')) {
          throw Exception('Workflow failed: $state');
        }

        // Wait before next poll
        await Future.delayed(const Duration(seconds: 1));
      }
    } catch (e) {
      throw Exception('Error in workflow: $e');
    }
  }
} 