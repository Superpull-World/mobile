import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'welcome_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final WalletService _walletService = WalletService();
  final AuthService _authService = AuthService();
  String? _recoveryPhrase;
  bool _isLoading = true;
  bool _isRecoveryPhraseVisible = false;

  @override
  void initState() {
    super.initState();
    _loadWalletInfo();
  }

  Future<void> _loadWalletInfo() async {
    try {
      final phrase = await _walletService.getMnemonic();
      if (mounted) {
        setState(() {
          _recoveryPhrase = phrase;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await _authService.clearJwt();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomePage()),
        (route) => false,
      );
    }
  }

  void _toggleRecoveryPhraseVisibility() {
    setState(() {
      _isRecoveryPhraseVisible = !_isRecoveryPhraseVisible;
    });
  }

  Future<void> _copyRecoveryPhrase() async {
    if (_recoveryPhrase != null) {
      await Clipboard.setData(ClipboardData(text: _recoveryPhrase!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recovery phrase copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.headlineMedium,
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallet',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recovery Phrase',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _isRecoveryPhraseVisible ? Icons.visibility_off : Icons.visibility,
                                  color: AppTheme.primaryColor,
                                ),
                                onPressed: _toggleRecoveryPhraseVisibility,
                                tooltip: _isRecoveryPhraseVisible ? 'Hide recovery phrase' : 'Show recovery phrase',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Keep this phrase safe. It\'s the only way to recover your wallet if you lose access.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          if (_isRecoveryPhraseVisible) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(
                                    _recoveryPhrase ?? 'Unable to load recovery phrase',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontFamily: 'monospace',
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: _copyRecoveryPhrase,
                                    icon: const Icon(Icons.copy, size: 18),
                                    label: const Text('Copy to clipboard'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            OutlinedButton.icon(
                              onPressed: _toggleRecoveryPhraseVisibility,
                              icon: const Icon(Icons.lock_open),
                              label: const Text('Reveal Recovery Phrase'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                side: const BorderSide(color: AppTheme.primaryColor),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Account',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Text(
                        'Sign Out',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.red,
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