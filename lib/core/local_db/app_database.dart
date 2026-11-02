import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [PendingActions, PendingGpsPoints, CachedTrips])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Used by tests to run entirely in-memory, with no filesystem access.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'fleet_saas_driver.sqlite'));

    return NativeDatabase.createInBackground(file);
  });
}
