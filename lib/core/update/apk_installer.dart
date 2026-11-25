import 'apk_installer_stub.dart'
    if (dart.library.io) 'apk_installer_io.dart' as impl;

import '../../data/update_service.dart';

Future<bool> downloadAndInstallApk(
  UpdateInfo info, {
  required void Function(double? progress) onProgress,
}) => impl.downloadAndInstallApk(info, onProgress: onProgress);
