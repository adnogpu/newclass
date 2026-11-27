import '../core/models/schedule_data.dart';
import '../core/storage/settings_store.dart';
import '../core/widgets/widget_data.dart';
import 'captcha_ocr.dart';
import 'schedule_api.dart';

class ScheduleService {
  ScheduleService({
    required this.store,
    required this.widgets,
    ScheduleApi Function()? apiFactory,
  }) : _apiFactory = apiFactory ?? ScheduleApi.new;

  final SettingsStore store;
  final WidgetPublisher widgets;
  final ScheduleApi Function() _apiFactory;

  ScheduleApi? _api;
  bool _dailySyncInProgress = false;

  Future<void> begin() async {
    await end();
    final api = _apiFactory();
    final raw = await store.readScheduleCookies();
    if (raw != null && raw.isNotEmpty) {
      api.importCookiesJson(raw);
    }
    _api = api;
  }

  Future<ScheduleData?> trySilentSync() async {
    final api = _api;
    if (api == null || !api.hasCookies) return null;
    try {
      final data = await api.fetchSchedule();
      await store.saveScheduleCookies(api.exportCookiesJson());
      await _save(data);
      return data;
    } on ScheduleSessionExpiredException {
      return null;
    } on LoginException {
      return null;
    }
  }

  /// Refreshes the timetable at most once every 24 hours without any UI.
  /// Saved cookies are reused first; if the session has expired, the bundled
  /// OCR solver can log in again without interrupting the user.
  Future<bool> maybeDailySilentSync({DateTime? now}) async {
    if (!store.isConfigured || _dailySyncInProgress) return false;
    final current = now ?? DateTime.now();
    if (!SettingsStore.scheduleAutoSyncDue(
      now: current,
      fetchedAt: store.schedule?.fetchedAt,
      lastAttempt: store.scheduleAutoSyncAttempt,
    )) {
      return false;
    }
    _dailySyncInProgress = true;
    ScheduleApi? api;
    try {
      await store.markScheduleAutoSyncAttempt(current);
      api = _apiFactory();
      final raw = await store.readScheduleCookies();
      if (raw != null && raw.isNotEmpty) {
        api.importCookiesJson(raw);
      }
      ScheduleData? data;
      if (api.hasCookies) {
        try {
          data = await api.fetchSchedule();
        } on ScheduleSessionExpiredException {
          data = null;
        }
      }
      data ??= await _silentLoginAndFetch(api);
      if (data == null) return false;
      await store.saveScheduleCookies(api.exportCookiesJson());
      await _save(data);
      return true;
    } catch (_) {
      return false;
    } finally {
      api?.close();
      _dailySyncInProgress = false;
    }
  }

  Future<ScheduleData?> _silentLoginAndFetch(ScheduleApi api) async {
    if (!CaptchaOcr.isSupported) return null;
    if (store.account.isEmpty || store.password.isEmpty) return null;
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final challenge = await api.fetchCaptcha();
        final answer = await CaptchaOcr.solve(challenge.imageBytes);
        if (answer == null) continue;
        await api.login(
          username: store.account,
          password: store.password,
          captchaUid: challenge.uid,
          answer: '$answer',
        );
        return await api.fetchSchedule();
      } on CaptchaRejectedException {
        continue;
      } on ScheduleException {
        return null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<CaptchaChallenge> fetchCaptcha() => _requireApi().fetchCaptcha();

  Future<ScheduleData> loginAndSync({
    required CaptchaChallenge challenge,
    required String answer,
  }) async {
    final api = _requireApi();
    if (store.account.isEmpty || store.password.isEmpty) {
      throw const LoginException('请先填写教务账号和密码');
    }
    await api.login(
      username: store.account,
      password: store.password,
      captchaUid: challenge.uid,
      answer: answer,
    );
    await store.saveScheduleCookies(api.exportCookiesJson());
    final data = await api.fetchSchedule();
    await _save(data);
    return data;
  }

  Future<void> end() async {
    _api?.close();
    _api = null;
  }

  ScheduleApi _requireApi() {
    final api = _api;
    if (api == null) {
      throw const ScheduleException('同步会话已结束');
    }
    return api;
  }

  Future<void> _save(ScheduleData data) async {
    await store.saveSchedule(data);
    await widgets.publishSchedule(
      schedule: data,
      semesterStart: store.semesterStart,
    );
  }
}
