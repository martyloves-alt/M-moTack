import 'package:flutter_test/flutter_test.dart';
import 'package:memotack/models.dart';
import 'package:memotack/speech.dart';

/// Moteur vocal factice : enregistre ce qui lui est demande sans jamais
/// toucher aux canaux de plateforme.
class FakeSpeechEngine implements SpeechEngine {
  FakeSpeechEngine({
    this.available = true,
    this.availableLanguages = const ['en-US', 'fr-FR', 'es-ES'],
    this.speakThrows = false,
    this.speakDuration = Duration.zero,
  });

  /// `false` simule un appareil sans moteur de synthese vocale.
  final bool available;
  final List<String> availableLanguages;
  final bool speakThrows;

  /// Duree simulee d'un enonce, pour tester l'interruption en cours de route.
  final Duration speakDuration;

  final List<String> spoken = [];
  String? language;
  double? rate;
  double? pitch;
  int stopCount = 0;
  int initCount = 0;

  @override
  Future<bool> init() async {
    initCount++;
    return available;
  }

  @override
  Future<List<String>> languages() async =>
      available ? availableLanguages : const [];

  @override
  Future<void> setLanguage(String value) async => language = value;

  @override
  Future<void> setRate(double value) async => rate = value;

  @override
  Future<void> setPitch(double value) async => pitch = value;

  @override
  Future<void> speak(String text) async {
    if (speakThrows) throw Exception('moteur indisponible');
    if (speakDuration > Duration.zero) {
      await Future<void>.delayed(speakDuration);
    }
    spoken.add(text);
  }

  @override
  Future<void> stop() async => stopCount++;
}

void main() {
  const settings = Settings.defaults;
  const pause = Duration(milliseconds: 1);

  group('speakCard', () {
    test('lit le recto puis le verso, dans cet ordre', () async {
      final engine = FakeSpeechEngine();
      final service = SpeechService(engine: engine);

      final outcome = await service.speakCard(
        front: 'Anasarque',
        back: 'Œdème généralisé',
        settings: settings,
        pause: pause,
      );

      expect(outcome, SpeechOutcome.spoken);
      expect(engine.spoken, ['Anasarque', 'Œdème généralisé']);
    });

    test('ne lit que le recto si le verso est vide', () async {
      final engine = FakeSpeechEngine();
      final service = SpeechService(engine: engine);

      await service.speakCard(front: 'Anasarque', back: '', settings: settings, pause: pause);

      expect(engine.spoken, ['Anasarque']);
    });

    test('applique la vitesse et la hauteur des reglages', () async {
      final engine = FakeSpeechEngine();
      final service = SpeechService(engine: engine);

      await service.speakCard(
        front: 'Test',
        back: '',
        settings: settings.copyWith(speechRate: 0.8, speechPitch: 1.4),
        pause: pause,
      );

      expect(engine.rate, 0.8);
      expect(engine.pitch, 1.4);
    });

    test('ne lit rien si la lecture est desactivee', () async {
      final engine = FakeSpeechEngine();
      final service = SpeechService(engine: engine);

      final outcome = await service.speakCard(
        front: 'Anasarque',
        back: 'Œdème',
        settings: settings.copyWith(speechEnabled: false),
        pause: pause,
      );

      expect(outcome, SpeechOutcome.disabled);
      expect(engine.spoken, isEmpty);
    });

    test('signale l absence de moteur au lieu de planter', () async {
      final engine = FakeSpeechEngine(available: false);
      final service = SpeechService(engine: engine);

      final outcome = await service.speakCard(
        front: 'Anasarque', back: '', settings: settings, pause: pause);

      expect(outcome, SpeechOutcome.noEngine);
      expect(engine.spoken, isEmpty);
      expect(speechOutcomeMessage(outcome), contains('synthèse vocale'));
    });

    test('un moteur sans aucune langue est traite comme absent', () async {
      final engine = FakeSpeechEngine(availableLanguages: const []);
      final service = SpeechService(engine: engine);

      final outcome = await service.speakCard(
        front: 'Anasarque', back: '', settings: settings, pause: pause);

      expect(outcome, SpeechOutcome.noEngine);
    });

    test('signale un echec du moteur sans propager l exception', () async {
      final engine = FakeSpeechEngine(speakThrows: true);
      final service = SpeechService(engine: engine);

      final outcome = await service.speakCard(
        front: 'Anasarque', back: '', settings: settings, pause: pause);

      expect(outcome, SpeechOutcome.failed);
    });
  });

  group('langue', () {
    test('retient fr-FR quand la voix est installee', () async {
      final engine = FakeSpeechEngine();
      final service = SpeechService(engine: engine);

      await service.speakCard(front: 'Test', back: '', settings: settings, pause: pause);

      expect(engine.language, 'fr-FR');
      expect(service.activeLanguage, 'fr-FR');
      expect(service.usedFallbackLanguage, isFalse);
    });

    test('se rabat sur une autre variante francaise', () async {
      // Pas de fr-FR installe, mais fr-CA disponible.
      final engine = FakeSpeechEngine(availableLanguages: const ['en-US', 'fr-CA']);
      final service = SpeechService(engine: engine);

      await service.speakCard(front: 'Test', back: '', settings: settings, pause: pause);

      expect(engine.language, 'fr-CA');
      expect(service.usedFallbackLanguage, isTrue);
    });

    test('accepte la notation fr_FR avec un souligne', () async {
      final engine = FakeSpeechEngine(availableLanguages: const ['en-US', 'fr_FR']);
      final service = SpeechService(engine: engine);

      await service.speakCard(front: 'Test', back: '', settings: settings, pause: pause);

      expect(engine.language, 'fr_FR');
    });

    test('lit quand meme si aucune voix francaise n est installee', () async {
      final engine = FakeSpeechEngine(availableLanguages: const ['en-US', 'de-DE']);
      final service = SpeechService(engine: engine);

      final outcome = await service.speakCard(
        front: 'Anasarque', back: '', settings: settings, pause: pause);

      // Mieux vaut un accent approximatif que le silence.
      expect(outcome, SpeechOutcome.spoken);
      expect(engine.spoken, ['Anasarque']);
      expect(service.activeLanguage, isNull);
    });
  });

  group('interruption', () {
    test('lancer une autre carte coupe la lecture en cours', () async {
      final engine = FakeSpeechEngine();
      final service = SpeechService(engine: engine);

      await service.speakCard(front: 'Première', back: '', settings: settings, pause: pause);
      final stopsApresPremiere = engine.stopCount;

      await service.speakCard(front: 'Deuxième', back: '', settings: settings, pause: pause);

      expect(engine.stopCount, greaterThan(stopsApresPremiere));
      expect(engine.spoken, ['Première', 'Deuxième']);
    });

    test('une lecture interrompue n enchaine pas sur son verso', () async {
      // Le recto dure assez longtemps pour qu'un stop() arrive pendant.
      final engine = FakeSpeechEngine(speakDuration: const Duration(milliseconds: 40));
      final service = SpeechService(engine: engine);

      final lecture = service.speakCard(
        front: 'Recto',
        back: 'Verso',
        settings: settings,
        pause: const Duration(milliseconds: 30),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await service.stop();
      await lecture;

      // Sans le compteur de generation, le verso serait parti apres la pause.
      expect(engine.spoken, isNot(contains('Verso')));
      expect(service.isSpeaking, isFalse);
    });

    test('stop coupe le moteur et remet l etat a zero', () async {
      final engine = FakeSpeechEngine();
      final service = SpeechService(engine: engine);

      await service.speakCard(front: 'Test', back: '', settings: settings, pause: pause);
      await service.stop();

      expect(engine.stopCount, greaterThan(0));
      expect(service.isSpeaking, isFalse);
    });
  });

  group('Settings', () {
    test('les reglages vocaux sont enregistres et relus', () {
      final json = settings.copyWith(
        speechEnabled: false,
        speechRate: 0.7,
        speechPitch: 1.3,
      ).toJson();

      final relus = Settings.fromJson(json);

      expect(relus.speechEnabled, isFalse);
      expect(relus.speechRate, 0.7);
      expect(relus.speechPitch, 1.3);
    });

    test('des reglages anterieurs sans champs vocaux restent lisibles', () {
      // Reglages tels qu'enregistres par une version anterieure : une
      // lecture stricte ferait echouer le chargement au demarrage.
      final ancien = {
        'remindersPerDay': 4,
        'activeHoursStart': '08:00',
        'activeHoursEnd': '23:00',
        'theme': 'dark',
      };

      final relus = Settings.fromJson(ancien);

      expect(relus.speechEnabled, Settings.defaults.speechEnabled);
      expect(relus.speechRate, Settings.defaults.speechRate);
      expect(relus.speechPitch, Settings.defaults.speechPitch);
    });
  });
}
