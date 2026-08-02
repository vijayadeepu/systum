import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';

final databaseProvider = Provider<SystumDatabase>((ref) {
  final database = SystumDatabase();
  ref.onDispose(database.close);
  return database;
});
