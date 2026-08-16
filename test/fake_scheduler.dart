import 'package:memotack/models.dart';
import 'package:memotack/notifications.dart';

/// Version renvoyee par le faux planificateur. Exposee en constante pour que
/// les tests ne la repetent pas : sinon chaque montee de version cassait une
/// assertion sans rapport.
const String kFakeAppVersion = '0.4.0+1';

/// Planificateur factice : enregistre ce qui lui est demande, sans jamais
/// toucher a la couche Android.
///
/// [scheduled] modelise la file d'attente reelle d'Android : [cancel] en
/// retire l'entree correspondante, sans quoi « rappels en attente » ne
/// voudrait rien dire apres une suppression de carte.
class FakeScheduler implements ReminderScheduler {
  FakeScheduler({
    this.ready = true,
    this.canScheduleExactAlarms = true,
    this.scheduleFails = false,
  });

  final bool ready;
  final bool canScheduleExactAlarms;

  /// Simule une planification qui echoue cote Android sans lever d'exception
  /// jusqu'a l'appelant — le scenario exact observe sur Samsung.
  final bool scheduleFails;

  ScheduleAttempt? lastAttempt;

  int openExactAlarmSettingsCount = 0;

  int initCount = 0;
  final List<int> cancelled = [];
  final List<PlannedReminder> scheduled = [];
  final List<String> shownNow = [];

  /// Ordre d'appel, pour verifier que l'annulation precede la planification.
  final List<String> calls = [];

  /// Rectos des rappels actuellement en attente.
  List<String> get pendingBodies => scheduled.map((r) => r.body).toList();

  @override
  Future<bool> init() async {
    initCount++;
    calls.add('init');
    return ready;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    calls.add('cancel');
    scheduled.removeWhere((r) => r.id == id);
  }

  @override
  Future<ScheduleAttempt> schedule(PlannedReminder reminder) async {
    calls.add('schedule');
    final attempt = ScheduleAttempt(
      id: reminder.id,
      requestedTime: reminder.time,
      resolvedTime: reminder.time.toString(),
      mode: scheduleFails ? 'echec' : 'exact',
      success: !scheduleFails,
      error: scheduleFails ? 'PlatformException(error, simulé, null, null)' : null,
      at: DateTime(2026, 1, 1, 9, 0),
    );
    lastAttempt = attempt;
    // Une planification qui echoue ne laisse aucune alarme en attente.
    if (!scheduleFails) scheduled.add(reminder);
    return attempt;
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

  @override
  Future<NotificationDiagnostics> diagnostics() async {
    calls.add('diagnostics');
    return NotificationDiagnostics(
      notificationsEnabled: ready,
      canScheduleExactAlarms: canScheduleExactAlarms,
      pendingCount: scheduled.length,
      appVersion: kFakeAppVersion,
      lastError: lastAttempt?.error,
      lastAttempt: lastAttempt,
    );
  }

  @override
  Future<void> openExactAlarmSettings() async {
    openExactAlarmSettingsCount++;
    calls.add('openExactAlarmSettings');
  }
}

Flashcard card({
  required String id,
  required String front,
  required DateTime nextReviewAt,
  int level = 0,
  String tagId = 'medical',
  String back = '',
}) {
  return Flashcard(
    id: id,
    front: front,
    back: back,
    tagId: tagId,
    level: level,
    nextReviewAt: nextReviewAt,
    createdAt: nextReviewAt,
  );
}
