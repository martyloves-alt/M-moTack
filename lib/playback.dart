import 'package:flutter/foundation.dart';

import 'models.dart';
import 'speech.dart';

/// Etat reel de la lecture, tel que les commandes doivent le refleter.
enum PlaybackStatus { idle, playing, paused }

/// Fin de phrase. On garde le delimiteur avec la phrase qu'il termine.
final RegExp _sentenceBreak = RegExp(r'(?<=[.!?…])\s+');

/// Decoupe une carte en segments lisibles.
///
/// Choix : le segment est la PHRASE, pas la carte. Sur cet ecran on lit une
/// seule carte a la fois ; sauter de carte en carte n'aurait donc rien a
/// parcourir. Le recto forme son propre segment — c'est souvent un mot
/// unique — et le verso est decoupe en phrases, ce qui donne un pas de
/// deplacement utile sur une definition longue.
List<String> splitIntoSegments(String front, String back) {
  final segments = <String>[];

  void addAll(String text) {
    for (final part in text.trim().split(_sentenceBreak)) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) segments.add(trimmed);
    }
  }

  addAll(front);
  addAll(back);
  return segments;
}

/// Machine a etats des commandes de lecture.
///
/// Elle detient la verite sur ce qui est actif : l'interface ne fait que
/// refleter [canPlay], [canPause], [canStop], [canPrevious] et [canNext].
///
/// Pause et reprise sont gerees ici, au segment pres, parce qu'Android n'a
/// pas de pause native : `TextToSpeech` n'expose que `stop()`. Le plugin
/// emule une pause en tronquant le texte restant a la derniere position
/// rapportee par le moteur, ce qui depend des callbacks de progression et
/// donc de l'appareil. Couper le moteur et retenir le segment courant donne
/// le meme service de facon previsible partout : la reprise reprend la
/// phrase en cours depuis son debut.
class PlaybackController extends ChangeNotifier {
  PlaybackController({required SpeechService speech}) : _speech = speech;

  final SpeechService _speech;

  List<String> _segments = const [];
  List<String> get segments => _segments;

  int _index = 0;

  /// Segment en cours de lecture, ou prochain a lire.
  int get index => _index;

  PlaybackStatus _status = PlaybackStatus.idle;
  PlaybackStatus get status => _status;

  /// Dernier echec rencontre, pour que l'ecran puisse l'expliquer.
  SpeechOutcome? lastOutcome;

  /// Invalide la boucle de lecture en cours. Toute commande l'incremente,
  /// ce qui empeche une lecture abandonnee de continuer a avancer.
  int _generation = 0;

  bool get canPlay => _segments.isNotEmpty && _status != PlaybackStatus.playing;
  bool get canPause => _status == PlaybackStatus.playing;
  bool get canStop => _status != PlaybackStatus.idle;
  bool get canPrevious => _segments.isNotEmpty && _index > 0;
  bool get canNext => _segments.isNotEmpty && _index < _segments.length - 1;

  /// Charge une carte, sans demarrer la lecture.
  void load(Flashcard card) {
    _generation++;
    _segments = splitIntoSegments(card.front, card.back);
    _index = 0;
    _status = PlaybackStatus.idle;
    lastOutcome = null;
    notifyListeners();
  }

  /// Demarre, ou reprend depuis le segment courant.
  Future<void> play({required Settings settings}) async {
    if (!canPlay) return;

    final generation = ++_generation;
    _status = PlaybackStatus.playing;
    notifyListeners();

    while (_index < _segments.length) {
      final outcome = await _speech.speakSegment(
        _segments[_index],
        settings: settings,
      );

      // Une commande est arrivee pendant l'enonce : elle a deja fixe l'etat.
      if (generation != _generation) return;

      if (outcome != SpeechOutcome.spoken) {
        lastOutcome = outcome;
        _status = PlaybackStatus.idle;
        notifyListeners();
        return;
      }

      if (_index >= _segments.length - 1) break;
      _index++;
      notifyListeners();
    }

    _status = PlaybackStatus.idle;
    notifyListeners();
  }

  /// Suspend la lecture en conservant le segment courant.
  Future<void> pause() async {
    if (!canPause) return;
    _generation++;
    _status = PlaybackStatus.paused;
    notifyListeners();
    await _speech.stop();
  }

  /// Arrete et revient au debut.
  Future<void> stop() async {
    if (!canStop) return;
    _generation++;
    _status = PlaybackStatus.idle;
    _index = 0;
    notifyListeners();
    await _speech.stop();
  }

  /// Recule d'un segment. Si la lecture etait en cours, elle repart de la.
  Future<void> previous({required Settings settings}) =>
      _moveTo(_index - 1, settings: settings);

  /// Avance d'un segment.
  Future<void> next({required Settings settings}) =>
      _moveTo(_index + 1, settings: settings);

  Future<void> _moveTo(int target, {required Settings settings}) async {
    if (_segments.isEmpty) return;
    if (target < 0 || target >= _segments.length) return;

    final wasPlaying = _status == PlaybackStatus.playing;

    _generation++;
    _index = target;
    // On repasse par idle pour que play() soit de nouveau autorise.
    _status = wasPlaying ? PlaybackStatus.idle : _status;
    notifyListeners();

    await _speech.stop();

    if (wasPlaying) {
      await play(settings: settings);
    }
  }

  @override
  void dispose() {
    _generation++;
    _speech.stop();
    super.dispose();
  }
}
