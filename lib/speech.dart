import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'logging.dart';
import 'models.dart';

/// Langue visee. Le repli est gere dans [SpeechService] : si aucune voix
/// fr-FR n'est installee, on tente une autre variante francaise, puis on
/// laisse la voix par defaut du moteur.
const String kPreferredLanguage = 'fr-FR';

/// Respiration entre le recto et le verso, pour que les deux ne se
/// confondent pas a l'oreille.
const Duration kPauseBetweenSides = Duration(milliseconds: 700);

const double kMinSpeechRate = 0.1;
const double kMaxSpeechRate = 1.0;
const double kMinSpeechPitch = 0.5;
const double kMaxSpeechPitch = 2.0;

/// Issue d'une demande de lecture.
enum SpeechOutcome {
  /// La lecture a ete menee (ou interrompue volontairement par une autre).
  spoken,

  /// La lecture est desactivee dans les reglages.
  disabled,

  /// Aucun moteur de synthese vocale utilisable sur l'appareil.
  noEngine,

  /// Le moteur existe mais a echoue.
  failed,
}

/// Message a montrer a l'utilisateur quand la lecture n'a pas eu lieu.
///
/// Renvoie une chaine vide pour [SpeechOutcome.spoken] : il n'y a alors rien
/// a dire, la voix parle d'elle-meme.
String speechOutcomeMessage(SpeechOutcome outcome) {
  switch (outcome) {
    case SpeechOutcome.spoken:
      return '';
    case SpeechOutcome.disabled:
      return 'La lecture vocale est désactivée. Tu peux l\'activer dans Réglages.';
    case SpeechOutcome.noEngine:
      return 'Aucun moteur de synthèse vocale n\'est disponible sur cet appareil. '
          'Installe « Synthèse vocale Google » depuis le Play Store.';
    case SpeechOutcome.failed:
      return 'La lecture a échoué. Réessaie dans un instant.';
  }
}

/// Couche TTS isolee derriere une interface, sur le modele de
/// ReminderScheduler : la logique de lecture devient testable sans passer
/// par les canaux de plateforme, indisponibles sous `flutter test`.
abstract class SpeechEngine {
  /// Prepare le moteur. `false` s'il n'y en a aucun.
  Future<bool> init();

  /// Langues disponibles, vide si le moteur n'en expose aucune.
  Future<List<String>> languages();

  Future<void> setLanguage(String language);
  Future<void> setRate(double rate);
  Future<void> setPitch(double pitch);

  /// Doit rendre la main une fois l'enonce termine, sans quoi le verso
  /// couvrirait le recto.
  Future<void> speak(String text);

  Future<void> stop();
}

/// Implementation reelle, adossee a flutter_tts.
class FlutterTtsEngine implements SpeechEngine {
  final FlutterTts _tts = FlutterTts();

  @override
  Future<bool> init() async {
    try {
      // Sans cela, speak() rend la main immediatement et il devient
      // impossible d'enchainer recto puis verso.
      await _tts.awaitSpeakCompletion(true);
      return true;
    } catch (e) {
      debugPrint('MémoTack: initialisation de la synthèse vocale impossible ($e)');
      return false;
    }
  }

  @override
  Future<List<String>> languages() async {
    try {
      final raw = await _tts.getLanguages;
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return const [];
    } catch (e) {
      debugPrint('MémoTack: langues indisponibles ($e)');
      return const [];
    }
  }

  @override
  Future<void> setLanguage(String language) async {
    try {
      await _tts.setLanguage(language);
    } catch (e) {
      debugPrint('MémoTack: langue $language refusée ($e)');
    }
  }

  @override
  Future<void> setRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate);
    } catch (e) {
      debugPrint('MémoTack: vitesse refusée ($e)');
    }
  }

  @override
  Future<void> setPitch(double pitch) async {
    try {
      await _tts.setPitch(pitch);
    } catch (e) {
      debugPrint('MémoTack: hauteur refusée ($e)');
    }
  }

  @override
  Future<void> speak(String text) => _tts.speak(text);

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('MémoTack: arrêt de la lecture impossible ($e)');
    }
  }
}

/// Lit les cartes a voix haute : recto, courte pause, verso.
class SpeechService {
  SpeechService({SpeechEngine? engine}) : _engine = engine ?? FlutterTtsEngine();

  static final SpeechService instance = SpeechService();

  final SpeechEngine _engine;

  bool _ready = false;

  /// Langue reellement retenue. `null` si aucune voix francaise n'est
  /// installee : on parle alors avec la voix par defaut du moteur.
  String? activeLanguage;

  /// Vrai quand on a du se rabattre sur autre chose que [kPreferredLanguage].
  bool get usedFallbackLanguage =>
      activeLanguage != null && activeLanguage != kPreferredLanguage;

  /// Identifie la lecture courante. Toute nouvelle demande — ou tout arret —
  /// incremente ce compteur, ce qui invalide la sequence precedente : c'est
  /// ce qui empeche deux voix de se superposer, et une lecture abandonnee de
  /// reprendre apres sa pause.
  int _generation = 0;

  bool _speaking = false;
  bool get isSpeaking => _speaking;

  /// Lit le recto puis, apres une pause, le verso s'il existe.
  Future<SpeechOutcome> speakCard({
    required String front,
    required String back,
    required Settings settings,
    Duration pause = kPauseBetweenSides,
  }) async {
    if (!settings.speechEnabled) return SpeechOutcome.disabled;

    // Coupe la lecture en cours avant d'en lancer une autre.
    await stop();
    final generation = _generation;

    if (!await _prepare(settings)) return SpeechOutcome.noEngine;

    _speaking = true;
    try {
      await _engine.speak(front);
      if (generation != _generation) return SpeechOutcome.spoken;

      if (back.trim().isNotEmpty) {
        await Future<void>.delayed(pause);
        if (generation != _generation) return SpeechOutcome.spoken;
        await _engine.speak(back);
      }
      return SpeechOutcome.spoken;
    } catch (e) {
      // Le moteur a recu le texte de la carte : son message d'erreur peut le
      // reprendre tel quel.
      debugPrintSafe(
        'MémoTack: lecture impossible ($e)',
        sensitive: [front, back],
      );
      return SpeechOutcome.failed;
    } finally {
      if (generation == _generation) _speaking = false;
    }
  }

  /// Lit un unique segment et rend la main a la fin de l'enonce.
  ///
  /// Contrairement a [speakCard], n'enchaine rien : l'ecran de lecture
  /// pilote lui-meme la progression, ce qui lui permet de sauter d'un
  /// segment a l'autre.
  Future<SpeechOutcome> speakSegment(
    String text, {
    required Settings settings,
  }) async {
    if (!settings.speechEnabled) return SpeechOutcome.disabled;
    if (!await _prepare(settings)) return SpeechOutcome.noEngine;

    _speaking = true;
    try {
      await _engine.speak(text);
      return SpeechOutcome.spoken;
    } catch (e) {
      debugPrintSafe(
        'MémoTack: lecture impossible ($e)',
        sensitive: [text],
      );
      return SpeechOutcome.failed;
    } finally {
      _speaking = false;
    }
  }

  /// Interrompt toute lecture. Appele aussi en quittant un ecran, pour
  /// qu'aucune voix ne continue en arriere-plan.
  Future<void> stop() async {
    _generation++;
    _speaking = false;
    await _engine.stop();
  }

  Future<bool> _prepare(Settings settings) async {
    if (!_ready) {
      if (!await _engine.init()) return false;

      final available = await _engine.languages();
      // Un moteur qui n'expose aucune langue n'est pas utilisable : c'est
      // le cas quand aucun moteur TTS n'est installe.
      if (available.isEmpty) return false;

      await _selectLanguage(available);
      _ready = true;
    }

    await _engine.setRate(settings.speechRate);
    await _engine.setPitch(settings.speechPitch);
    return true;
  }

  Future<void> _selectLanguage(List<String> available) async {
    String normalise(String l) => l.toLowerCase().replaceAll('_', '-');

    String? chosen;
    for (final l in available) {
      if (normalise(l) == kPreferredLanguage.toLowerCase()) {
        chosen = l;
        break;
      }
    }

    // Repli : n'importe quelle variante francaise (fr-CA, fr-BE...) vaut
    // mieux qu'une voix anglaise sur du vocabulaire francais.
    if (chosen == null) {
      for (final l in available) {
        if (normalise(l).startsWith('fr')) {
          chosen = l;
          break;
        }
      }
    }

    if (chosen != null) {
      await _engine.setLanguage(chosen);
      activeLanguage = chosen;
    } else {
      // Aucune voix francaise : on garde la voix par defaut du moteur.
      // L'accent sera approximatif, mais mieux vaut cela que le silence.
      activeLanguage = null;
    }
  }
}
