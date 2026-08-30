import 'package:flutter/material.dart';

// A tiny shared registry so any screen can register its own tour's
// narration text + "last step" key + finish callback right before starting
// its ShowCaseWidget sequence. ShowCaseWidget itself is created once at the
// app root (see main.dart), so this is how each screen's tour hooks into
// that single global instance without every screen needing its own copy.
class OnboardingNarrator {
  static Map<GlobalKey, String> _narrations = {};
  static GlobalKey? lastKey;
  static VoidCallback? onFinished;

  static void register({
    required Map<GlobalKey, String> narrations,
    required GlobalKey lastKey,
    required VoidCallback onFinished,
  }) {
    _narrations = narrations;
    OnboardingNarrator.lastKey = lastKey;
    OnboardingNarrator.onFinished = onFinished;
  }

  static String? textFor(GlobalKey key) => _narrations[key];

  static void clear() {
    _narrations = {};
    lastKey = null;
    onFinished = null;
  }
}