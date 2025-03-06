import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:solana/solana.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'wallet_service.dart';
import '../config/api_config.dart';

class AuthService {
  late final String _baseUrl;
  final WalletService _walletService = WalletService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _jwtKey = 'jwt_token';
  Timer? _jwtCheckTimer;
  
  // Check JWT every 5 minutes
  static const Duration _checkInterval = Duration(minutes: 5);
  // Renew JWT if it expires in less than 10 minutes
  static const Duration _renewThreshold = Duration(minutes: 10);
  // Maximum number of retries for auth operations
  static const int _maxRetries = 3;

  // Cache the JWT in memory for faster access and to reduce I/O
  String? _cachedJwt;

  AuthService() {
    _baseUrl = ApiConfig.baseUrl;
        
    if (kDebugMode) {
      print('🌐 Auth using API URL: $_baseUrl');
    }

    // Initialize JWT cache
    _initializeJwtCache();
    _startPeriodicCheck();
  }

  Future<void> _initializeJwtCache() async {
    try {
      _cachedJwt = await _storage.read(key: _jwtKey);
      if (_cachedJwt != null) {
        print('📄 JWT loaded from storage');
      }
    } catch (e) {
      print('⚠️ Failed to load JWT from storage: $e');
    }
  }

  void _startPeriodicCheck() {
    _jwtCheckTimer?.cancel();
    _jwtCheckTimer = Timer.periodic(_checkInterval, (_) => _checkAndRenewToken());
  }

  void dispose() {
    _jwtCheckTimer?.cancel();
  }

  Future<String?> getStoredJwt() async {
    // Check memory cache first
    if (_cachedJwt != null) {
      return _cachedJwt;
    }
    
    // Then try to read from secure storage
    _cachedJwt = await _storage.read(key: _jwtKey);
    return _cachedJwt;
  }

  Future<void> storeJwt(String jwt) async {
    // Store in both memory and secure storage
    _cachedJwt = jwt;
    await _storage.write(key: _jwtKey, value: jwt);
    print('📝 JWT stored successfully');
  }

  Future<void> clearJwt() async {
    _cachedJwt = null;
    await _storage.delete(key: _jwtKey);
    print('🗑️ JWT cleared');
  }

  Future<bool> isAuthenticated() async {
    // Add retry logic for more reliable checking
    for (int i = 0; i < _maxRetries; i++) {
      try {
        final isValid = await _isTokenValid();
        if (isValid) {
          return true;
        }
        
        // Small delay between retries
        if (i < _maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 200 * (i + 1)));
        }
      } catch (e) {
        print('⚠️ Error checking authentication (attempt ${i+1}): $e');
        if (i == _maxRetries - 1) {
          return false;
        }
      }
    }
    return false;
  }

  Future<bool> _isTokenValid() async {
    final jwt = await getStoredJwt();
    if (jwt == null) return false;
    
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return false;
      
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
      );
      
      final expiry = DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000);
      return DateTime.now().isBefore(expiry);
    } catch (e) {
      print('Error validating token: $e');
      return false;
    }
  }

  Future<Duration?> _getTimeUntilExpiry() async {
    final jwt = await getStoredJwt();
    if (jwt == null) return null;
    
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
      );
      
      final expiry = DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000);
      return expiry.difference(DateTime.now());
    } catch (e) {
      print('Error checking token expiry: $e');
      return null;
    }
  }

  Future<void> _checkAndRenewToken() async {
    try {
      final timeUntilExpiry = await _getTimeUntilExpiry();
      if (timeUntilExpiry == null) return;

      // If token expires soon, try to renew it
      if (timeUntilExpiry <= _renewThreshold) {
        print('Token expires in ${timeUntilExpiry.inMinutes} minutes, attempting renewal');
        final newJwt = await authenticate();
        if (newJwt == null) {
          print('Failed to renew token');
        } else {
          print('Successfully renewed token');
        }
      }
    } catch (e) {
      print('Error during token check and renewal: $e');
    }
  }

  Future<String?> authenticate() async {
    try {
      // First check if we already have a valid token
      if (await isAuthenticated()) {
        final existingJwt = await getStoredJwt();
        print('🔑 Using existing valid JWT');
        return existingJwt;
      }

      print('🔑 Starting authentication process');
      
      // Get the keypair
      final keypair = await _walletService.getKeypair();
      if (keypair == null) throw Exception('No wallet found');

      // Start auth workflow
      final startResponse = await http.post(
        Uri.parse('$_baseUrl/workflow/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': 'auth',
          'args': [keypair.publicKey.toBase58()],
        }),
      );

      print('Start response: ${startResponse.body}');
      if (startResponse.statusCode != 200) {
        throw Exception('Failed to start auth workflow: ${startResponse.body}');
      }

      final responseData = jsonDecode(startResponse.body);
      final workflowId = responseData['id'] as String?;
      if (workflowId == null) {
        throw Exception('No workflow ID in response: ${startResponse.body}');
      }

      String? jwt;
      int attempts = 0;
      const maxAttempts = 10; // Prevent infinite loop
      
      // Poll for nonce and sign it
      while (jwt == null && attempts < maxAttempts) {
        attempts++;
        print('🔄 Polling for auth state (attempt $attempts)');
        
        try {
          final queryResponse = await http.get(
            Uri.parse('$_baseUrl/workflow/query?id=$workflowId'),
            headers: {'Content-Type': 'application/json'},
          );

          print('Query response: ${queryResponse.body}');
          if (queryResponse.statusCode != 200) {
            throw Exception('Failed to query workflow status: ${queryResponse.body}');
          }

          final queryData = jsonDecode(queryResponse.body);
          final queries = queryData['queries'] as Map<String, dynamic>?;
          if (queries == null) {
            print('No queries in response: $queryData');
            continue;
          }

          final state = queries['getState'] as Map<String, dynamic>?;
          if (state == null) {
            print('No state in queries: $queries');
            continue;
          }
          
          if (state['error'] != null) {
            throw Exception('Workflow error: ${state['error']}');
          }

          if (state['nonce'] != null) {
            // Sign the nonce
            final message = utf8.encode(state['nonce']);
            final signature = await keypair.sign(Uint8List.fromList(message));
            
            // Send signature
            final signalResponse = await http.post(
              Uri.parse('$_baseUrl/workflow/signal'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'name': 'submitSignature',
                'workflowId': workflowId,
                'args': signature.toBase58(),
              }),
            );
            print('Signal response: ${signalResponse.body}');
          } else if (state['jwt'] != null) {
            jwt = state['jwt'] as String;
            await storeJwt(jwt);
            print('🎉 Authentication successful, JWT received and stored');
            break;
          }
        } catch (e) {
          print('Error during authentication polling: $e');
          if (attempts >= maxAttempts) {
            throw Exception('Authentication failed after $maxAttempts attempts: $e');
          }
        }

        // Wait before next poll
        await Future.delayed(const Duration(seconds: 1));
      }

      if (jwt == null) {
        throw Exception('Authentication failed: No JWT received after $maxAttempts attempts');
      }

      return jwt;
    } catch (e, stackTrace) {
      print('Authentication error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  // Force reauthentication - useful for retries
  Future<String?> forceReauthenticate() async {
    try {
      // Clear existing JWT
      await clearJwt();
      
      // Wait a moment to ensure everything is cleared
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Attempt to get a new JWT
      return await authenticate();
    } catch (e) {
      print('Force reauthentication error: $e');
      return null;
    }
  }
} 