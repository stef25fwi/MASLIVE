import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MasLive'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Bienvenue sur MasLive',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
