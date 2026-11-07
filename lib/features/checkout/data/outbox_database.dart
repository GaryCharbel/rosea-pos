import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'outbox_database.g.dart';

/// One durable pay attempt. Keyed by the client_tx (one per checkout) so a replay is
/// an upsert, never a duplicate. Lives in its OWN SQLite file — unlike the catalog
/// cache it is NOT disposable, so it must survive schema changes with real migrations.
class PayOutbox extends Table {
  TextColumn get clientTx => text()();
  TextColumn get payload => text()(); // PayIntent JSON
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending|sending|paid|failed
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get ticketNo => integer().nullable()(); // human receipt # once paid
  TextColumn get resultJson => text().nullable()(); // _pay_ticket_result
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {clientTx};
}

@DriftDatabase(tables: [PayOutbox])
class OutboxDatabase extends _$OutboxDatabase {
  OutboxDatabase() : super(_open());

  OutboxDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  // No destructive migration here: queued sales are money and must never be dropped.
  // Future schema changes get hand-written, data-preserving migrations.

  static LazyDatabase _open() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      return NativeDatabase.createInBackground(File(p.join(dir.path, 'rosea_outbox.sqlite')));
    });
  }
}
