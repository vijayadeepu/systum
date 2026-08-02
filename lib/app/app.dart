import 'package:flutter/material.dart';

import 'router.dart';

class SystumApp extends StatelessWidget {
  const SystumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Systum',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}