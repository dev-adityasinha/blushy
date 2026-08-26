import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

class HtmlAudioRecorder {
  html.MediaRecorder? _mediaRecorder;
  final List<html.Blob> _chunks = [];
  Timer? _timer;
  int _seconds = 0;
  bool _isRecording = false;

  void Function(int)? onProgress;

  bool get isRecording => _isRecording;
  int get seconds => _seconds;

  Future<void> start() async {
    if (_isRecording) return;

    try {
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        }
      });
      if (stream == null) {
        throw Exception('Microphone access denied or not supported.');
      }

      _chunks.clear();
      _mediaRecorder = html.MediaRecorder(stream);
      _mediaRecorder!.addEventListener('dataavailable', (event) {
        final blobEvent = event as html.BlobEvent;
        if (blobEvent.data != null) {
          _chunks.add(blobEvent.data!);
        }
      });

      _mediaRecorder!.start();
      _isRecording = true;
      _seconds = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _seconds++;
        onProgress?.call(_seconds);
      });
    } catch (e) {
      _isRecording = false;
      rethrow;
    }
  }

  Future<({List<int> bytes, int duration})?> stop() async {
    if (!_isRecording || _mediaRecorder == null) return null;

    final completer = Completer<({List<int> bytes, int duration})>();

    _mediaRecorder!.addEventListener('stop', (event) async {
      final blob = html.Blob(_chunks, 'audio/webm');

      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob);
      await reader.onLoad.first;
      final bytes = (reader.result as List).cast<int>();

      if (!completer.isCompleted) {
        completer.complete((bytes: bytes, duration: _seconds));
      }

      _mediaRecorder!.stream?.getTracks().forEach((track) {
        track.stop();
      });
    });

    _timer?.cancel();
    _mediaRecorder!.stop();
    _isRecording = false;

    return completer.future;
  }

  void cancel() {
    if (!_isRecording || _mediaRecorder == null) return;
    _timer?.cancel();
    _mediaRecorder!.stop();
    _mediaRecorder!.stream?.getTracks().forEach((track) {
      track.stop();
    });
    _isRecording = false;
  }
}

class HtmlAudioPlayer {
  HtmlAudioPlayer(this.url) {
    _audioElement = html.AudioElement(url);
    _audioElement.onTimeUpdate.listen((_) {
      onTimeUpdate?.call(_audioElement.currentTime.toDouble());
    });
    _audioElement.onDurationChange.listen((_) {
      final d = _audioElement.duration.toDouble();
      if (!d.isNaN && !d.isInfinite) {
        onDurationChange?.call(d);
      }
    });
    _audioElement.onEnded.listen((_) {
      onEnded?.call();
    });
  }

  final String url;
  late final html.AudioElement _audioElement;

  void Function(double)? onTimeUpdate;
  void Function(double)? onDurationChange;
  void Function()? onEnded;

  double get duration {
    final d = _audioElement.duration.toDouble();
    return (d.isNaN || d.isInfinite) ? 0.0 : d;
  }

  double get currentTime => _audioElement.currentTime.toDouble();

  void play() {
    _audioElement.play();
  }

  void pause() {
    _audioElement.pause();
  }

  void seek(double seconds) {
    _audioElement.currentTime = seconds;
  }

  void dispose() {
    _audioElement.pause();
    _audioElement.src = '';
    _audioElement.remove();
  }
}

class HtmlSpeechRecognizer {
  String _transcription = '';
  bool _isListening = false;
  bool _manualAbort = false;

  dynamic _wrappedOnAudioReady;
  dynamic _wrappedOnEnd;
  dynamic _wrappedOnError;
  dynamic _wrappedOnSpeechStart;
  dynamic _wrappedOnSpeechEnd;
  dynamic _wrappedOnInterimResult;

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

  Future<void> start({String lang = 'en-US', bool continuous = true}) async {
    _transcription = '';
    _isListening = true;
    _manualAbort = false;

    _wrappedOnAudioReady = js.allowInterop((String base64Audio) async {
      if (_manualAbort) return;

      if (transcriber == null) {
        onError?.call('no_transcriber');
        return;
      }

      try {
        final text = await transcriber!(base64Audio);
        if (_manualAbort) return;
        final cleanText = text.trim();
        if (cleanText.isNotEmpty) {
          _transcription = cleanText;
          onResult?.call(cleanText);
        }
      } catch (e) {
        print("[HtmlSpeechRecognizer] Error: $e");
      }
    });

    _wrappedOnEnd = js.allowInterop(() {
      if (_manualAbort) return;
      _isListening = false;
      onStop?.call();
    });

    _wrappedOnError = js.allowInterop((String msg) {
      if (_manualAbort) return;
      _isListening = false;
      onError?.call(msg);
    });

    _wrappedOnSpeechStart = js.allowInterop(() {
      onSpeechStart?.call();
    });

    _wrappedOnSpeechEnd = js.allowInterop(() {
      onSpeechEnd?.call();
    });

    _wrappedOnInterimResult = js.allowInterop((String text) {
      if (_manualAbort) return;
      onInterimResult?.call(text);
    });

    final wrappedOnResult = js.allowInterop((String text) {
      if (_manualAbort) return;
      final cleanText = text.trim();
      if (cleanText.isNotEmpty) {
        _transcription = cleanText;
        onResult?.call(cleanText);
      }
    });

    js.context['__blushyDartOnAudioReady'] = _wrappedOnAudioReady;
    js.context['__blushyDartOnEnd'] = _wrappedOnEnd;
    js.context['__blushyDartOnError'] = _wrappedOnError;
    js.context['__blushyDartOnSpeechStart'] = _wrappedOnSpeechStart;
    js.context['__blushyDartOnSpeechEnd'] = _wrappedOnSpeechEnd;
    js.context['__blushyDartOnInterimResult'] = _wrappedOnInterimResult;
    js.context['__blushyDartOnResult'] = wrappedOnResult;

    try {
      js.context.callMethod('eval', ['''
(function() {
  if (window.__blushySR) {
    try { window.__blushySR.onend = null; window.__blushySR.abort(); } catch(e) {}
    window.__blushySR = null;
  }

  window.__blushyVoiceStopped = false;

  var SC = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (SC) {
    var sr = new SC();
    sr.continuous = true;
    sr.interimResults = true;
    sr.maxAlternatives = 1;
    sr.lang = '$lang';

    sr.onresult = function(event) {
      var fullText = '';
      for (var i = 0; i < event.results.length; ++i) {
        fullText += event.results[i][0].transcript;
      }
      fullText = fullText.trim();
      if (fullText.length > 0) {
        try { if (window.__blushyDartOnInterimResult) window.__blushyDartOnInterimResult(fullText); } catch(e) {}
        try { if (window.__blushyDartOnResult) window.__blushyDartOnResult(fullText); } catch(e) {}
      }
    };

    sr.onerror = function(e) {
      if (e.error === 'no-speech' || e.error === 'aborted') return;
    };

    sr.onend = function() {
      window.__blushySR = null;
      if (!window.__blushyVoiceStopped) setTimeout(function(){ try { sr.start(); } catch(e){} }, 250);
    };

    try {
      sr.start();
      window.__blushySR = sr;
    } catch(e) {}
  }
})()
''']);
    } catch (e) {
      _isListening = false;
      onError?.call('start_exception: $e');
    }
  }

  void stop() {
    _isListening = false;
    _manualAbort = true;
    try {
      js.context.callMethod('eval', ['''
        (function() {
          window.__blushyVoiceStopped = true;
          if (window.__blushySR) {
            try { window.__blushySR.stop(); } catch(e) {}
            window.__blushySR = null;
          }
        })()
      ''']);
    } catch (e) {}
  }
}
