import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider((ref) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, bool>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

class AuthNotifier extends StateNotifier<bool> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(false) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    state = await _authService.isAuthenticated();
  }

  Future<bool> authenticate() async {
    final jwt = await _authService.authenticate();
    state = jwt != null;
    return state;
  }

  Future<void> signOut() async {
    await _authService.clearJwt();
    state = false;
  }
} 