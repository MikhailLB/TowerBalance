/// High-level state of a single playthrough. Drives both gameplay logic and
/// the overlays (HUD, pause, game over).
enum TowerGameStatus {
  /// Game widget is mounted but hasn't started (intro/countdown).
  ready,

  /// Hook is swinging with an attached block; tap to drop.
  swinging,

  /// A block was released and we're waiting for it to settle.
  falling,

  /// Player paused via the pause button.
  paused,

  /// Player lost; show the Game Over overlay.
  gameOver,
}
