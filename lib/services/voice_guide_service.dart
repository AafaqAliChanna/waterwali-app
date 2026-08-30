import 'package:flutter_tts/flutter_tts.dart';

// Wraps on-device text-to-speech — free, no API key, works fully offline
// via the phone's own TTS engine. Used to narrate the onboarding tour.
class VoiceGuideService {
  static final VoiceGuideService _instance = VoiceGuideService._internal();
  factory VoiceGuideService() => _instance;
  VoiceGuideService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.15); // slightly higher pitch, closer to the
                                // female-leaning voice requested
    // Best-effort: pick a female-labeled voice if the device exposes one.
    // Not every device labels voices this way — falls back silently to
    // whatever the OS default voice is if none is found.
    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        final femaleVoice = voices.cast<dynamic>().firstWhere(
              (v) => (v['name'] as String? ?? '').toLowerCase().contains('female'),
              orElse: () => null,
            );
        if (femaleVoice != null) {
          await _tts.setVoice({
            'name': femaleVoice['name'],
            'locale': femaleVoice['locale'],
          });
        }
      }
    } catch (_) {
      // Non-fatal — narration still works with the device's default voice.
    }
    _initialized = true;
  }

  Future<void> speak(String text) async {
    await _ensureInitialized();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}