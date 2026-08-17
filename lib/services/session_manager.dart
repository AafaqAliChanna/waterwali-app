/// A tiny global hook so any service (which intentionally has no access to
/// AuthProvider or BuildContext — services shouldn't depend on UI state)
/// can signal "the token is dead, force a logout" from one place, instead
/// of every screen needing its own copy of that logic.
class SessionManager {
  static void Function()? onSessionExpired;
}