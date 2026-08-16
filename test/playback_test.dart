import 'package:flutter_test/flutter_test.dart';
import 'package:memotack/models.dart';
import 'package:memotack/playback.dart';
import 'package:memotack/speech.dart';

/// Moteur factice dont chaque enonce prend un temps mesurable, pour pouvoir
/// intervenir pendant une lecture.
class FakeEngine implements SpeechEngine {
  FakeEngine({this.speakDuration = Duration.zero, this.available = true});

  final Duration speakDuration;
  final bool available;

  final List<String> spoken = [];
  int stopCount = 0;

  @override
  Future<bool> init() async => available;

  @override
  Future<List<String>> languages() async => available ? const ['fr-FR'] : const [];

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> speak(String text) async {
    if (speakDuration > Duration.zero) {
      await Future<void>.delayed(speakDuration);
    }
    spoken.add(text);
  }

  @override
  Future<void> stop() async => stopCount++;
}

Flashcard carte({String front = 'Anasarque', String back = ''}) => Flashcard(
      id: 'a',
      front: front,
      back: back,
      tagId: 'medical',
      level: 0,
      nextReviewAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  const settings = Settings.defaults;
  const long = Duration(milliseconds: 40);

  PlaybackController controllerFor(FakeEngine engine) =>
      PlaybackController(speech: SpeechService(engine: engine));

  group('découpage en segments', () {
    test('le recto forme son propre segment', () {
      final segments = splitIntoSegments('Anasarque', '');

      expect(segments, ['Anasarque']);
    });

    test('le verso est découpé en phrases', () {
      final segments = splitIntoSegments(
        'Anasarque',
        'Œdème généralisé. Il touche le tissu sous-cutané. Grave ?',
      );

      expect(segments, [
        'Anasarque',
        'Œdème généralisé.',
        'Il touche le tissu sous-cutané.',
        'Grave ?',
      ]);
    });

    test('une carte sans verso donne un seul segment', () {
      expect(splitIntoSegments('Anasarque', '   '), hasLength(1));
    });

    test('une carte vide ne donne aucun segment', () {
      expect(splitIntoSegments('', ''), isEmpty);
    });
  });

  group('commandes disponibles', () {
    test('au repos : lire oui, pause et stop non', () {
      final c = controllerFor(FakeEngine())..load(carte(back: 'Une. Deux.'));

      expect(c.status, PlaybackStatus.idle);
      expect(c.canPlay, isTrue);
      expect(c.canPause, isFalse);
      expect(c.canStop, isFalse);
    });

    test('une carte vide n autorise aucune commande', () {
      final c = controllerFor(FakeEngine())..load(carte(front: '', back: ''));

      expect(c.canPlay, isFalse);
      expect(c.canPause, isFalse);
      expect(c.canStop, isFalse);
      expect(c.canPrevious, isFalse);
      expect(c.canNext, isFalse);
    });

    test('pendant la lecture : pause oui, lire non', () async {
      final engine = FakeEngine(speakDuration: long);
      final c = controllerFor(engine)..load(carte(back: 'Une. Deux. Trois.'));

      final lecture = c.play(settings: settings);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(c.status, PlaybackStatus.playing);
      // L'exigence explicite : jamais Play actif pendant une lecture.
      expect(c.canPlay, isFalse);
      expect(c.canPause, isTrue);
      expect(c.canStop, isTrue);

      await c.stop();
      await lecture;
    });

    test('en pause : lire oui, pause non', () async {
      final engine = FakeEngine(speakDuration: long);
      final c = controllerFor(engine)..load(carte(back: 'Une. Deux. Trois.'));

      final lecture = c.play(settings: settings);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await c.pause();
      await lecture;

      expect(c.status, PlaybackStatus.paused);
      expect(c.canPlay, isTrue);
      // Et jamais Pause sur une lecture arretee.
      expect(c.canPause, isFalse);
      expect(c.canStop, isTrue);
    });

    test('précédent est refusé sur le premier segment', () {
      final c = controllerFor(FakeEngine())..load(carte(back: 'Une. Deux.'));

      expect(c.index, 0);
      expect(c.canPrevious, isFalse);
      expect(c.canNext, isTrue);
    });

    test('suivant est refusé sur le dernier segment', () async {
      final c = controllerFor(FakeEngine())..load(carte(back: 'Une.'));

      await c.next(settings: settings); // 0 -> 1 (dernier)

      expect(c.index, 1);
      expect(c.canNext, isFalse);
      expect(c.canPrevious, isTrue);
    });
  });

  group('lecture', () {
    test('enchaîne tous les segments puis revient au repos', () async {
      final engine = FakeEngine();
      final c = controllerFor(engine)..load(carte(back: 'Une. Deux.'));

      await c.play(settings: settings);

      expect(engine.spoken, ['Anasarque', 'Une.', 'Deux.']);
      expect(c.status, PlaybackStatus.idle);
    });

    test('la pause conserve le segment courant', () async {
      final engine = FakeEngine(speakDuration: long);
      final c = controllerFor(engine)..load(carte(back: 'Une. Deux. Trois.'));

      final lecture = c.play(settings: settings);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final segmentAuMomentDeLaPause = c.index;
      await c.pause();
      await lecture;

      expect(c.index, segmentAuMomentDeLaPause);
      expect(c.status, PlaybackStatus.paused);
    });

    test('la reprise repart du segment en pause, pas du début', () async {
      final engine = FakeEngine();
      final c = controllerFor(engine)..load(carte(back: 'Une. Deux.'));

      // On se place volontairement sur le dernier segment.
      await c.next(settings: settings);
      await c.next(settings: settings);
      engine.spoken.clear();

      await c.play(settings: settings);

      expect(engine.spoken, ['Deux.']);
    });

    test('stop revient au premier segment', () async {
      final engine = FakeEngine(speakDuration: long);
      final c = controllerFor(engine)..load(carte(back: 'Une. Deux. Trois.'));

      final lecture = c.play(settings: settings);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await c.stop();
      await lecture;

      expect(c.index, 0);
      expect(c.status, PlaybackStatus.idle);
      expect(engine.stopCount, greaterThan(0));
    });

    test('une lecture interrompue n avance plus', () async {
      // Sans le compteur de generation, la boucle aurait continue a
      // enoncer les segments suivants apres l'arret.
      final engine = FakeEngine(speakDuration: long);
      final c = controllerFor(engine)..load(carte(back: 'Une. Deux. Trois.'));

      final lecture = c.play(settings: settings);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await c.stop();
      await lecture;

      final apresArret = engine.spoken.length;
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(engine.spoken.length, apresArret);
    });

    test('sans moteur, la lecture retombe au repos et le signale', () async {
      final c = controllerFor(FakeEngine(available: false))
        ..load(carte(back: 'Une.'));

      await c.play(settings: settings);

      expect(c.status, PlaybackStatus.idle);
      expect(c.lastOutcome, SpeechOutcome.noEngine);
    });

    test('lecture désactivée dans les réglages : rien n est énoncé', () async {
      final engine = FakeEngine();
      final c = controllerFor(engine)..load(carte(back: 'Une.'));

      await c.play(settings: settings.copyWith(speechEnabled: false));

      expect(engine.spoken, isEmpty);
      expect(c.lastOutcome, SpeechOutcome.disabled);
      expect(c.status, PlaybackStatus.idle);
    });
  });

  group('déplacement', () {
    test('avancer à l arrêt déplace sans lire', () async {
      final engine = FakeEngine();
      final c = controllerFor(engine)..load(carte(back: 'Une. Deux.'));

      await c.next(settings: settings);

      expect(c.index, 1);
      expect(c.status, PlaybackStatus.idle);
      expect(engine.spoken, isEmpty);
    });

    test('avancer pendant la lecture reprend au nouveau segment', () async {
      final engine = FakeEngine();
      final c = controllerFor(engine)..load(carte(back: 'Une. Deux.'));

      final lecture = c.play(settings: settings);
      await c.next(settings: settings);
      await lecture;

      // Le segment vise a bien ete enonce apres le saut.
      expect(engine.spoken, contains('Une.'));
      expect(c.status, PlaybackStatus.idle);
    });

    test('avancer en pause conserve l état en pause', () async {
      final engine = FakeEngine(speakDuration: long);
      final c = controllerFor(engine)..load(carte(back: 'Une. Deux. Trois.'));

      final lecture = c.play(settings: settings);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await c.pause();
      await lecture;

      await c.next(settings: settings);

      expect(c.status, PlaybackStatus.paused);
    });

    test('les bornes ne sont jamais franchies', () async {
      final c = controllerFor(FakeEngine())..load(carte(back: 'Une.'));

      await c.previous(settings: settings);
      expect(c.index, 0);

      await c.next(settings: settings);
      await c.next(settings: settings);
      expect(c.index, 1);
    });
  });

  group('rechargement', () {
    test('charger une autre carte remet tout à zéro', () async {
      final engine = FakeEngine(speakDuration: long);
      final c = controllerFor(engine)..load(carte(back: 'Une. Deux. Trois.'));

      final lecture = c.play(settings: settings);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      c.load(carte(front: 'Dyspnée', back: 'Autre.'));
      await lecture;

      expect(c.index, 0);
      expect(c.status, PlaybackStatus.idle);
      expect(c.segments, ['Dyspnée', 'Autre.']);
    });
  });
}
