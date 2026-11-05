import 'package:flutter/material.dart';

/// Shown while the persisted session is being resolved, so a returning user does
/// not briefly see the login form before being redirected to the shell.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0C0A0F),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Rosea POS',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Color(0xFFED3D8C),
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFED3D8C)),
            ),
          ],
        ),
      ),
    );
  }
}
