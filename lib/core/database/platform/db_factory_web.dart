import 'package:sqflite/sqflite.dart' show DatabaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web: SQLite compiled to WebAssembly, stored in IndexedDB. Needs
/// web/sqlite3.wasm and web/sqflite_sw.js, fetched by tool/build_web.sh.
DatabaseFactory get appDatabaseFactory => databaseFactoryFfiWeb;
