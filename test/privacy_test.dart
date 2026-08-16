import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memotack/logging.dart';
import 'package:memotack/models.dart';
import 'package:memotack/notifications.dart';
import 'package:memotack/speech.dart';

/// Texte de carte volontairement improbable : s'il apparait dans un log,
/// c'est forcement qu'il en vient.
const String kSentinelFront = 'ZORGLUB_RECTO_CONFIDENTIEL_42';
const String kSentinelBack = 'ZORGLUB_VERSO_CONFIDENTIEL_42';

/// Capture tout ce qui passe par debugPrint pendant [body].
Future<List<String>> captureLogs(Future<void> Function() body) async {
  final captured = <String>[];
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) captured.add(message);
  };
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return captured;
}

/// Moteur vocal dont l'exception reprend le texte recu — c'est ainsi que se
/// comportent certaines PlatformException, qui repetent leurs arguments.
class EchoingSpeechEngine implements SpeechEngine {
  @override
  Future<bool> init() async => true;

  @override
  Future<List<String>> languages() async => const ['fr-FR'];

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> speak(String text) async {
    throw Exception('PlatformException(tts_error, échec sur "$text", null)');
  }

  @override
  Future<void> stop() async {}
}

/// Planificateur dont l'exception reprend le corps de la notification, donc
/// le recto de la carte.
class EchoingScheduler implements ReminderScheduler {
  final List<ScheduleAttempt> attempts = [];

  @override
  Future<bool> init() async => true;

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<ScheduleAttempt> schedule(PlannedReminder reminder) async {
    final raw = 'PlatformException(error, impossible de programmer '
        '"${reminder.body}", null)';
    final attempt = ScheduleAttempt(
      id: reminder.id,
      requestedTime: reminder.time,
      resolvedTime: reminder.time.toString(),
      mode: 'echec',
      success: false,
      error: redactSecrets(raw, [reminder.body]),
      at: DateTime(2026, 1, 1),
    );
    attempts.add(attempt);
    debugPrint('MémoTack: rappel ${reminder.id} — ${attempt.error}');
    return attempt;
  }

  @override
  Future<void> showNow({required int id, required String title, required String body}) async {}

  @override
  Future<NotificationDiagnostics> diagnostics() async => NotificationDiagnostics(
        notificationsEnabled: true,
        canScheduleExactAlarms: true,
        pendingCount: 0,
        appVersion: '0.5.0+1',
        lastError: attempts.isEmpty ? null : attempts.last.error,
        lastAttempt: attempts.isEmpty ? null : attempts.last,
      );

  @override
  Future<void> openExactAlarmSettings() async {}
}

void main() {
  group('redactSecrets', () {
    test('retire la valeur sensible du message', () {
      final safe = redactSecrets('erreur sur "Anasarque" ici', ['Anasarque']);

      expect(safe, isNot(contains('Anasarque')));
      expect(safe, contains(kRedactedMarker));
    });

    test('retire toutes les occurrences', () {
      final safe = redactSecrets('Anasarque puis Anasarque', ['Anasarque']);

      expect(safe.contains('Anasarque'), isFalse);
    });

    test('ignore les valeurs trop courtes pour etre masquees sans degat', () {
      // Masquer « a » mutilerait tout le message.
      final safe = redactSecrets('rappel a programmer', ['a']);

      expect(safe, 'rappel a programmer');
    });

    test('laisse le message intact quand rien n est sensible', () {
      final safe = redactSecrets('erreur générique', ['Anasarque']);

      expect(safe, 'erreur générique');
    });
  });

  group('aucun contenu de carte dans les logs', () {
    test('lecture vocale : l exception du moteur est expurgée', () async {
      final service = SpeechService(engine: EchoingSpeechEngine());

      final logs = await captureLogs(() async {
        await service.speakCard(
          front: kSentinelFront,
          back: kSentinelBack,
          settings: Settings.defaults,
          pause: const Duration(milliseconds: 1),
        );
      });

      expect(logs, isNotEmpty, reason: 'le test doit exercer un vrai log');
      final tout = logs.join('\n');
      expect(tout, isNot(contains(kSentinelFront)));
      expect(tout, isNot(contains(kSentinelBack)));
      expect(tout, contains(kRedactedMarker));
    });

    test('planification : le corps du rappel est expurgé', () async {
      final scheduler = EchoingScheduler();
      final service = NotificationService(scheduler: scheduler);

      final logs = await captureLogs(() async {
        await service.rescheduleAll(
          cards: [
            Flashcard(
              id: 'a',
              front: kSentinelFront,
              back: kSentinelBack,
              tagId: 'medical',
              level: 0,
              nextReviewAt: DateTime(2020, 1, 1),
              createdAt: DateTime(2020, 1, 1),
            ),
          ],
          settings: Settings.defaults,
          now: DateTime(2026, 1, 1, 9, 0),
        );
      });

      expect(logs, isNotEmpty, reason: 'le test doit exercer un vrai log');
      expect(logs.join('\n'), isNot(contains(kSentinelFront)));
    });

    test('le diagnostic affiché ne contient pas non plus le recto', () async {
      // lastError est montre dans la carte Diagnostic : il doit etre
      // expurge a la source, pas seulement au moment de journaliser.
      final scheduler = EchoingScheduler();
      final service = NotificationService(scheduler: scheduler);

      await service.rescheduleAll(
        cards: [
          Flashcard(
            id: 'a',
            front: kSentinelFront,
            back: '',
            tagId: 'medical',
            level: 0,
            nextReviewAt: DateTime(2020, 1, 1),
            createdAt: DateTime(2020, 1, 1),
          ),
        ],
        settings: Settings.defaults,
        now: DateTime(2026, 1, 1, 9, 0),
      );

      final d = await service.diagnostics();

      expect(d.lastError, isNotNull);
      expect(d.lastError, isNot(contains(kSentinelFront)));
      expect(d.lastAttempt!.error, isNot(contains(kSentinelFront)));
    });
  });
}
