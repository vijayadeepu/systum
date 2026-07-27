import 'package:flutter/material.dart';

class SystumApp extends StatelessWidget {
  const SystumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Systum',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(body: Center(child: Text('Systum'))),
    );
  }
}
