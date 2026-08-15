import 'package:flutter_test/flutter_test.dart';
import 'package:memotack/models.dart';
import 'package:memotack/notifications.dart';

import 'fake_scheduler.dart';

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

      expect(fake.calls.indexOf('cancel'), lessThan(fake.calls.indexOf('schedule')));
    });

    test('n annule que la plage des rappels reels, jamais les diagnostics', () async {
      final now = DateTime(2026, 1, 1, 9, 0);
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      final cards = [
        card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2026, 1, 1, 8, 0)),
      ];

      await service.rescheduleAll(cards: cards, settings: settings, now: now);

      // Toute la plage des rappels reels est balayee...
      expect(fake.cancelled, List<int>.generate(kMaxReminderCount, (i) => i));
      // ...mais aucun identifiant de diagnostic n'est touche : un cancelAll()
      // aurait emporte le rappel de test en cours.
      expect(fake.cancelled, isNot(contains(kDebugNotificationId)));
      expect(fake.cancelled, isNot(contains(kDebugScheduledNotificationId)));
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
      expect(fake.cancelled, isEmpty);
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

  group('scheduleTestReminder', () {
    test('appelle le planificateur avec une echeance future', () async {
      final now = DateTime(2026, 1, 1, 9, 0);
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      final scheduled = await service.scheduleTestReminder(now: now);

      expect(scheduled, isTrue);
      expect(fake.scheduled, hasLength(1));

      final reminder = fake.scheduled.single;
      expect(reminder.time.isAfter(now), isTrue);
      expect(reminder.time, now.add(const Duration(seconds: 60)));
    });

    test('emprunte le meme chemin que les vrais rappels, pas showNow', () async {
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      await service.scheduleTestReminder(now: DateTime(2026, 1, 1, 9, 0));

      // C'est tout l'interet du test : passer par schedule() donc
      // zonedSchedule(), et non par un affichage immediat.
      expect(fake.calls, contains('schedule'));
      expect(fake.shownNow, isEmpty);
    });

    test('utilise un identifiant dedie, hors de la plage des rappels reels', () async {
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      await service.scheduleTestReminder(now: DateTime(2026, 1, 1, 9, 0));

      final id = fake.scheduled.single.id;
      expect(id, kDebugScheduledNotificationId);
      expect(id, isNot(kDebugNotificationId));
      expect(id, greaterThanOrEqualTo(kMaxReminderCount));
    });

    test('survit a une replanification des vrais rappels', () async {
      final now = DateTime(2026, 1, 1, 9, 0);
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      await service.scheduleTestReminder(now: now);
      final testReminderId = fake.scheduled.single.id;

      // L'utilisateur ajoute une carte pendant le compte a rebours.
      await service.rescheduleAll(
        cards: [card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2026, 1, 1, 8, 0))],
        settings: settings,
        now: now,
      );

      expect(fake.cancelled, isNot(contains(testReminderId)));
    });

    test('ne programme rien si les notifications sont refusees', () async {
      final fake = FakeScheduler(ready: false);
      final service = NotificationService(scheduler: fake);

      final scheduled = await service.scheduleTestReminder(now: DateTime(2026, 1, 1, 9, 0));

      expect(scheduled, isFalse);
      expect(fake.scheduled, isEmpty);
    });

    test('signale false quand la planification echoue reellement', () async {
      // Regression : le compte a rebours demarrait meme quand aucune alarme
      // n'etait posee, parce que le succes n'etait jamais verifie.
      final fake = FakeScheduler(scheduleFails: true);
      final service = NotificationService(scheduler: fake);

      final scheduled = await service.scheduleTestReminder(now: DateTime(2026, 1, 1, 9, 0));

      expect(scheduled, isFalse);
      expect(fake.calls, contains('schedule'));
      expect(fake.scheduled, isEmpty);
    });
  });

  group('diagnostics', () {
    test('remonte l etat de la chaine Android', () async {
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      final d = await service.diagnostics();

      expect(d.notificationsEnabled, isTrue);
      expect(d.canScheduleExactAlarms, isTrue);
      expect(d.appVersion, kFakeAppVersion);
    });

    test('reste lisible meme quand l initialisation a echoue', () async {
      // C'est precisement le cas ou le diagnostic sert : il ne doit pas se
      // couper en meme temps que le reste de la chaine.
      final fake = FakeScheduler(ready: false);
      final service = NotificationService(scheduler: fake);

      final d = await service.diagnostics();

      expect(service.isReady, isFalse);
      expect(d.notificationsEnabled, isFalse);
      expect(fake.calls, contains('diagnostics'));
    });

    test('signale les alarmes exactes refusees', () async {
      final fake = FakeScheduler(canScheduleExactAlarms: false);
      final service = NotificationService(scheduler: fake);

      final d = await service.diagnostics();

      expect(d.canScheduleExactAlarms, isFalse);
    });

    test('compte les rappels en attente', () async {
      final now = DateTime(2026, 1, 1, 9, 0);
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      expect((await service.diagnostics()).pendingCount, 0);

      await service.rescheduleAll(
        cards: [card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2026, 1, 1, 8, 0))],
        settings: settings,
        now: now,
      );

      expect((await service.diagnostics()).pendingCount, 1);
    });

    test('expose l erreur brute et le compte rendu de planification', () async {
      final fake = FakeScheduler(scheduleFails: true);
      final service = NotificationService(scheduler: fake);

      await service.scheduleTestReminder(now: DateTime(2026, 1, 1, 9, 0));
      final d = await service.diagnostics();

      expect(d.lastError, contains('PlatformException'));
      expect(d.lastAttempt, isNotNull);
      expect(d.lastAttempt!.success, isFalse);
      expect(d.lastAttempt!.mode, 'echec');
      // Le symptome observe : rien en attente malgre un appel effectue.
      expect(d.pendingCount, 0);
    });

    test('openExactAlarmSettings delegue au planificateur', () async {
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      await service.openExactAlarmSettings();

      expect(fake.openExactAlarmSettingsCount, 1);
    });
  });
}
