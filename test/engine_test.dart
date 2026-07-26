import 'package:flutter_test/flutter_test.dart';
import 'package:memotack/models.dart';
import 'package:memotack/engine.dart';

void main() {
  group('reviewCard', () {
    test('remembered avance le niveau et calcule la bonne echeance', () {
      final now = DateTime(2026, 1, 1, 10, 0);
      final card = Flashcard(
        id: '1',
        front: 'Anasarque',
        back: '',
        tagId: 'medical',
        level: 0,
        nextReviewAt: now,
        createdAt: now,
      );

      final result = reviewCard(card: card, remembered: true, now: now);

      expect(result.level, 1);
      expect(result.nextReviewAt, now.add(const Duration(hours: 4)));
    });

    test('non remembered recule le niveau et rapproche l echeance', () {
      final now = DateTime(2026, 1, 1, 10, 0);
      final card = Flashcard(
        id: '1',
        front: 'Test',
        back: '',
        tagId: 'medical',
        level: 3,
        nextReviewAt: now,
        createdAt: now,
      );

      final result = reviewCard(card: card, remembered: false, now: now);

      expect(result.level, 2);
      expect(result.nextReviewAt, now.add(const Duration(hours: 12)));
    });

    test('le niveau ne descend jamais sous 0', () {
      final now = DateTime(2026, 1, 1, 10, 0);
      final card = Flashcard(
        id: '1',
        front: 'Test',
        back: '',
        tagId: 'medical',
        level: 0,
        nextReviewAt: now,
        createdAt: now,
      );

      final result = reviewCard(card: card, remembered: false, now: now);

      expect(result.level, 0);
      expect(result.nextReviewAt, now.add(const Duration(hours: 1)));
    });

    test('le niveau ne depasse jamais kMaxLevel', () {
      final now = DateTime(2026, 1, 1, 10, 0);
      final card = Flashcard(
        id: '1',
        front: 'Test',
        back: '',
        tagId: 'medical',
        level: kMaxLevel,
        nextReviewAt: now,
        createdAt: now,
      );

      final result = reviewCard(card: card, remembered: true, now: now);

      expect(result.level, kMaxLevel);
      expect(result.nextReviewAt, now.add(const Duration(hours: 168)));
    });

    test('l echeance repart de now, pas de l ancienne echeance (pas de derive)', () {
      final scheduledFor = DateTime(2026, 1, 1, 10, 0);
      final reviewedLateAt = DateTime(2026, 1, 3, 18, 0);
      final card = Flashcard(
        id: '1',
        front: 'Test',
        back: '',
        tagId: 'medical',
        level: 0,
        nextReviewAt: scheduledFor,
        createdAt: scheduledFor,
      );

      final result =
          reviewCard(card: card, remembered: true, now: reviewedLateAt);

      expect(result.nextReviewAt, reviewedLateAt.add(const Duration(hours: 4)));
    });
  });

  group('createFlashcard', () {
    test('cree une carte niveau 0 avec echeance dans 1h', () {
      final now = DateTime(2026, 1, 1, 10, 0);

      final card = createFlashcard(
        id: 'abc',
        front: 'Hook narratif',
        back: 'Les 3 premieres secondes',
        tagId: 'reseaux',
        now: now,
      );

      expect(card.level, 0);
      expect(card.nextReviewAt, now.add(const Duration(hours: 1)));
      expect(card.createdAt, now);
      expect(card.front, 'Hook narratif');
    });
  });

  group('dueCards / upcomingCards', () {
    final now = DateTime(2026, 1, 1, 12, 0);

    Flashcard cardAt(String id, DateTime nextReviewAt) => Flashcard(
          id: id,
          front: id,
          back: '',
          tagId: 't',
          level: 0,
          nextReviewAt: nextReviewAt,
          createdAt: now,
        );

    test('separe correctement dues et a venir, triees par echeance', () {
      final cards = [
        cardAt('futur-lointain', now.add(const Duration(days: 3))),
        cardAt('due-en-retard', now.subtract(const Duration(hours: 5))),
        cardAt('due-a-l-instant', now),
        cardAt('futur-proche', now.add(const Duration(hours: 2))),
      ];

      final due = dueCards(cards, now);
      final upcoming = upcomingCards(cards, now);

      expect(
        due.map((c) => c.id).toList(),
        ['due-en-retard', 'due-a-l-instant'],
      );
      expect(
        upcoming.map((c) => c.id).toList(),
        ['futur-proche', 'futur-lointain'],
      );
    });

    test('listes vides si aucune carte', () {
      expect(dueCards([], now), isEmpty);
      expect(upcomingCards([], now), isEmpty);
    });
  });

  group('buildDailySchedule', () {
    final settings = Settings(
      remindersPerDay: 4,
      activeHoursStart: '08:00',
      activeHoursEnd: '20:00',
      theme: AppTheme.dark,
    );

    Flashcard cardAt(String id, DateTime nextReviewAt) => Flashcard(
          id: id,
          front: id,
          back: '',
          tagId: 't',
          level: 0,
          nextReviewAt: nextReviewAt,
          createdAt: nextReviewAt,
        );

    test('sans aucune carte, tous les creneaux restent vides', () {
      final now = DateTime(2026, 1, 1, 7, 0);

      final schedule =
          buildDailySchedule(cards: [], settings: settings, now: now);

      // 4 creneaux aujourd'hui + 4 demain, puisque le calcul couvre
      // maintenant les deux jours.
      expect(schedule.length, 8);
      expect(schedule.every((s) => s.flashcardId == null), isTrue);
    });

    test('les cartes les plus en retard sont assignees en premier', () {
      final now = DateTime(2026, 1, 1, 7, 0);
      final cards = [
        cardAt('recente', now.subtract(const Duration(hours: 1))),
        cardAt('ancienne', now.subtract(const Duration(days: 2))),
      ];

      final schedule =
          buildDailySchedule(cards: cards, settings: settings, now: now);

      expect(schedule[0].flashcardId, 'ancienne');
      expect(schedule[1].flashcardId, 'recente');
      expect(schedule[2].flashcardId, isNull);
      expect(schedule[3].flashcardId, isNull);
    });

    test('les creneaux deja passes ne sont pas repris, mais demain suit', () {
      final now = DateTime(2026, 1, 1, 15, 0);

      final schedule =
          buildDailySchedule(cards: [], settings: settings, now: now);

      // Seul le creneau de 17:00 reste aujourd'hui (08:00, 11:00 et 14:00
      // sont deja passes), plus les 4 creneaux de demain : 5 au total.
      expect(schedule.length, 5);
    });

    test('remindersPerDay=0 ne programme rien', () {
      final now = DateTime(2026, 1, 1, 7, 0);
      final zeroSettings = settings.copyWith(remindersPerDay: 0);

      final schedule =
          buildDailySchedule(cards: [], settings: zeroSettings, now: now);

      expect(schedule, isEmpty);
    });

    test('plage horaire qui traverse minuit (ex. 20h -> 8h) est geree correctement', () {
      final now = DateTime(2026, 1, 1, 7, 0);
      final overnightSettings = settings.copyWith(
        activeHoursStart: '20:00',
        activeHoursEnd: '08:00',
      );

      final schedule =
          buildDailySchedule(cards: [], settings: overnightSettings, now: now);

      // Fenetre 20h -> 8h le lendemain = 12h, divisee en 4 = un creneau
      // toutes les 3h. Le calcul couvrant aujourd'hui ET demain, ca fait
      // 4 creneaux pour chaque jour, tous a venir puisque now = 7h : 8 au total.
      expect(schedule.length, 8);
    });

    test('plage finissant a minuit (00:00) traverse bien vers le lendemain', () {
      final now = DateTime(2026, 1, 1, 7, 0);
      final midnightSettings = settings.copyWith(
        activeHoursStart: '09:00',
        activeHoursEnd: '00:00',
      );

      final schedule =
          buildDailySchedule(cards: [], settings: midnightSettings, now: now);

      // 09:00 -> 00:00 le lendemain = 15h, divisee en 4 creneaux, pour
      // aujourd'hui et pour demain : 8 au total.
      expect(schedule.length, 8);
    });

    test('plus de cartes dues que de creneaux : les surplus attendent', () {
      final now = DateTime(2026, 1, 1, 7, 0);
      final cards = List.generate(
        10,
        (i) => cardAt('carte$i', now.subtract(Duration(hours: i + 1))),
      );

      final schedule =
          buildDailySchedule(cards: cards, settings: settings, now: now);

      // 4 creneaux aujourd'hui + 4 demain = 8, pour 10 cartes dues : les 2
      // moins en retard (carte0, carte1) restent en attente.
      expect(schedule.length, 8);
      expect(schedule.every((s) => s.flashcardId != null), isTrue);

      final assignedIds =
          schedule.map((s) => s.flashcardId).whereType<String>().toSet();
      expect(
        assignedIds,
        {
          'carte9',
          'carte8',
          'carte7',
          'carte6',
          'carte5',
          'carte4',
          'carte3',
          'carte2',
        },
      );
    });
  });
}
