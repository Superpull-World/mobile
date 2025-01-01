import 'dart:convert';
import 'package:http/http.dart' as http;

class WorkflowService {
  // TODO: Move this to a configuration file
  static const String baseUrl = 'http://localhost:3000';

  Future<Map<String, dynamic>> startCreateItemWorkflow({
    required String name,
    required String description,
    required String imageUrl,
    required double price,
    required String ownerAddress,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/workflow/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': 'createItemWorkflow',
          'args': [{
            'name': name,
            'description': description,
            'imageUrl': imageUrl,
            'price': price,
            'ownerAddress': ownerAddress,
          }]
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to start workflow: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error starting workflow: $e');
    }
  }
} 