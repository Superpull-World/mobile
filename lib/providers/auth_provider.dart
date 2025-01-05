import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isAuthenticated = false;

  AuthProvider() {
    _checkAuthStatus();
  }

  bool get isAuthenticated => _isAuthenticated;

  Future<void> _checkAuthStatus() async {
    _isAuthenticated = await _authService.isAuthenticated();
    notifyListeners();
  }

  Future<bool> authenticate() async {
    final jwt = await _authService.authenticate();
    _isAuthenticated = jwt != null;
    notifyListeners();
    return _isAuthenticated;
  }

  Future<void> signOut() async {
    await _authService.clearJwt();
    _isAuthenticated = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }
} 