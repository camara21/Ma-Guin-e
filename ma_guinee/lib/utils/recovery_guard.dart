class RecoveryGuard {
  static bool _active = false;

  static bool get isActive => _active;

  static void activate() => _active = true;

  static void deactivate() => _active = false;
}
