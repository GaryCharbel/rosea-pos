import 'package:drift/drift.dart';

import 'catalog_connection.dart';

part 'catalog_database.g.dart';

/// Service/product categories. `kind` mirrors the server enum ('service'|'product').
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Bookable services. Price is cached as integer cents (never rates — those stay
/// server-side behind RLS).
class Services extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get name => text()();
  IntColumn get priceCents => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Retail products. Price in cents; `commission_eligible` is NOT cached (it only
/// matters server-side in pay_ticket).
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get name => text()();
  IntColumn get priceCents => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Categories, Services, Products])
class CatalogDatabase extends _$CatalogDatabase {
  CatalogDatabase() : super(openCatalogConnection());

  /// For tests: an in-memory or custom executor (e.g. NativeDatabase.memory()).
  CatalogDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// This DB is a disposable cache — every row is re-fetchable from the server via
  /// CatalogRepository.sync(). So on any schema-version bump we drop and recreate all
  /// tables rather than hand-writing migrations (and, crucially, rather than crashing
  /// an existing install on open). The next sync repopulates it.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (Migrator m, int from, int to) async {
          for (final table in allTables) {
            await m.deleteTable(table.actualTableName);
          }
          await m.createAll();
        },
      );
}
