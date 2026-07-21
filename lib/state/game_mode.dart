/// Which mode a [GameplayScreen] round is being played under. Both modes
/// currently play identical Classic rules - Rush's 60s countdown isn't
/// implemented yet, this only changes the mode pill shown in the HUD.
enum GameMode {
  classic,
  rush;

  String get pillLabel => switch (this) {
        GameMode.classic => 'Classic',
        GameMode.rush => 'Rush · 60s',
      };
}
