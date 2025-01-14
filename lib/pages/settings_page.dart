import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import 'welcome_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final WalletService _walletService = WalletService();
  final AuthService _authService = AuthService();
  String? _recoveryPhrase;
  String? _publicKey;
  bool _showRecoveryPhrase = false;

  @override
  void initState() {
    super.initState();
    _loadWalletInfo();
  }

  Future<void> _loadWalletInfo() async {
    try {
      final phrase = await _walletService.getMnemonic();
      final address = await _walletService.getWalletAddress();
      setState(() {
        _recoveryPhrase = phrase;
        _publicKey = address;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading wallet info: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.clearJwt();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  Future<void> _copyRecoveryPhrase() async {
    if (_recoveryPhrase == null) return;
    
    await Clipboard.setData(ClipboardData(text: _recoveryPhrase!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recovery phrase copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(
            Icons.close,
            color: Color(0xFFEEFC42),
            size: 28,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet Section
            const Text(
              'Wallet',
              style: TextStyle(
                color: Color(0xFFEEFC42),
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Public Key
                  ListTile(
                    title: const Text(
                      'Public Key',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      _publicKey ?? 'Loading...',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'monospace',
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.copy,
                        color: Color(0xFFEEFC42),
                      ),
                      onPressed: _publicKey == null
                          ? null
                          : () async {
                              await Clipboard.setData(ClipboardData(text: _publicKey!));
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Public key copied to clipboard')),
                                );
                              }
                            },
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  // Recovery Phrase
                  ListTile(
                    title: const Text(
                      'Recovery Phrase',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _showRecoveryPhrase
                              ? _recoveryPhrase ?? 'Loading...'
                              : '••• ••• ••• •••',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (_showRecoveryPhrase) ...[
                          const SizedBox(height: 8),
                          const Text(
                            '⚠️ Warning: Never share your recovery phrase with anyone. Store it in a safe place.',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _showRecoveryPhrase
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: const Color(0xFFEEFC42),
                          ),
                          onPressed: () {
                            setState(() {
                              _showRecoveryPhrase = !_showRecoveryPhrase;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.copy,
                            color: Color(0xFFEEFC42),
                          ),
                          onPressed: _recoveryPhrase == null
                              ? null
                              : _copyRecoveryPhrase,
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  ListTile(
                    title: const Text(
                      'Export Private Key',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.lock,
                      color: Colors.white38,
                    ),
                    enabled: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Account Section
            const Text(
              'Account',
              style: TextStyle(
                color: Color(0xFFEEFC42),
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: const Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
                onTap: _signOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 