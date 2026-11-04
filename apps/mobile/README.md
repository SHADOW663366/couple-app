# Couple Mobile（Flutter）

## 首次准备

本仓库只提交了 `lib/` 与 `pubspec.yaml`。若缺少 `android/`、`ios/` 平台目录，在已安装 Flutter 后于本目录执行：

```bash
flutter create . --project-name couple_app
flutter pub get
```

## 运行

1. 先启动 `apps/api`
2. 按设备修改 `lib/core/config.dart` 中的 API 地址：
   - Android 模拟器：`http://10.0.2.2:3000`（默认）
   - iOS 模拟器：`http://127.0.0.1:3000`
   - 真机：电脑局域网 IP，如 `http://192.168.1.8:3000`
3. `flutter run`
