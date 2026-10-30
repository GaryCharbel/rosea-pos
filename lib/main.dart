import 'package:flutter/material.dart';

void main() {
  runApp(const RoseaPosApp());
}

/// Placeholder shell for the Rosea POS. Real screens arrive in Stage 1.
class RoseaPosApp extends StatelessWidget {
  const RoseaPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rosea POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

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
                fontSize: 52,
                fontWeight: FontWeight.w800,
                color: Color(0xFFED3D8C),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Point of Sale — scaffolding',
              style: TextStyle(fontSize: 18, color: Color(0xFFB8A9B0)),
            ),
          ],
        ),
      ),
    );
  }
}
