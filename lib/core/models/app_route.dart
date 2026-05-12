/// Persisted decision about how the app should boot on subsequent runs.
///
/// `web` opens the WebView, `arcade` jumps directly into the Tower Falls
/// game, `pristine` means the gateway has not answered yet.
enum AppRoute {
  web,
  arcade,
  pristine;

  String storageId() {
    switch (this) {
      case AppRoute.web:
        return 'web';
      case AppRoute.arcade:
        return 'arcade';
      case AppRoute.pristine:
        return 'pristine';
    }
  }

  static AppRoute decode(String? raw) {
    switch (raw) {
      case 'web':
      case 'browser':
        return AppRoute.web;
      case 'arcade':
      case 'game':
        return AppRoute.arcade;
      default:
        return AppRoute.pristine;
    }
  }
}
