import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens the on-disk SQLite file backing the catalog cache. The POS targets Windows
/// and Android only (no web), so a native file connection is correct for both.
/// `sqlite3_flutter_libs` ships the native sqlite3 for each target.
LazyDatabase openCatalogConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'rosea_catalog.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
