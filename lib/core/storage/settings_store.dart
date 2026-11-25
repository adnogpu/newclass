import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/electricity_balance.dart';
import '../models/room_ref.dart';
import '../models/schedule_data.dart';

abstract class CredentialStore {
  Future<String?> readAccount();
  Future<String?> readPassword();
  Future<void> saveAccount(String value);
  Future<void> savePassword(String value);
  Future<String?> readScheduleCookies();
  Future<void> saveScheduleCookies(String value);
  Future<void> clearScheduleCookies();
  Future<void> clear();
}

class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accountKey = 'academic_account';
  static const _passwordKey = 'academic_password';
  static const _cookiesKey = 'jwgl_cookies';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccount() => _storage.read(key: _accountKey);

  @override
  Future<String?> readPassword() => _storage.read(key: _passwordKey);

  @override
  Future<void> saveAccount(String value) =>
      _storage.write(key: _accountKey, value: value);

  @override
  Future<void> savePassword(String value) =>
      _storage.write(key: _passwordKey, value: value);

  @override
  Future<String?> readScheduleCookies() => _storage.read(key: _cookiesKey);

  @override
  Future<void> saveScheduleCookies(String value) =>
      _storage.write(key: _cookiesKey, value: value);

  @override
  Future<void> clearScheduleCookies() => _storage.delete(key: _cookiesKey);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accountKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _cookiesKey);
  }
}

class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs, this._credentials);

  static const roomNoKey = 'settings.room_no';
  static const roomRefKey = 'cache.room_ref';
  static const balanceKey = 'cache.balance';
  static const scheduleKey = 'cache.schedule';
  static const semesterStartKey = 'settings.semester_start';
  static const semesterStartForKey = 'settings.semester_start_for';

  final SharedPreferences _prefs;
  final CredentialStore _credentials;

  String account = '';
  String password = '';
  String roomNo = '';
  RoomRef? resolvedRoom;
  ElectricityBalance? balance;
  ScheduleData? schedule;
  DateTime? semesterStart;

  bool get isConfigured =>
      account.trim().isNotEmpty &&
      password.isNotEmpty &&
      isValidRoomNo(roomNo);

  bool get hasValidRoom => isValidRoomNo(roomNo);

  bool get hasSchedule => schedule != null;

  bool get hasBalance => balance != null;

  int get maxWeek => schedule?.maxWeek ?? 20;

  int currentWeek(DateTime now) {
    final start = semesterStart;
    if (schedule == null || start == null) return 1;
    final week = SemesterCalendar.weekForDate(now, start);
    if (week < 1) return 1;
    if (week > maxWeek) return maxWeek;
    return week;
  }

  Future<void> load() async {
    try {
      account = (await _credentials.readAccount())?.trim() ?? '';
      password = await _credentials.readPassword() ?? '';
    } catch (_) {
      account = '';
      password = '';
    }
    roomNo = _prefs.getString(roomNoKey) ?? '';
    resolvedRoom = readCachedRoom(_prefs);
    balance = readCachedBalance(_prefs);
    schedule = readSchedule(_prefs);

    final storedStart = DateTime.tryParse(
      _prefs.getString(semesterStartKey) ?? '',
    );
    final startSemester = _prefs.getString(semesterStartForKey) ?? '';
    if (schedule != null &&
        (storedStart == null || startSemester != schedule!.semester)) {
      semesterStart = SemesterCalendar.defaultStart(schedule!.semester);
      await _prefs.setString(
        semesterStartKey,
        semesterStart!.toIso8601String(),
      );
      await _prefs.setString(semesterStartForKey, schedule!.semester);
    } else {
      semesterStart = storedStart;
    }
  }

  Future<void> saveSetup({
    required String account,
    required String password,
    required String roomNo,
  }) async {
    final trimmedAccount = account.trim();
    final trimmedRoom = roomNo.trim();
    await _credentials.saveAccount(trimmedAccount);
    await _credentials.savePassword(password);
    this.account = trimmedAccount;
    this.password = password;
    if (this.roomNo != trimmedRoom) {
      await _clearRoomCache();
      this.roomNo = trimmedRoom;
    }
    await _prefs.setString(roomNoKey, this.roomNo);
    notifyListeners();
  }

  Future<void> updateAccount(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == account) return;
    await _credentials.saveAccount(trimmed);
    account = trimmed;
    await _credentials.clearScheduleCookies();
    await _clearScheduleCache();
    notifyListeners();
  }

  Future<void> updatePassword(String value) async {
    if (value.isEmpty || value == password) return;
    await _credentials.savePassword(value);
    password = value;
    await _credentials.clearScheduleCookies();
    notifyListeners();
  }

  Future<void> updateRoomNo(String value) async {
    final trimmed = value.trim();
    if (!isValidRoomNo(trimmed) || trimmed == roomNo) return;
    await _clearRoomCache();
    roomNo = trimmed;
    await _prefs.setString(roomNoKey, roomNo);
    notifyListeners();
  }

  Future<void> setResolvedRoom(RoomRef room) async {
    resolvedRoom = room;
    await writeCachedRoom(_prefs, room);
    notifyListeners();
  }

  Future<void> setBalance(ElectricityBalance value) async {
    balance = value;
    await writeCachedBalance(_prefs, value);
    notifyListeners();
  }

  Future<void> clearBalance() async {
    if (balance == null) return;
    balance = null;
    await writeCachedBalance(_prefs, null);
    notifyListeners();
  }

  Future<void> saveSchedule(ScheduleData value) async {
    schedule = value;
    await writeSchedule(_prefs, value);

    final startSemester = _prefs.getString(semesterStartForKey) ?? '';
    if (semesterStart == null || startSemester != value.semester) {
      semesterStart = SemesterCalendar.defaultStart(value.semester);
      await _prefs.setString(
        semesterStartKey,
        semesterStart!.toIso8601String(),
      );
      await _prefs.setString(semesterStartForKey, value.semester);
    }
    notifyListeners();
  }

  Future<void> setSemesterStart(DateTime date) async {
    semesterStart = SemesterCalendar.mondayOf(date);
    await _prefs.setString(
      semesterStartKey,
      semesterStart!.toIso8601String(),
    );
    await _prefs.setString(semesterStartForKey, schedule?.semester ?? '');
    notifyListeners();
  }

  Future<String?> readScheduleCookies() => _credentials.readScheduleCookies();

  Future<void> saveScheduleCookies(String value) =>
      _credentials.saveScheduleCookies(value);

  Future<void> _clearRoomCache() async {
    resolvedRoom = null;
    balance = null;
    await _prefs.remove(roomRefKey);
    await _prefs.remove(balanceKey);
  }

  Future<void> _clearScheduleCache() async {
    schedule = null;
    await _prefs.remove(scheduleKey);
  }

  static bool isValidRoomNo(String value) =>
      RegExp(r'^\d{3,6}$').hasMatch(value.trim());

  static RoomRef? readCachedRoom(SharedPreferences prefs) {
    final raw = prefs.getString(roomRefKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        return RoomRef.fromJson(Map<String, dynamic>.from(json));
      }
    } catch (_) {}
    return null;
  }

  static Future<void> writeCachedRoom(
    SharedPreferences prefs,
    RoomRef? room,
  ) async {
    if (room == null) {
      await prefs.remove(roomRefKey);
    } else {
      await prefs.setString(roomRefKey, jsonEncode(room.toJson()));
    }
  }

  static ElectricityBalance? readCachedBalance(SharedPreferences prefs) {
    final raw = prefs.getString(balanceKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        return ElectricityBalance.fromJson(
          Map<String, dynamic>.from(json),
        );
      }
    } catch (_) {}
    return null;
  }

  static Future<void> writeCachedBalance(
    SharedPreferences prefs,
    ElectricityBalance? value,
  ) async {
    if (value == null) {
      await prefs.remove(balanceKey);
    } else {
      await prefs.setString(balanceKey, jsonEncode(value.toJson()));
    }
  }

  static ScheduleData? readSchedule(SharedPreferences prefs) {
    final raw = prefs.getString(scheduleKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is Map) {
        return ScheduleData.fromJson(Map<String, dynamic>.from(json));
      }
    } catch (_) {}
    return null;
  }

  static Future<void> writeSchedule(
    SharedPreferences prefs,
    ScheduleData value,
  ) async {
    await prefs.setString(scheduleKey, jsonEncode(value.toJson()));
  }

  static String readRoomNo(SharedPreferences prefs) =>
      prefs.getString(roomNoKey) ?? '';

  static DateTime? readSemesterStart(SharedPreferences prefs) =>
      DateTime.tryParse(prefs.getString(semesterStartKey) ?? '');
}
