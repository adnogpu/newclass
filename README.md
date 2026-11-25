# newclass

南京理工大学泰州科技学院课表与寝室电费查询应用。Flutter + Material 3，界面参考 [FunClass](https://github.com/my-fun-bit/FunClass) 的雾面配色与无阴影卡片，但代码与数据完全独立。

## 功能

- **课表**：使用教务账号密码登录 CAS 统一身份认证（算术验证码在应用内手动输入），抓取教务系统学期理论课表；按周浏览、今日高亮、课程详情；课表缓存本地，登录会话加密保存，失效时才重新登录。
- **电费**：按宿舍房间号匿名查询剩余电量，无需登录；自动解析楼栋/楼层，7 号楼会弹出南/中/北楼选择；下拉刷新，并缓存最近一次结果。
- **桌面小部件**：Android 桌面提供「今日课表」与「寝室电费」两个独立组件；今日课表由原生按当前日期与周次从缓存计算，电费由后台任务每 3 小时刷新一次。
- **设置**：教务账号、密码、宿舍房间号、开学日期均可随时修改。

应用只与学校系统通信：CAS / 教务系统用于课表，电费接口用于余额。没有自建服务器，没有统计、广告或追踪。

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

## 实现说明

- **CAS 登录**：复刻登录页 jsbn 的裸 RSA（UTF-8 小端、无填充、`m^e mod n`）；验证码通过底部弹窗展示给用户填写，不依赖 OCR。成功后保存 Cookie（加密存储），后续同步优先静默复用。
- **课表解析**：解析 `xskb_list.do` 的 `table#kbtable`，处理一格多课、单双周、`[xx-xx节]`、红字 `P` 调课标记、备注行。
- **当前周次**：由学期字符串推导默认开学日（秋季学期 9 月 5 日后的第一个周一、春季学期 2 月 20 日后的第一个周一），可在设置中修改；课表按课程周次过滤。
- **电费接口**：移植自本地参考脚本的房间号→楼栋/楼层解析与 `left-degree` HTML 解析；该站点的 HTTPS 证书无效，仅对 `ykt.tzu.edu.cn` 放行。
- **小部件**：`home_widget` 写入共享偏好，原生 `RemoteViews` 渲染；今日课表保存整学期课程与开学日，原生在渲染时过滤当天课程，`DATE_CHANGED` 时自动更新。
- **后台刷新**：WorkManager 每 3 小时查询一次电费并更新两个组件；失败保留上次缓存。

## 隐私

- 教务账号、密码、登录 Cookie 使用系统安全存储（Android Keystore / iOS Keychain）保存，仅在本机。
- 课表与电费缓存保存在应用私有目录；不会上传到任何第三方。
- 仓库不包含任何账号、密码、个人课表或校内抓取脚本。`query_by_room.py` 与 `query_class/` 仅作本地参考，已在 `.gitignore` 中排除。
- 仅适用于南京理工大学泰州科技学院（NUSTTI）的校内接口，请使用本人账号。

## 已知限制

- 首次/会话过期登录需要手动输入算术验证码；暂未做 OCR。
- iOS 桌面小部件与后台定时刷新尚未实现（需要 macOS/Xcode）。
- Actions 构建的 APK 使用调试签名，适合自用与测试；正式分发请配置自己的签名。
- 电费接口证书异常、页面结构变化时可能需要更新解析逻辑。

## License

MIT
