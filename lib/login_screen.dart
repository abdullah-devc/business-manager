import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'widgets/glass.dart';
import 'widgets/app_loading_indicator.dart';

/// Shown at app start. If no password has been set yet, this doubles as the
/// first-time password setup screen. Otherwise it's a plain login gate.
/// Calls [onSuccess] once the user is authenticated.
class LoginScreen extends StatefulWidget {
  final VoidCallback onSuccess;

  const LoginScreen({super.key, required this.onSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = true;
  bool _isSetupMode = false;
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkMode();
  }

  Future<void> _checkMode() async {
    final hasPassword = await AuthService.instance.hasPassword();
    if (!mounted) return;
    setState(() {
      _isSetupMode = !hasPassword;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    if (_isSetupMode) {
      await AuthService.instance.setPassword(_passwordCtrl.text);
      if (!mounted) return;
      widget.onSuccess();
      return;
    }

    final remaining = await AuthService.instance.lockoutSecondsRemaining();
    if (remaining > 0) {
      setState(() {
        _submitting = false;
        _error = 'Too many failed attempts. Try again in $remaining seconds.';
      });
      return;
    }

    final ok = await AuthService.instance.verifyPassword(_passwordCtrl.text);
    if (!mounted) return;

    if (ok) {
      widget.onSuccess();
      return;
    }

    final lockedFor = await AuthService.instance.lockoutSecondsRemaining();
    setState(() {
      _submitting = false;
      _passwordCtrl.clear();
      _error = lockedFor > 0
          ? 'Too many failed attempts. Try again in $lockedFor seconds.'
          : 'Incorrect password.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: AppLoadingView(label: 'Preparing secure access'),
      );
    }

    return Scaffold(
      body: AdaptiveBackgroundText(
        // Builder gives us a BuildContext below the adaptive Theme that
        // AdaptiveBackgroundText inserts — otherwise `Theme.of(context)`
        // below resolves against the stale outer context and the title
        // stays the app's static (dark-text) light theme regardless of
        // background brightness.
        child: Builder(
          builder: (context) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        _isSetupMode ? Icons.lock_outline : Icons.lock,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isSetupMode
                            ? 'Set Up App Password'
                            : 'BizRise',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      if (_isSetupMode) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Choose a password to protect your business data. '
                          'You will need it every time you open the app.',
                          textAlign: TextAlign.center,
                          // No hardcoded color: this sits directly on the
                          // animated background (no glass panel behind it),
                          // so it needs to inherit AdaptiveBackgroundText's
                          // adaptive color instead of a fixed black54 that
                          // disappears once the background is dimmed.
                        ),
                      ],
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: _isSetupMode ? 'New Password' : 'Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Enter a password';
                          if (_isSetupMode && value.length < 6) {
                            return 'Use at least 6 characters';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) {
                          if (!_isSetupMode) _submit();
                        },
                      ),
                      if (_isSetupMode) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscure,
                          decoration: const InputDecoration(
                            labelText: 'Confirm Password',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value != _passwordCtrl.text)
                              return 'Passwords do not match';
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 20),
                      GlassActionButton(
                        onPressed: _submitting ? null : _submit,
                        icon: _isSetupMode
                            ? Icons.lock_outline
                            : Icons.lock_open,
                        expand: true,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        label: _submitting
                            ? const AppLoadingIndicator.compact()
                            : Text(
                                _isSetupMode
                                    ? 'Set Password & Continue'
                                    : 'Unlock',
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
