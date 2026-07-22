import 'models.dart';

/// Fait avancer ou reculer une carte après une révision.
///
/// Choix assumé : l'intervalle repart de l'instant de la révision (`now`),
/// pas de l'échéance initialement prévue. Réviser en retard ne pénalise
/// donc pas le planning futur.
Flashcard reviewCard({
  required Flashcard card,
  required bool remembered,
  required DateTime now,
}) {
  int newLevel = remembered ? card.level + 1 : card.level - 1;
  if (newLevel < 0) newLevel = 0;
  if (newLevel > kMaxLevel) newLevel = kMaxLevel;

  final hours = kLevelIntervalsHours[newLevel];
  final nextReviewAt = now.add(Duration(hours: hours));

  return card.copyWith(level: newLevel, nextReviewAt: nextReviewAt);
}

/// Crée une nouvelle carte, prête à être révisée une première fois
/// dans kLevelIntervalsHours[0] heures (1h par défaut).
Flashcard createFlashcard({
  required String id,
  required String front,
  required String back,
  required String tagId,
  required DateTime now,
}) {
  return Flashcard(
    id: id,
    front: front,
    back: back,
    tagId: tagId,
    level: 0,
    nextReviewAt: now.add(Duration(hours: kLevelIntervalsHours[0])),
    createdAt: now,
  );
}

/// Cartes dues à l'instant `now`, triées de la plus en retard à la moins
/// en retard.
List<Flashcard> dueCards(List<Flashcard> cards, DateTime now) {
  final due = cards.where((c) => !c.nextReviewAt.isAfter(now)).toList();
  due.sort((a, b) => a.nextReviewAt.compareTo(b.nextReviewAt));
  return due;
}

/// Cartes pas encore dues, triées par échéance la plus proche.
List<Flashcard> upcomingCards(List<Flashcard> cards, DateTime now) {
  final upcoming = cards.where((c) => c.nextReviewAt.isAfter(now)).toList();
  upcoming.sort((a, b) => a.nextReviewAt.compareTo(b.nextReviewAt));
  return upcoming;
}

DateTime _combineDateAndTime(DateTime date, String hhmm) {
  final parts = hhmm.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  return DateTime(date.year, date.month, date.day, hour, minute);
}

/// Calcule les créneaux de rappel restants pour aujourd'hui, et la carte
/// à montrer à chaque créneau, selon les réglages et les cartes dues.
List<ScheduledReminder> buildDailySchedule({
  required List<Flashcard> cards,
  required Settings settings,
  required DateTime now,
}) {
  final startToday = _combineDateAndTime(now, settings.activeHoursStart);
  final endToday = _combineDateAndTime(now, settings.activeHoursEnd);

  if (!endToday.isAfter(startToday) || settings.remindersPerDay <= 0) {
    return const [];
  }

  final totalWindow = endToday.difference(startToday);
  final slotGap = Duration(
    microseconds: totalWindow.inMicroseconds ~/ settings.remindersPerDay,
  );

  final allSlots = List<DateTime>.generate(
    settings.remindersPerDay,
    (i) => startToday.add(slotGap * i),
  );

  final remainingSlots = allSlots.where((slot) => slot.isAfter(now)).toList();

  final queue = List<Flashcard>.of(cards)
    ..sort((a, b) => a.nextReviewAt.compareTo(b.nextReviewAt));
  var queueIndex = 0;

  final result = <ScheduledReminder>[];
  for (final slot in remainingSlots) {
    if (queueIndex < queue.length &&
        !queue[queueIndex].nextReviewAt.isAfter(slot)) {
      result.add(
        ScheduledReminder(time: slot, flashcardId: queue[queueIndex].id),
      );
      queueIndex++;
    } else {
      result.add(ScheduledReminder(time: slot, flashcardId: null));
    }
  }
  return result;
}
