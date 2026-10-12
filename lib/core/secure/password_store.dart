// Remembered PDF passwords (FR-028), kept in platform secure storage (research R9):
// Android Keystore, iOS Keychain; on the web, WebCrypto with a browser-held key.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class PasswordStore {
  Future<String?> read(String bookId);
  Future<void> write(String bookId, String password);
  Future<void> delete(String bookId);
}

class SecurePasswordStore implements PasswordStore {
  SecurePasswordStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static String _key(String bookId) => 'pdf-password:$bookId';

  @override
  Future<String?> read(String bookId) => _storage.read(key: _key(bookId));

  @override
  Future<void> write(String bookId, String password) =>
      _storage.write(key: _key(bookId), value: password);

  @override
  Future<void> delete(String bookId) => _storage.delete(key: _key(bookId));
}

final passwordStoreProvider = Provider<PasswordStore>((ref) => SecurePasswordStore());
