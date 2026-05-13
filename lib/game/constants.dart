// Compatibility shim that exposes the asset-path / timing constants the
// gray screens (notify_offer_screen, network_pause_screen) imported from
// `lib/game/constants.dart` in the TowerFalls codebase. TowerBalance keeps
// its own game-side constants in `lib/game/game_constants.dart` — this file
// is purely a thin re-mapping so the ported gray screens compile unchanged.

const String kBgAsset = 'assets/gameplay_assets/start_bg_asset.webp';

const String kLoadingVideoPortrait =
    'assets/additional_assets/loading_screen/9x16_loading_screen_red.mp4';
const String kLoadingVideoLandscape =
    'assets/additional_assets/loading_screen/16x9_loading_screen.mp4';

const Duration kLoadingMinDuration = Duration(milliseconds: 4500);

const String kNotifyVideoPortrait =
    'assets/additional_assets/notifications/9x16_notification.mp4';
const String kNotifyVideoLandscape =
    'assets/additional_assets/notifications/16x9_notification.mp4';

const String kNoWifiBgPortrait =
    'assets/additional_assets/no_wifi/9x16_no_wifi_screen.webp';
const String kNoWifiBgLandscape =
    'assets/additional_assets/no_wifi/16x9_no_wifi_screen.webp';
const String kNoWifiButton = 'assets/gameplay_assets/button_asset.webp';
