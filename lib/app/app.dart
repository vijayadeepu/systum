import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backup/backup_provider.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class SystumApp extends ConsumerWidget {
  const SystumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recovery = ref.watch(backupRecoveryProvider);
    if (recovery.isLoading) {
      return MaterialApp(
        title: 'Systum',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: const _RecoveryLoadingPage(),
      );
    }
    if (recovery.hasError) {
      return MaterialApp(
        title: 'Systum',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: _RecoveryErrorPage(
          error: recovery.error!,
          onRetry: () => ref.invalidate(backupRecoveryProvider),
        ),
      );
    }
    return MaterialApp.router(
      title: 'Systum',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}

class _RecoveryLoadingPage extends StatelessWidget {
  const _RecoveryLoadingPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: CircularProgressIndicator(semanticsLabel: 'Recovering data'),
    ),
  );
}

class _RecoveryErrorPage extends StatelessWidget {
  const _RecoveryErrorPage({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Systum needs to finish restoring your data before it can open.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SelectableText(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry recovery'),
            ),
          ],
        ),
      ),
    ),
  );
}
