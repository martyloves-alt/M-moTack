import 'package:flutter_test/flutter_test.dart';
import 'package:memotack/models.dart';
import 'package:memotack/notifications.dart';

/// Planificateur factice : enregistre ce qui lui est demande, sans jamais
/// toucher a la couche Android.
class FakeScheduler implements ReminderScheduler {
  FakeScheduler({this.ready = true});

  final bool ready;

  int initCount = 0;
  int cancelAllCount = 0;
  final List<PlannedReminder> scheduled = [];
  final List<String> shownNow = [];

  /// Ordre d'appel, pour verifier que l'annulation precede la planification.
  final List<String> calls = [];

  @override
  Future<bool> init() async {
    initCount++;
    calls.add('init');
    return ready;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    calls.add('cancelAll');
  }

  @override
  Future<void> schedule(PlannedReminder reminder) async {
    scheduled.add(reminder);
    calls.add('schedule');
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    shownNow.add(body);
    calls.add('showNow');
  }
}

Flashcard card({
  required String id,
  required String front,
  required DateTime nextReviewAt,
}) {
  return Flashcard(
    id: id,
    front: front,
    back: '',
    tagId: 'medical',
    level: 0,
    nextReviewAt: nextReviewAt,
    createdAt: nextReviewAt,
  );
}

void main() {
  // Reglages par defaut : 4 rappels/jour entre 08:00 et 23:00.
  // Fenetre de 15 h / 4 => un creneau toutes les 3 h 45 :
  // 08:00, 11:45, 15:30, 19:15.
  const settings = Settings.defaults;

  group('rescheduleAll', () {
    test('un creneau futur declenche bien une planification', () async {
      final now = DateTime(2026, 1, 1, 9, 0);
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      // Carte due depuis 08:00, donc eligible au prochain creneau.
      final cards = [
        card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2026, 1, 1, 8, 0)),
      ];

      await service.rescheduleAll(cards: cards, settings: settings, now: now);

      expect(fake.scheduled, hasLength(1));
      final reminder = fake.scheduled.single;
      expect(reminder.time, DateTime(2026, 1, 1, 11, 45));
      expect(reminder.time.isAfter(now), isTrue);
      expect(reminder.body, 'Anasarque');
    });

    test('les creneaux deja passes ne sont jamais planifies', () async {
      // 20:00 : les quatre creneaux du jour sont passes, seuls ceux de
      // demain restent.
      final now = DateTime(2026, 1, 1, 20, 0);
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      final cards = [
        card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2026, 1, 1, 7, 0)),
      ];

      await service.rescheduleAll(cards: cards, settings: settings, now: now);

      expect(fake.scheduled, isNotEmpty);
      for (final reminder in fake.scheduled) {
        expect(reminder.time.isAfter(now), isTrue);
      }
      expect(fake.scheduled.first.time, DateTime(2026, 1, 2, 8, 0));
    });

    test('annule les anciens rappels avant d en programmer de nouveaux', () async {
      final now = DateTime(2026, 1, 1, 9, 0);
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      final cards = [
        card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2026, 1, 1, 8, 0)),
      ];

      await service.rescheduleAll(cards: cards, settings: settings, now: now);

      expect(fake.cancelAllCount, 1);
      expect(fake.calls.indexOf('cancelAll'), lessThan(fake.calls.indexOf('schedule')));
    });

    test('plusieurs cartes dues recoivent des identifiants distincts', () async {
      final now = DateTime(2026, 1, 1, 9, 0);
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      final cards = [
        card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2026, 1, 1, 7, 0)),
        card(id: 'b', front: 'Dyspnée', nextReviewAt: DateTime(2026, 1, 1, 7, 30)),
        card(id: 'c', front: 'Asthénie', nextReviewAt: DateTime(2026, 1, 1, 8, 0)),
      ];

      await service.rescheduleAll(cards: cards, settings: settings, now: now);

      expect(fake.scheduled, hasLength(3));
      expect(fake.scheduled.map((r) => r.id).toSet(), {0, 1, 2});
      // La carte la plus en retard part sur le creneau le plus proche.
      expect(fake.scheduled.first.body, 'Anasarque');
    });

    test('ne programme rien si la permission est refusee', () async {
      final now = DateTime(2026, 1, 1, 9, 0);
      final fake = FakeScheduler(ready: false);
      final service = NotificationService(scheduler: fake);

      final cards = [
        card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2026, 1, 1, 8, 0)),
      ];

      await service.rescheduleAll(cards: cards, settings: settings, now: now);

      expect(service.isReady, isFalse);
      expect(fake.scheduled, isEmpty);
      expect(fake.cancelAllCount, 0);
    });

    test('une permission refusee est retentee au prochain appel', () async {
      // L'utilisateur peut accorder la permission depuis les reglages Android
      // apres un premier refus : l'echec ne doit pas etre memorise.
      final fake = FakeScheduler(ready: false);
      final service = NotificationService(scheduler: fake);

      await service.rescheduleAll(cards: const [], settings: settings);
      await service.rescheduleAll(cards: const [], settings: settings);

      expect(fake.initCount, 2);
    });

    test('aucun rappel si remindersPerDay vaut 0', () async {
      final now = DateTime(2026, 1, 1, 9, 0);
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      final cards = [
        card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2026, 1, 1, 8, 0)),
      ];

      await service.rescheduleAll(
        cards: cards,
        settings: settings.copyWith(remindersPerDay: 0),
        now: now,
      );

      expect(fake.scheduled, isEmpty);
    });

    test('une carte non encore due n occupe aucun creneau', () async {
      final now = DateTime(2026, 1, 1, 9, 0);
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      // Due demain a 23:00 : apres tous les creneaux planifies.
      final cards = [
        card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2026, 1, 2, 23, 0)),
      ];

      await service.rescheduleAll(cards: cards, settings: settings, now: now);

      expect(fake.scheduled, isEmpty);
    });
  });

  group('showTestNotification', () {
    test('envoie une notification immediate', () async {
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      final sent = await service.showTestNotification();

      expect(sent, isTrue);
      expect(fake.shownNow, hasLength(1));
    });

    test('signale son echec si les notifications sont refusees', () async {
      final fake = FakeScheduler(ready: false);
      final service = NotificationService(scheduler: fake);

      final sent = await service.showTestNotification();

      expect(sent, isFalse);
      expect(fake.shownNow, isEmpty);
    });
  });
}
