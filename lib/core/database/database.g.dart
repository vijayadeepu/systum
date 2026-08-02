// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
abstract class _$SystumDatabase extends GeneratedDatabase {
  _$SystumDatabase(QueryExecutor e) : super(e);
  $SystumDatabaseManager get managers => $SystumDatabaseManager(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [];
}

class $SystumDatabaseManager {
  final _$SystumDatabase _db;
  $SystumDatabaseManager(this._db);
}
