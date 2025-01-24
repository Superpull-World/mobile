import 'dart:async';
import 'dart:convert';
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

  Stream<String> queryWorkflowStatus(String workflowId) {
    final controller = StreamController<String>();

    void pollStatus() async {
      while (!controller.isClosed) {
        try {
          final response = await http.get(
            Uri.parse('$baseUrl/workflow/query?id=$workflowId'),
            headers: {'Content-Type': 'application/json'},
          );

          if (response.statusCode != 200) {
            controller.addError('Failed to query workflow status: ${response.body}');
            await controller.close();
            return;
          }

          final data = json.decode(response.body);
          final status = data['status']?['name'] as String?;
          
          if (kDebugMode) {
            print('🔄 Workflow Status:');
            print('  - ID: $workflowId');
            print('  - Status: $status');
            print('  - Raw Response: ${response.body}');
            print('  - Parsed Data: $data');
            print('  - Status Object: ${data['status']}');
          }
          
          if (status == null) {
            controller.addError('Invalid workflow status response');
            await controller.close();
            return;
          }

          controller.add(status.toLowerCase());

          // If we reach a terminal state, close the stream
          if (status.toLowerCase() == 'completed' || status.toLowerCase() == 'failed') {
            if (kDebugMode) {
              print('✅ Workflow Completed:');
              print('  - ID: $workflowId');
              print('  - Final Status: $status');
            }
            await controller.close();
            return;
          }

          // Poll every second
          await Future.delayed(const Duration(seconds: 1));
        } catch (e) {
          controller.addError('Error polling workflow status: $e');
          await controller.close();
          return;
        }
      }
    }

    // Start polling
    pollStatus();

    return controller.stream;
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