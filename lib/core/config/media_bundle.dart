/// Optional asset overrides for the core flow.
///
/// The core module ships with no bundled artwork — every screen falls back to
/// a Material/gradient placeholder when the corresponding entry below is
/// `null`. To brand the flow, the host app should:
///
/// 1. Add its own assets to `pubspec.yaml` (under `flutter.assets`).
/// 2. Call [MediaBundle.configure] EARLY in `main()`, before `runApp`.
///
/// All fields are optional and independent — provide only the assets you
/// have. Missing entries simply leave the matching screen in its default
/// look. None of the fields are validated; passing an invalid asset path
/// will surface as an Image.asset error at render time but will not crash
/// the boot flow.
abstract final class MediaBundle {
  static String? splashVideoPortrait;
  static String? splashVideoLandscape;
  static String? splashBackground;

  static String? notifyOfferVideoPortrait;
  static String? notifyOfferVideoLandscape;
  static String? notifyOfferBackground;

  /// Video backgrounds for the offline screen (mp4 / mov / webm).
  /// Use these OR [networkPauseImagePortrait] / [networkPauseImageLandscape]
  /// — when both are set, the video takes precedence.
  static String? networkPauseBackgroundPortrait;
  static String? networkPauseBackgroundLandscape;

  /// Static image backgrounds for the offline screen (webp / png / jpg).
  /// Cheaper to render than a video and a good fit when the no-wifi art
  /// doesn't need animation.
  static String? networkPauseImagePortrait;
  static String? networkPauseImageLandscape;

  static String? networkPauseRetryButton;

  /// Bulk setter used by the host app from its `main()`.
  static void configure({
    String? splashVideoPortrait,
    String? splashVideoLandscape,
    String? splashBackground,
    String? notifyOfferVideoPortrait,
    String? notifyOfferVideoLandscape,
    String? notifyOfferBackground,
    String? networkPauseBackgroundPortrait,
    String? networkPauseBackgroundLandscape,
    String? networkPauseImagePortrait,
    String? networkPauseImageLandscape,
    String? networkPauseRetryButton,
  }) {
    MediaBundle.splashVideoPortrait = splashVideoPortrait;
    MediaBundle.splashVideoLandscape = splashVideoLandscape;
    MediaBundle.splashBackground = splashBackground;
    MediaBundle.notifyOfferVideoPortrait = notifyOfferVideoPortrait;
    MediaBundle.notifyOfferVideoLandscape = notifyOfferVideoLandscape;
    MediaBundle.notifyOfferBackground = notifyOfferBackground;
    MediaBundle.networkPauseBackgroundPortrait =
        networkPauseBackgroundPortrait;
    MediaBundle.networkPauseBackgroundLandscape =
        networkPauseBackgroundLandscape;
    MediaBundle.networkPauseImagePortrait = networkPauseImagePortrait;
    MediaBundle.networkPauseImageLandscape = networkPauseImageLandscape;
    MediaBundle.networkPauseRetryButton = networkPauseRetryButton;
  }
}
