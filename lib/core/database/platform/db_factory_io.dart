import 'package:sqflite/sqflite.dart';

/// Android (and desktop tests): sqflite's global factory. Tests swap it for
/// the FFI one before opening.
DatabaseFactory get appDatabaseFactory => databaseFactory;
