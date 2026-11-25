# newclass

南京理工大学泰州科技学院课表与寝室电费查询应用。Flutter + Material 3，界面参考 [FunClass](https://github.com/my-fun-bit/FunClass) 的雾面配色与无阴影卡片，但代码与数据完全独立。

## 功能

- **课表**：使用教务账号密码登录 CAS 统一身份认证；验证码优先由 Android 端 ML Kit 在本地自动识别，识别失败时自动回退到手动输入。抓取教务系统学期理论课表，支持周网格与今日列表两种视图；周网格使用 3dp 课程色条、居中课名和自适应行高，今日列表完整显示课程名与教室/教师。课表缓存本地，登录会话加密保存，失效时才重新登录。
- **电费**：按宿舍房间号匿名查询剩余电量，无需登录；自动解析楼栋/楼层，7 号楼会弹出南/中/北楼选择；下拉刷新，并缓存最近一次结果。
- **桌面小部件**：Android 桌面提供「今日课表」与「寝室电费」两个 2×2 独立组件。今日课表显示当天尚未结束的课程，课程结束后自动隐藏；设置页可请求添加到桌面，小米/Redmi 需先允许「桌面快捷方式」特殊权限。不支持的桌面会给出手动添加步骤。电费由后台任务每 3 小时刷新一次。
- **设置**：教务账号、密码、宿舍房间号、开学日期均可随时修改；设置页提供「检查更新」。
- **自动更新**：启动时经 `gh-proxy.com` 检查最新 Release，下载 APK 并校验 SHA-256 后交给系统安装器；设置页可手动检查。

应用只与学校系统通信：CAS / 教务系统用于课表，电费接口用于余额；更新检查只访问 GitHub（经 gh-proxy 加速）。没有自建服务器，没有统计、广告或追踪。

## 环境

- Flutter 3.50.1（Dart 3.14）
- JDK 17
- Android SDK Platform 36、Build-Tools 36.0.0（Android 8.0+ / minSdk 26）

## 运行

```bash
flutter pub get
flutter run
```

构建 APK：

```bash
flutter build apk --release
```

产物位于 `build/app/outputs/flutter-apk/app-release.apk`。仓库的 GitHub Actions 会在推送后自动执行 `flutter analyze`、`flutter test` 并构建 APK，可在 Actions 运行页面的 Artifacts 中下载 `newclass-apk`。

## 自动发布与更新

- 每次推送到 `main`，Actions 会以 `github.run_number` 作为 Android `versionCode` 构建，生成 `version.json`（版本名、版本号、大小、SHA-256），并更新固定 `latest` Release，资产为 `newclass.apk` 与 `version.json`。
- 应用启动或点「检查更新」时，通过 `https://gh-proxy.com/` 访问 `releases/download/latest/version.json`（失败时回退直连 GitHub）。远端 `versionCode` 大于当前版本时提示更新。
- 下载同样走 gh-proxy，完成后校验 SHA-256；若代理返回的文件校验不符，会自动改用 GitHub 直连重新下载。校验通过后调用系统安装器覆盖安装。
- 更新包使用与当前版本相同的固定签名，因此无需卸载，数据会保留。
- 只有 Android 支持应用内更新；iOS/Web 会提示不支持自动安装。

## 实现说明

- **CAS 登录**：复刻登录页 jsbn 的裸 RSA（UTF-8 小端、无填充、`m^e mod n`）；验证码优先使用 ML Kit 本地 OCR（多种灰度/二值化/去噪预处理），识别失败或非 Android 设备时通过底部弹窗手动输入。成功后保存 Cookie（加密存储），后续同步优先静默复用。
- **课表解析**：解析 `xskb_list.do` 的 `table#kbtable`，处理一格多课、单双周、`[xx-xx节]`、红字 `P` 调课标记、备注行。
- **课表组件**：原生保存整学期课程，按当天/当前周过滤，并按结束时间隐藏已结束课程；课程结束点会触发组件刷新。
- **当前周次**：由学期字符串推导默认开学日（秋季学期 9 月 5 日后的第一个周一、春季学期 2 月 20 日后的第一个周一），可在设置中修改；课表按课程周次过滤。
- **电费接口**：移植自本地参考脚本的房间号→楼栋/楼层解析与 `left-degree` HTML 解析；该站点的 HTTPS 证书无效，仅对 `ykt.tzu.edu.cn` 放行。
- **小部件**：`home_widget` 写入共享偏好，原生 `RemoteViews` 渲染；今日课表保存整学期课程与开学日，原生在渲染时过滤当天课程，`DATE_CHANGED` 时自动更新。
- **后台刷新**：WorkManager 每 3 小时查询一次电费并更新两个组件；失败保留上次缓存。

## 签名

GitHub Actions 使用仓库 Secrets 中的固定签名密钥构建（`ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`），密钥不会提交到仓库。这样后续 Actions 构建的 APK 可以直接覆盖安装。

本地构建时，在 `android/app/` 放 `key.properties` 与对应 `.jks` 即使用同一签名；没有时自动回退到 debug 签名。

## 隐私

- 教务账号、密码、登录 Cookie 使用系统安全存储（Android Keystore / iOS Keychain）保存，仅在本机。
- 验证码 OCR 使用 ML Kit 在设备本地完成，验证码图片不会上传到第三方。
- 更新检查与下载只访问 GitHub / `gh-proxy.com`，不包含任何个人数据；安装包下载后会校验 SHA-256。
- 课表与电费缓存保存在应用私有目录；不会上传到任何第三方。
- 仓库不包含任何账号、密码、个人课表或校内抓取脚本。`query_by_room.py` 与 `query_class/` 仅作本地参考，已在 `.gitignore` 中排除。
- 仅适用于南京理工大学泰州科技学院（NUSTTI）的校内接口，请使用本人账号。

## 已知限制

- 验证码优先自动识别；OCR 未通过或非 Android 设备时回退到手动输入，不会重复用同一验证码尝试。
- 自动更新需要用户在系统安装器中确认，无法静默安装；下载源经 gh-proxy 加速，校验失败时回退 GitHub 直连。
- 部分桌面（如部分 MIUI/HyperOS）不实现应用内添加组件接口，或需要先允许「桌面快捷方式」特殊权限；设置页会显示对应步骤并可直接打开应用设置。
- iOS 桌面小部件与后台定时刷新尚未实现（需要 macOS/Xcode）。
- Actions 构建的 APK 使用调试签名，适合自用与测试；正式分发请配置自己的签名。
- 电费接口证书异常、页面结构变化时可能需要更新解析逻辑。

## License

MIT
