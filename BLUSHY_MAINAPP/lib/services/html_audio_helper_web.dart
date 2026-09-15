import 'dart:async';

import 'package:flutter/foundation.dart';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

class HtmlAudioRecorder {
  web.MediaRecorder? _mediaRecorder;
  final List<web.Blob> _chunks = [];
  Timer? _timer;
  int _seconds = 0;
  bool _isRecording = false;

  void Function(int)? onProgress;

  bool get isRecording => _isRecording;
  int get seconds => _seconds;

  /// MediaRecorder produces WebM here; the native half produces m4a. Callers
  /// label the upload from these rather than assuming a format.
  String get fileExtension => 'webm';
  String get mimeType => 'audio/webm';

  /// Stops every track on the recorder's stream, which is what actually
  /// releases the microphone and clears the browser's recording indicator.
  void _releaseMicrophone() {
    try {
      final tracks = _mediaRecorder?.stream.getTracks().toDart;
      if (tracks == null) return;
      for (final track in tracks) {
        try {
          track.stop();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> start() async {
    if (_isRecording) return;

    try {
      // The audio constraints are a plain JS object; there is no typed
      // dictionary for them in package:web.
      final audioConstraints = JSObject()
        ..setProperty('echoCancellation'.toJS, true.toJS)
        ..setProperty('noiseSuppression'.toJS, true.toJS)
        ..setProperty('autoGainControl'.toJS, true.toJS);

      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: audioConstraints))
          .toDart;

      _chunks.clear();
      _mediaRecorder = web.MediaRecorder(stream);
      _mediaRecorder!.addEventListener(
        'dataavailable',
        ((web.Event event) {
          _chunks.add((event as web.BlobEvent).data);
        }).toJS,
      );

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

    _mediaRecorder!.addEventListener(
      'stop',
      ((web.Event event) {
        final blob = web.Blob(
          _chunks.map((chunk) => chunk as JSAny).toList().toJS,
          web.BlobPropertyBag(type: 'audio/webm'),
        );

        final reader = web.FileReader();
        // onloadend fires for both success and failure, so the recording can
        // never hang waiting on a read that already gave up.
        reader.onloadend = ((web.Event _) {
          if (completer.isCompleted) return;
          final result = reader.result;
          if (result.isA<JSArrayBuffer>()) {
            completer.complete((
              bytes: (result as JSArrayBuffer).toDart.asUint8List(),
              duration: _seconds,
            ));
          } else {
            completer.completeError(StateError('Could not read the recording.'));
          }
          _releaseMicrophone();
        }).toJS;
        reader.readAsArrayBuffer(blob);
      }).toJS,
    );

    _timer?.cancel();
    _mediaRecorder!.stop();
    _isRecording = false;

    return completer.future;
  }

  void cancel() {
    if (!_isRecording || _mediaRecorder == null) return;
    _timer?.cancel();
    _mediaRecorder!.stop();
    _releaseMicrophone();
    _isRecording = false;
  }
}

class HtmlAudioPlayer {
  HtmlAudioPlayer(this.url) {
    _audioElement = web.HTMLAudioElement()..src = url;

    _audioElement.ontimeupdate = ((web.Event _) {
      onTimeUpdate?.call(_audioElement.currentTime);
    }).toJS;

    _audioElement.ondurationchange = ((web.Event _) {
      final d = _audioElement.duration;
      if (!d.isNaN && !d.isInfinite) {
        onDurationChange?.call(d);
      }
    }).toJS;

    _audioElement.onended = ((web.Event _) {
      onEnded?.call();
    }).toJS;
  }

  final String url;
  late final web.HTMLAudioElement _audioElement;

  void Function(double)? onTimeUpdate;
  void Function(double)? onDurationChange;
  void Function()? onEnded;

  double get duration {
    final d = _audioElement.duration;
    return (d.isNaN || d.isInfinite) ? 0.0 : d;
  }

  double get currentTime => _audioElement.currentTime;

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

  JSFunction? _wrappedOnAudioReady;
  JSFunction? _wrappedOnEnd;
  JSFunction? _wrappedOnError;
  JSFunction? _wrappedOnSpeechStart;
  JSFunction? _wrappedOnSpeechEnd;
  JSFunction? _wrappedOnInterimResult;

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

  Future<void> _handleAudioReady(String base64Audio) async {
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
      debugPrint("[HtmlSpeechRecognizer] Error: $e");
    }
  }

  Future<void> start({String lang = 'en-US', bool continuous = true}) async {
    _transcription = '';
    _isListening = true;
    _manualAbort = false;

    // toJS rejects a Future-returning signature, so the JS-facing callback is
    // synchronous and starts the work without awaiting it. The JS caller never
    // used the returned value, so this matches the previous behaviour.
    _wrappedOnAudioReady = ((String base64Audio) {
      unawaited(_handleAudioReady(base64Audio));
    }).toJS;

    _wrappedOnEnd = (() {
      if (_manualAbort) return;
      _isListening = false;
      onStop?.call();
    }).toJS;

    _wrappedOnError = ((String msg) {
      if (_manualAbort) return;
      _isListening = false;
      onError?.call(msg);
    }).toJS;

    _wrappedOnSpeechStart = (() {
      onSpeechStart?.call();
    }).toJS;

    _wrappedOnSpeechEnd = (() {
      onSpeechEnd?.call();
    }).toJS;

    _wrappedOnInterimResult = ((String text) {
      if (_manualAbort) return;
      onInterimResult?.call(text);
    }).toJS;

    final wrappedOnResult = ((String text) {
      if (_manualAbort) return;
      final cleanText = text.trim();
      if (cleanText.isNotEmpty) {
        _transcription = cleanText;
        onResult?.call(cleanText);
      }
    }).toJS;

    globalContext['__blushyDartOnAudioReady'] = _wrappedOnAudioReady;
    globalContext['__blushyDartOnEnd'] = _wrappedOnEnd;
    globalContext['__blushyDartOnError'] = _wrappedOnError;
    globalContext['__blushyDartOnSpeechStart'] = _wrappedOnSpeechStart;
    globalContext['__blushyDartOnSpeechEnd'] = _wrappedOnSpeechEnd;
    globalContext['__blushyDartOnInterimResult'] = _wrappedOnInterimResult;
    globalContext['__blushyDartOnResult'] = wrappedOnResult;

    try {
      globalContext.callMethod<JSAny?>('eval'.toJS, '''
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
'''.toJS);
    } catch (e) {
      _isListening = false;
      onError?.call('start_exception: $e');
    }
  }

  void stop() {
    _isListening = false;
    _manualAbort = true;
    try {
      globalContext.callMethod<JSAny?>('eval'.toJS, '''
        (function() {
          window.__blushyVoiceStopped = true;
          if (window.__blushySR) {
            try { window.__blushySR.stop(); } catch(e) {}
            window.__blushySR = null;
          }
        })()
      '''.toJS);
    } catch (_) {
      // Nothing to stop: the recognizer was never created, or the page is
      // already tearing down.
    }
  }
}
