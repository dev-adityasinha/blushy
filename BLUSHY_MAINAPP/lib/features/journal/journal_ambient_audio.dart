import '../../services/html_audio_helper.dart';

enum AmbientTheme {
  none,
  forest,
  rain,
  cafe,
  library,
  night,
}

class JournalAmbientAudio {
  static final JournalAmbientAudio _instance = JournalAmbientAudio._internal();
  factory JournalAmbientAudio() => _instance;
  JournalAmbientAudio._internal();

  HtmlAudioPlayer? _activePlayer;
  AmbientTheme _currentTheme = AmbientTheme.none;
  double _volume = 0.5;
  bool _isMuted = false;

  AmbientTheme get currentTheme => _currentTheme;
  double get volume => _volume;
  bool get isMuted => _isMuted;

  static const Map<AmbientTheme, String> _soundUrls = {
    AmbientTheme.forest: 'https://actions.google.com/sounds/v1/environments/forest_birds.ogg',
    AmbientTheme.rain: 'https://actions.google.com/sounds/v1/weather/rain_heavy_loud.ogg',
    AmbientTheme.cafe: 'https://actions.google.com/sounds/v1/crowds/bar_crowd.ogg',
    AmbientTheme.library: 'https://actions.google.com/sounds/v1/environments/office_ambient.ogg',
    AmbientTheme.night: 'https://actions.google.com/sounds/v1/environments/crickets_night.ogg',
  };

  void playTheme(AmbientTheme theme) {
    if (theme == _currentTheme && _activePlayer != null) return;

    stop();
    _currentTheme = theme;

    if (theme == AmbientTheme.none) return;

    final url = _soundUrls[theme];
    if (url != null) {
      _activePlayer = HtmlAudioPlayer(url);
      _activePlayer!.onEnded = () {
        // Loop ambient sound
        if (_currentTheme == theme && !_isMuted) {
          _activePlayer?.play();
        }
      };
      if (!_isMuted) {
        _activePlayer!.play();
      }
    }
  }

  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
    // Audio volume control
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _activePlayer?.pause();
    } else {
      if (_currentTheme != AmbientTheme.none) {
        _activePlayer?.play();
      }
    }
  }

  void stop() {
    _activePlayer?.dispose();
    _activePlayer = null;
    _currentTheme = AmbientTheme.none;
  }
}
