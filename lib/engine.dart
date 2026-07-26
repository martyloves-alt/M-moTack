import 'models.dart';

/// Fait avancer ou reculer une carte apres une revision.
///
/// Choix assume : l'intervalle repart de l'instant de la revision (`now`),
/// pas de l'echeance initialement prevue. Reviser en retard ne penalise
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

List<Flashcard> dueCards(List<Flashcard> cards, DateTime now) {
  final due = cards.where((c) => !c.nextReviewAt.isAfter(now)).toList();
  due.sort((a, b) => a.nextReviewAt.compareTo(b.nextReviewAt));
  return due;
}

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

/// Calcule les creneaux de rappel pour un jour donne (seule la date de
/// [dayAnchor] est utilisee), selon les heures actives et le nombre de
/// rappels par jour.
///
/// Si l'heure de fin tombe avant (ou egale a) l'heure de debut, la plage
/// est consideree comme traversant minuit (ex. 09:00 -> 00:00 = 15h,
/// jusqu'a minuit la nuit suivante) plutot que d'etre invalide.
List<DateTime> _slotsForDay(DateTime dayAnchor, Settings settings) {
  final start = _combineDateAndTime(dayAnchor, settings.activeHoursStart);
  var end = _combineDateAndTime(dayAnchor, settings.activeHoursEnd);
  if (!end.isAfter(start)) {
    end = end.add(const Duration(days: 1));
  }

  final totalWindow = end.difference(start);
  final slotGap = Duration(
    microseconds: totalWindow.inMicroseconds ~/ settings.remindersPerDay,
  );

  return List<DateTime>.generate(
    settings.remindersPerDay,
    (i) => start.add(slotGap * i),
  );
}

/// Calcule les creneaux de rappel a venir et la carte a montrer a chaque
/// creneau, selon les reglages et les cartes dues.
///
/// Couvre aujourd'hui ET demain (pas seulement aujourd'hui) : si tous les
/// creneaux du jour sont deja passes au moment de l'appel (ex. l'appli est
/// rouverte tard le soir, apres le dernier creneau prevu), on retombe quand
/// meme sur les creneaux de demain plutot que de ne rien programmer du tout.
List<ScheduledReminder> buildDailySchedule({
  required List<Flashcard> cards,
  required Settings settings,
  required DateTime now,
}) {
  if (settings.remindersPerDay <= 0) {
    return const [];
  }

  final tomorrow = now.add(const Duration(days: 1));
  final allSlots = [
    ..._slotsForDay(now, settings),
    ..._slotsForDay(tomorrow, settings),
  ]..sort();

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
