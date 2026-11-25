import 'package:newclass/core/storage/settings_store.dart';

class FakeCredentialStore implements CredentialStore {
  String? account;
  String? password;
  String? cookies;

  @override
  Future<String?> readAccount() async => account;

  @override
  Future<String?> readPassword() async => password;

  @override
  Future<String?> readScheduleCookies() async => cookies;

  @override
  Future<void> saveAccount(String value) async {
    account = value;
  }

  @override
  Future<void> savePassword(String value) async {
    password = value;
  }

  @override
  Future<void> saveScheduleCookies(String value) async {
    cookies = value;
  }

  @override
  Future<void> clearScheduleCookies() async {
    cookies = null;
  }

  @override
  Future<void> clear() async {
    account = null;
    password = null;
    cookies = null;
  }
}
