import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/txn.dart';

/// 账本存储接口：移动端走 SQLite，Web 走 SharedPreferences。
abstract class LedgerRepository {
  Future<List<Txn>> loadAll();

  Future<Txn> insert(Txn txn);

  Future<void> insertMany(List<Txn> txns);

  Future<void> delete(int id);

  Future<void> deleteAll();
}

Future<LedgerRepository> openLedgerRepository() async {
  if (kIsWeb) return SharedPreferencesRepository();
  return SqfliteRepository();
}

const _rowType = 'type';
const _rowCategory = 'category';
const _rowAmount = 'amount';
const _rowDay = 'day';
const _rowNote = 'note';
const _rowCreated = 'created';

Map<String, Object?> _toRow(Txn t) => {
  _rowType: t.type.name,
  _rowCategory: t.categoryKey,
  _rowAmount: t.amount,
  _rowDay: t.day,
  _rowNote: t.note,
  _rowCreated: t.createdAt,
};

Txn _fromRow(int id, Map<String, Object?> row) => Txn(
  id: id,
  type: TxnType.values.byName(row[_rowType] as String),
  categoryKey: row[_rowCategory] as String,
  amount: (row[_rowAmount] as num).toDouble(),
  day: row[_rowDay] as String,
  note: row[_rowNote] as String? ?? '',
  createdAt: (row[_rowCreated] as num).toInt(),
);

class SqfliteRepository implements LedgerRepository {
  SqfliteRepository();

  static const _dbName = 'ledger.db';
  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, _dbName),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE txn (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            category TEXT NOT NULL,
            amount REAL NOT NULL,
            day TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            created INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_txn_day ON txn (day)');
      },
    );
    return _db!;
  }

  @override
  Future<List<Txn>> loadAll() async {
    final db = await _open();
    final rows = await db.query('txn', orderBy: 'day DESC, created DESC');
    return rows.map((r) => _fromRow(r['id'] as int, r)).toList();
  }

  @override
  Future<Txn> insert(Txn txn) async {
    final db = await _open();
    final id = await db.insert('txn', _toRow(txn));
    return _fromRow(id, _toRow(txn));
  }

  @override
  Future<void> insertMany(List<Txn> txns) async {
    final db = await _open();
    final batch = db.batch();
    for (final t in txns) {
      batch.insert('txn', _toRow(t));
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> delete(int id) async {
    final db = await _open();
    await db.delete('txn', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteAll() async {
    final db = await _open();
    await db.delete('txn');
  }
}

class SharedPreferencesRepository implements LedgerRepository {
  SharedPreferencesRepository();

  static const _key = 'ledger.txns';

  Future<(SharedPreferences, List<Txn>)> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return (prefs, const <Txn>[]);
    final rows = (jsonDecode(raw) as List).cast<Map<String, Object?>>();
    return (prefs, rows.map((r) => _fromRow(r['id'] as int, r)).toList());
  }

  Future<void> _write(SharedPreferences prefs, List<Txn> txns) {
    final rows = [
      for (final t in txns)
        {'id': t.id, ..._toRow(t)},
    ];
    return prefs.setString(_key, jsonEncode(rows));
  }

  @override
  Future<List<Txn>> loadAll() async {
    final (_, txns) = await _read();
    final sorted = [...txns]..sort((a, b) => b.day.compareTo(a.day));
    return sorted;
  }

  @override
  Future<Txn> insert(Txn txn) async {
    final (prefs, txns) = await _read();
    final id = txns.map((t) => t.id ?? 0).fold<int>(0, (a, b) => a > b ? a : b) + 1;
    final saved = _fromRow(id, _toRow(txn));
    await _write(prefs, [saved, ...txns]);
    return saved;
  }

  @override
  Future<void> insertMany(List<Txn> txns) async {
    final (prefs, existing) = await _read();
    var id = existing.map((t) => t.id ?? 0).fold<int>(0, (a, b) => a > b ? a : b);
    final added = [
      for (final t in txns)
        _fromRow(++id, _toRow(t)),
    ];
    await _write(prefs, [...added, ...existing]);
  }

  @override
  Future<void> delete(int id) async {
    final (prefs, txns) = await _read();
    await _write(prefs, txns.where((t) => t.id != id).toList());
  }

  @override
  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
