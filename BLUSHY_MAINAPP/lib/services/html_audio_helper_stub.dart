import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Native (Android / iOS / desktop) half of the audio helpers. The web half
/// lives in `html_audio_helper_web.dart`; `html_audio_helper.dart` picks one.
///
/// Both halves expose the same surface, including `fileExtension` and
/// `mimeType`, because the recording is uploaded for transcription and the
/// server rejects anything whose declared type does not match its contents.

class HtmlAudioRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  int _seconds = 0;
  bool _isRecording = false;
  String? _path;

  void Function(int)? onProgress;

  bool get isRecording => _isRecording;
  int get seconds => _seconds;

  /// AAC-LC in an MPEG-4 container. Android cannot produce WebM, and `m4a` is
  /// one of the types the upload filter accepts.
  String get fileExtension => 'm4a';
  String get mimeType => 'audio/m4a';

  Future<void> start() async {
    if (_isRecording) return;

    if (!await _recorder.hasPermission()) {
      throw Exception('Microphone permission was not granted.');
    }

    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/blushy_recording_'
        '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _path!);

    _isRecording = true;
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _seconds++;
      onProgress?.call(_seconds);
    });
  }

  Future<({List<int> bytes, int duration})?> stop() async {
    if (!_isRecording) return null;
    _timer?.cancel();

    final recordedPath = await _recorder.stop();
    _isRecording = false;

    final target = recordedPath ?? _path;
    if (target == null) return null;

    final file = File(target);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    // The recording has been read into memory; leaving it on disk would keep a
    // copy of the user's voice around after the note is saved.
    unawaited(file.delete().catchError((_) => file));

    return (bytes: bytes, duration: _seconds);
  }

  void cancel() {
    _timer?.cancel();
    if (!_isRecording) return;
    _isRecording = false;
    unawaited(_discard());
  }

  Future<void> _discard() async {
    try {
      final recordedPath = await _recorder.stop();
      final target = recordedPath ?? _path;
      if (target != null) {
        final file = File(target);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {
      // Nothing recorded, or the file is already gone.
    }
  }
}

class HtmlAudioPlayer {
  HtmlAudioPlayer(this.url) {
    _positionSub = _player.positionStream.listen((position) {
      onTimeUpdate?.call(position.inMilliseconds / 1000.0);
    });
    _durationSub = _player.durationStream.listen((duration) {
      if (duration != null) onDurationChange?.call(duration.inMilliseconds / 1000.0);
    });
    _stateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ja.ProcessingState.completed) onEnded?.call();
    });

    // Loading is asynchronous; a bad URL must not take the screen down with it.
    unawaited(_player.setUrl(url).then<void>((_) {}).catchError((Object _) {}));
  }

  final String url;
  final ja.AudioPlayer _player = ja.AudioPlayer();

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<ja.PlayerState>? _stateSub;

  void Function(double)? onTimeUpdate;
  void Function(double)? onDurationChange;
  void Function()? onEnded;

  double get duration {
    final d = _player.duration;
    return d == null ? 0.0 : d.inMilliseconds / 1000.0;
  }

  double get currentTime => _player.position.inMilliseconds / 1000.0;

  void play() {
    unawaited(_player.play().catchError((Object _) {}));
  }

  void pause() {
    unawaited(_player.pause().catchError((Object _) {}));
  }

  void seek(double seconds) {
    unawaited(
      _player.seek(Duration(milliseconds: (seconds * 1000).round())).catchError((Object _) {}),
    );
  }

  void dispose() {
    unawaited(_positionSub?.cancel());
    unawaited(_durationSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_player.dispose());
  }
}

/// Browser-only. Native speech recognition would need its own plugin and
/// permission, and nothing in the app calls this today, so it fails loudly
/// rather than returning a placeholder transcript that reads like real speech.
class HtmlSpeechRecognizer {
  void Function(String)? onResult;
  void Function(String)? onInterimResult;
  void Function()? onStop;
  void Function(String)? onError;
  void Function()? onSpeechStart;
  void Function()? onSpeechEnd;

  Future<String> Function(String base64Audio)? transcriber;

  bool get isListening => false;
  String get transcription => '';

  HtmlSpeechRecognizer();

  Future<void> start({String lang = 'en-US', bool continuous = false}) async {
    throw UnsupportedError(
      'Live speech recognition is web-only. On this platform, record with '
      'HtmlAudioRecorder and transcribe the bytes server-side.',
    );
  }

  void stop() {
    onStop?.call();
  }
}
