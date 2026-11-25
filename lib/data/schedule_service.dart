import '../core/models/schedule_data.dart';
import '../core/storage/settings_store.dart';
import '../core/widgets/widget_data.dart';
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
