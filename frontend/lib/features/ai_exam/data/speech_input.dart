import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text behind a small interface so another transcription service can replace the
/// device recognizer later without touching the exam screen. Only text leaves this adapter;
/// no recording is stored or sent anywhere by the app.
abstract class SpeechInput {
  /// Prepares the recognizer (asks for microphone permission). False when unavailable or denied.
  Future<bool> init();
  bool get isListening;

  /// Streams recognised text. [onText] gets the running transcript of the current utterance
  /// (`isFinal` true once the recognizer settles). [onError] gets a readable message.
  Future<void> start({required void Function(String text, bool isFinal) onText, required void Function(String message) onError, String? localeId});
  Future<void> stop();
  Future<void> cancel();
}

/// Device recognizer (Android/iOS speech services, browser Web Speech API on the web).
class DeviceSpeechInput implements SpeechInput {
  final SpeechToText _stt = SpeechToText();
  bool _ready = false;
  void Function(String message)? _onError;

  @override
  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(onError: (SpeechRecognitionError e) => _onError?.call(_describe(e.errorMsg)), debugLogging: false);
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  static String _describe(String code) => switch (code) {
        'error_no_match' || 'error_speech_timeout' => 'No speech was recognised. Try again, closer to the microphone.',
        'error_network' || 'error_network_timeout' => 'Speech recognition needs a network connection on this device.',
        'error_permission' || 'error_insufficient_permissions' => 'Microphone permission was denied. Allow it in settings, or type your answer.',
        'error_busy' => 'The speech recognizer is busy. Wait a moment and try again.',
        _ => 'Speech recognition stopped ($code). Your text is kept; you can type or try again.',
      };

  @override
  bool get isListening => _stt.isListening;

  @override
  Future<void> start({required void Function(String text, bool isFinal) onText, required void Function(String message) onError, String? localeId}) async {
    _onError = onError;
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) => onText(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 6),
        localeId: localeId,
      ),
    );
  }

  @override
  Future<void> stop() => _stt.stop();

  @override
  Future<void> cancel() => _stt.cancel();
}

/// Replaceable factory (tests and future transcription services plug in here).
SpeechInput Function() speechInputFactory = DeviceSpeechInput.new;

/// Joins a new transcript onto the existing answer without losing what is already there.
String appendTranscript(String existing, String addition) {
  final a = addition.trim();
  if (a.isEmpty) return existing;
  final e = existing.trimRight();
  if (e.isEmpty) return a;
  return '$e $a';
}
