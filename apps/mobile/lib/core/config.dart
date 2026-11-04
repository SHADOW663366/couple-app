class AppConfig {
  /// 可用 --dart-define=API_BASE_URL=https://xxx 覆盖。
  /// 当前默认：免费临时公网隧道（电脑需保持 API + 隧道运行）。
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://long-suns-stare.loca.lt',
  );
}
