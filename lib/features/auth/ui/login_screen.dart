import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session_controller.dart';

const _bg = Color(0xFF0C0A0F);
const _field = Color(0xFF1A141F);
const _card = Color(0xFF1A141F);
const _ink = Color(0xFFF5EDF1);
const _muted = Color(0xFFB8A9B0);
const _dim = Color(0xFF6E5E6A);
const _pink = Color(0xFFED3D8C);
const _err = Color(0xFFFF6B8A);

/// Email + password sign-in. Surfaces actionable error copy from [mapAuthError]
/// via the session controller — never a bare "unexpected error".
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await ref
        .read(sessionProvider.notifier)
        .signIn(email: _email.text.trim(), password: _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err?.message;
    });
  }

  void _forgotPassword() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        backgroundColor: _card,
        content: Text(
          'Password resets are handled by the owner from the dashboard — ask them to '
          'reset yours, then sign in again.',
          style: TextStyle(color: _ink),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 56,
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: _pink, borderRadius: BorderRadius.circular(16)),
                              child: const Text('R',
                                  style: TextStyle(
                                      color: _bg, fontSize: 30, fontWeight: FontWeight.w900)),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text('Welcome back',
                              style: TextStyle(
                                  fontSize: 34, fontWeight: FontWeight.w800, color: _ink)),
                          const SizedBox(height: 6),
                          const Text('Sign in with your staff account to open the till.',
                              style: TextStyle(color: _muted, fontSize: 15)),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const <String>[AutofillHints.username],
                            enabled: !_busy,
                            style: const TextStyle(color: _ink),
                            decoration: _decoration('Email'),
                            validator: (String? v) =>
                                (v == null || !v.contains('@')) ? 'Enter your email' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: const <String>[AutofillHints.password],
                            enabled: !_busy,
                            style: const TextStyle(color: _ink),
                            decoration: _decoration('Password').copyWith(
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: _muted),
                                tooltip: _obscure ? 'Show password' : 'Hide password',
                              ),
                            ),
                            onFieldSubmitted: (_) => _submit(),
                            validator: (String? v) =>
                                (v == null || v.isEmpty) ? 'Enter your password' : null,
                          ),
                          if (_error != null) ...<Widget>[
                            const SizedBox(height: 16),
                            Semantics(
                              liveRegion: true,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Icon(Icons.error_outline, color: _err, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_error!,
                                        style: const TextStyle(color: _err, height: 1.3)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: _pink,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Sign in',
                                    style:
                                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _busy ? null : _forgotPassword,
                            child: const Text('Forgot password?',
                                style: TextStyle(color: _pink, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 16, top: 8),
              child: Text('Rosea POS · v1.0',
                  style: TextStyle(color: _dim, fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _muted),
        filled: true,
        fillColor: _field,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _pink, width: 1.4),
        ),
      );
}
