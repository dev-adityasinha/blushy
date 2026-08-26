import 'dart:async';

class HtmlAudioRecorder {
  bool _isRecording = false;
  int _seconds = 0;

  void Function(int)? onProgress;

  bool get isRecording => _isRecording;
  int get seconds => _seconds;

  Future<void> start() async {
    _isRecording = true;
    _seconds = 0;
  }

  Future<({List<int> bytes, int duration})?> stop() async {
    _isRecording = false;
    return (bytes: <int>[], duration: _seconds);
  }

  void cancel() {
    _isRecording = false;
  }
}

class HtmlAudioPlayer {
  HtmlAudioPlayer(this.url);

  final String url;

  void Function(double)? onTimeUpdate;
  void Function(double)? onDurationChange;
  void Function()? onEnded;

  double get duration => 0.0;
  double get currentTime => 0.0;

  void play() {}
  void pause() {}
  void seek(double seconds) {}
  void dispose() {}
}

class HtmlSpeechRecognizer {
  bool _isListening = false;
  String _transcription = '';

  void Function(String)? onResult;
  void Function(String)? onInterimResult;
  void Function()? onStop;
  void Function(String)? onError;
  void Function()? onSpeechStart;
  void Function()? onSpeechEnd;

  Future<String> Function(String base64Audio)? transcriber;

  bool get isListening => _isListening;
  String get transcription => _transcription;

  HtmlSpeechRecognizer();

  Future<void> start({String lang = 'en-US', bool continuous = false}) async {
    _isListening = true;
    _transcription = "Listening on native platform...";
    onResult?.call(_transcription);
  }

  void stop() {
    _isListening = false;
    onStop?.call();
  }
}
