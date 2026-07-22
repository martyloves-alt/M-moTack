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
      final reviewedLateAt = DateTime(2026, 1, 3, 18, 0); // 2 jours de retard
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

      expect(schedule.length, 4);
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

    test('les creneaux deja passes ne sont pas repris', () {
      final now = DateTime(2026, 1, 1, 15, 0); // en cours de journee

      final schedule =
          buildDailySchedule(cards: [], settings: settings, now: now);

      // Fenetre 8h-20h divisee en 4 = creneaux a 8h, 11h, 14h, 17h.
      // Seul 17h est encore a venir apres 15h.
      expect(schedule.length, 1);
    });

    test('remindersPerDay=0 ne programme rien', () {
      final now = DateTime(2026, 1, 1, 7, 0);
      final zeroSettings = settings.copyWith(remindersPerDay: 0);

      final schedule =
          buildDailySchedule(cards: [], settings: zeroSettings, now: now);

      expect(schedule, isEmpty);
    });

    test('plage horaire invalide (fin avant debut) ne programme rien', () {
      final now = DateTime(2026, 1, 1, 7, 0);
      final invalidSettings = settings.copyWith(
        activeHoursStart: '20:00',
        activeHoursEnd: '08:00',
      );

      final schedule =
          buildDailySchedule(cards: [], settings: invalidSettings, now: now);

      expect(schedule, isEmpty);
    });

    test('plus de cartes dues que de creneaux : les surplus attendent', () {
      final now = DateTime(2026, 1, 1, 7, 0);
      final cards = List.generate(
        6,
        (i) => cardAt('carte$i', now.subtract(Duration(hours: i + 1))),
      );

      final schedule =
          buildDailySchedule(cards: cards, settings: settings, now: now);

      expect(schedule.length, 4);
      expect(schedule.every((s) => s.flashcardId != null), isTrue);

      final assignedIds =
          schedule.map((s) => s.flashcardId).whereType<String>().toSet();
      expect(assignedIds, {'carte5', 'carte4', 'carte3', 'carte2'});
    });
  });
}
