class AppConfig {
  /// 可用 --dart-define=API_BASE_URL=https://xxx 覆盖。
  /// 当前默认：SnapDeploy 免费公网（电脑不用开）。
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://couple-app-0b1b5.containers.snapdeploy.app',
  );
}
