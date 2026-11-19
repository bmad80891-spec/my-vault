import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class VaultEntry {
  const VaultEntry({
    required this.id,
    required this.service,
    this.username = '',
    this.email = '',
    this.phone = '',
    this.password = '',
    this.website = '',
    this.category = 'Other',
    this.notes = '',
  });

  final String id;
  final String service;
  final String username;
  final String email;
  final String phone;
  final String password;
  final String website;
  final String category;
  final String notes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'service': service,
        'username': username,
        'email': email,
        'phone': phone,
        'password': password,
        'website': website,
        'category': category,
        'notes': notes,
      };

  factory VaultEntry.fromJson(Map<String, dynamic> json) => VaultEntry(
        id: json['id'] as String,
        service: json['service'] as String? ?? '',
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        password: json['password'] as String? ?? '',
        website: json['website'] as String? ?? '',
        category: json['category'] as String? ?? 'Other',
        notes: json['notes'] as String? ?? '',
      );
}

class VaultStore {
  VaultStore._();
  static final VaultStore instance = VaultStore._();

  static const _checkText = 'MY_VAULT_LOCAL_UNLOCK_CHECK_V1';
  static const _iterations = 210000;
  final _cipher = AesGcm.with256bits();
  final _random = Cryptography.instance;
  Database? _db;
  Uint8List? _key;

  bool get isUnlocked => _key != null;

  Future<void> initialize() async {
    if (_db != null) return;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final root = await getDatabasesPath();
    _db = await openDatabase(
      p.join(root, 'my_vault_secure.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE entries (id TEXT PRIMARY KEY, nonce TEXT NOT NULL, cipher_text TEXT NOT NULL, mac TEXT NOT NULL, updated_at INTEGER NOT NULL)',
        );
      },
    );
  }

  Future<bool> hasMasterPassword() async {
    await initialize();
    final rows = await _db!.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['salt'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> createMasterPassword(String password) async {
    await initialize();
    if (password.length < 12) {
      throw ArgumentError('Use at least 12 characters for the master password.');
    }
    if (await hasMasterPassword()) {
      throw StateError('A master password has already been created.');
    }
    final salt = await _random.newRandomBytes(16);
    final key = await _deriveKey(password, salt);
    final verifier = await _cipher.encrypt(
      utf8.encode(_checkText),
      secretKey: SecretKey(key),
    );
    await _db!.transaction((txn) async {
      await txn.insert('settings', {'key': 'salt', 'value': base64Encode(salt)});
      await txn.insert('settings', {
        'key': 'verifier',
        'value': _encodeBox(verifier),
      });
    });
    _key = Uint8List.fromList(key);
  }

  Future<bool> unlock(String password) async {
    await initialize();
    final saltValue = await _setting('salt');
    final verifierValue = await _setting('verifier');
    if (saltValue == null || verifierValue == null) return false;
    try {
      final key = await _deriveKey(password, base64Decode(saltValue));
      final box = _decodeBox(verifierValue);
      final clear = await _cipher.decrypt(box, secretKey: SecretKey(key));
      if (utf8.decode(clear) != _checkText) return false;
      _key = Uint8List.fromList(key);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<int>> _deriveKey(String password, List<int> salt) async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    );
    final key = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  Future<String?> _setting(String key) async {
    final rows = await _db!.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  String _encodeBox(SecretBox box) => jsonEncode({
        'nonce': base64Encode(box.nonce),
        'cipherText': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      });

  SecretBox _decodeBox(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    return SecretBox(
      base64Decode(json['cipherText'] as String),
      nonce: base64Decode(json['nonce'] as String),
      mac: Mac(base64Decode(json['mac'] as String)),
    );
  }

  Future<void> saveEntry(VaultEntry entry) async {
    final key = _key;
    if (key == null) throw StateError('Vault is locked.');
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(entry.toJson())),
      secretKey: SecretKey(key),
    );
    await _db!.insert(
      'entries',
      {
        'id': entry.id,
        'nonce': base64Encode(box.nonce),
        'cipher_text': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<VaultEntry>> loadEntries() async {
    final key = _key;
    if (key == null) throw StateError('Vault is locked.');
    final rows = await _db!.query('entries', orderBy: 'updated_at DESC');
    final result = <VaultEntry>[];
    for (final row in rows) {
      try {
        final box = SecretBox(
          base64Decode(row['cipher_text'] as String),
          nonce: base64Decode(row['nonce'] as String),
          mac: Mac(base64Decode(row['mac'] as String)),
        );
        final clear = await _cipher.decrypt(box, secretKey: SecretKey(key));
        result.add(VaultEntry.fromJson(
          jsonDecode(utf8.decode(clear)) as Map<String, dynamic>,
        ));
      } catch (_) {
        // Skip an unreadable record rather than exposing partial or corrupt data.
      }
    }
    return result;
  }

  Future<void> deleteEntry(String id) async {
    if (_key == null) throw StateError('Vault is locked.');
    await _db!.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> lock() async {
    _key?.fillRange(0, _key!.length, 0);
    _key = null;
  }
}
