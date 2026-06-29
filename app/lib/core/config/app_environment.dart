/// Build-time environment selector. Chosen via `--dart-define=APP_ENV=...`.
enum AppEnvironment {
  dev,
  staging,
  prod;

  bool get isDev => this == AppEnvironment.dev;
  bool get isProd => this == AppEnvironment.prod;
  bool get isProduction => isProd;
}
