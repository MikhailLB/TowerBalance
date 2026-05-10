/// Centralised asset path catalogue for the app. Keep all asset literals here
/// so we never typo a path at the call site.
class AppAssets {
  static const _gameplay = 'assets/gameplay_assets';
  static const _loading = 'assets/additional_assets/loading_screen';

  static const sky = '$_gameplay/bg_sky_asset.webp';
  static const ground = '$_gameplay/ground_asset.webp';
  static const cloud = '$_gameplay/cloud_asset_01.webp';
  static const hook = '$_gameplay/hook_asset.webp';
  static const button = '$_gameplay/button_asset.webp';
  static const startBg = '$_gameplay/start_bg_asset.webp';
  static const startBuilding = '$_gameplay/start_building_asset.webp';

  static const logo = 'assets/logo.webp';
  static const logoName = 'assets/logo_name.webp';

  /// All 6 block skins. Indexed 1..6 to match the source filenames.
  static String block(int n) => '$_gameplay/block_asset_0$n.webp';

  static const allBlocks = <String>[
    '$_gameplay/block_asset_01.webp',
    '$_gameplay/block_asset_02.webp',
    '$_gameplay/block_asset_03.webp',
    '$_gameplay/block_asset_04.webp',
    '$_gameplay/block_asset_05.webp',
    '$_gameplay/block_asset_06.webp',
  ];

  static const loadingVideoPortrait =
      '$_loading/9x16_loading_screen_red.mp4';
  static const loadingVideoLandscape = '$_loading/16x9_loading_screen.mp4';

  /// 4-state loading bar (state 4 == fully loaded).
  static String loadingBar(int state) =>
      '$_loading/loading_bar_0$state.webp';
}
