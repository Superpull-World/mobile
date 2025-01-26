import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart';
import '../config/api_config.dart';
import 'dart:async';

class UploadResponse {
  final String fileUrl;    // S3 URL
  final String? ipfsUrl;   // IPFS URL
  final String? cid;       // IPFS CID

  UploadResponse({
    required this.fileUrl,
    this.ipfsUrl,
    this.cid,
  });
}

class UploadService {
  final String baseUrl = ApiConfig.baseUrl;

  Future<UploadResponse> uploadImage(
    File file,
    String jwt, {
    void Function(double progress)? onProgress,
  }) async {
    final url = Uri.parse('$baseUrl/upload');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $jwt'
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

    final streamedResponse = await request.send();
    
    // Track upload progress
    final totalBytes = request.contentLength ?? 0;
    int bytesReceived = 0;
    
    final completer = Completer<UploadResponse>();
    final List<int> bytes = [];
    
    streamedResponse.stream.listen(
      (List<int> newBytes) {
        bytes.addAll(newBytes);
        bytesReceived += newBytes.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(bytesReceived / totalBytes);
        }
      },
      onDone: () {
        if (streamedResponse.statusCode != 200) {
          final errorMessage = utf8.decode(bytes);
          print('Upload failed with status ${streamedResponse.statusCode}: $errorMessage');
          completer.completeError('Failed to upload image: $errorMessage');
          return;
        }
        final responseData = utf8.decode(bytes);
        final responseJson = jsonDecode(responseData);
        print('Complete upload response: $responseJson');

        completer.complete(UploadResponse(
          fileUrl: responseJson['data']['fileUrl'],
          ipfsUrl: responseJson['data']['ipfsUrl'],
          cid: responseJson['data']['cid'],
        ));
      },
      onError: (error) {
        print('Upload stream error: $error');
        completer.completeError('Upload failed: $error');
      },
      cancelOnError: true,
    );

    return completer.future;
  }
} 