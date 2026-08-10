import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'engine.dart';
import 'models.dart';

const String kChannelId = 'memotack_rappels';
const String kChannelName = 'Rappels MémoTack';
const String kChannelDescription = 'Rappels pour réviser tes mots et phrases';

/// Identifiant reserve a la notification de diagnostic, hors de la plage
/// utilisee par les rappels (qui numerotent a partir de 0).
const int kDebugNotificationId = 999999;

/// Un rappel effectivement remis au planificateur.
class PlannedReminder {
  final int id;
  final String body;
  final DateTime time;

  const PlannedReminder({
    required this.id,
    required this.body,
    required this.time,
  });
}

/// Couche Android isolee derriere une interface : la logique de planification
/// devient testable sans passer par les canaux de plateforme, qui ne sont pas
/// disponibles sous `flutter test`.
abstract class ReminderScheduler {
  /// Renvoie `true` si les notifications peuvent reellement etre affichees.
  Future<bool> init();
  Future<void> cancelAll();
  Future<void> schedule(PlannedReminder reminder);
  Future<void> showNow({required int id, required String title, required String body});
}

/// Implementation reelle, adossee a flutter_local_notifications.
class AndroidReminderScheduler implements ReminderScheduler {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    kChannelId,
    kChannelName,
    channelDescription: kChannelDescription,
    importance: Importance.high,
    priority: Priority.high,
  );
  static const NotificationDetails _details = NotificationDetails(android: _androidDetails);

  @override
  Future<bool> init() async {
    try {
      tz_data.initializeTimeZones();
      // Le fuseau ne sert qu'a exprimer un instant absolu : TZDateTime.from
      // conserve l'instant, donc un rappel calcule a 11h45 heure de l'appareil
      // se declenche bien a 11h45, quel que soit le fuseau choisi ici.
      tz.setLocalLocation(tz.getLocation('Africa/Lagos'));

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _plugin.initialize(initSettings);

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      // Le canal doit exister avant toute notification. En le creant
      // explicitement, on garantit son importance : un canal cree
      // implicitement avec une importance faible ne peut plus etre releve
      // ensuite (Android 8+ interdit d'elever un canal existant).
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          kChannelId,
          kChannelName,
          description: kChannelDescription,
          importance: Importance.high,
        ),
      );

      final granted = await androidImpl?.requestNotificationsPermission() ?? true;
      if (!granted) {
        debugPrint('MémoTack: permission de notification refusee.');
        return false;
      }

      // Sans SCHEDULE_EXACT_ALARM accorde, on retombera sur des alarmes
      // inexactes dans _scheduleOne plutot que d'echouer.
      await androidImpl?.requestExactAlarmsPermission();

      return true;
    } catch (e) {
      debugPrint('MémoTack: initialisation des notifications impossible ($e)');
      return false;
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('MémoTack: annulation des rappels impossible ($e)');
    }
  }

  @override
  Future<void> schedule(PlannedReminder reminder) async {
    final when = tz.TZDateTime.from(reminder.time, tz.local);
    try {
      await _plugin.zonedSchedule(
        reminder.id,
        'MémoTack',
        reminder.body,
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // L'utilisateur n'a pas accorde les alarmes exactes : mieux vaut un
      // rappel approximatif que pas de rappel du tout.
      try {
        await _plugin.zonedSchedule(
          reminder.id,
          'MémoTack',
          reminder.body,
          when,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('MémoTack: rappel ${reminder.id} impossible a programmer ($e)');
      }
    }
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(id, title, body, _details);
    } catch (e) {
      debugPrint('MémoTack: notification immediate impossible ($e)');
    }
  }
}

/// Traduit les creneaux calcules par [buildDailySchedule] en rappels concrets.
///
/// Fonction pure, donc directement testable : elle ne garde que les creneaux
/// portant une carte existante, et numerote les rappels a partir de 0.
List<PlannedReminder> planReminders({
  required List<Flashcard> cards,
  required Settings settings,
  required DateTime now,
}) {
  final byId = {for (final c in cards) c.id: c};
  final schedule = buildDailySchedule(cards: cards, settings: settings, now: now);

  final reminders = <PlannedReminder>[];
  for (final slot in schedule) {
    final flashcardId = slot.flashcardId;
    if (flashcardId == null) continue;
    final card = byId[flashcardId];
    if (card == null) continue;

    reminders.add(
      PlannedReminder(id: reminders.length, body: card.front, time: slot.time),
    );
  }
  return reminders;
}

/// Gere la programmation des rappels sous forme de notifications Android.
///
/// Toute erreur est interceptee et journalisee sans jamais faire planter
/// l'application.
class NotificationService {
  NotificationService({ReminderScheduler? scheduler})
      : _scheduler = scheduler ?? AndroidReminderScheduler();

  static final NotificationService instance = NotificationService();

  final ReminderScheduler _scheduler;
  bool _ready = false;

  /// Vrai une fois que la couche Android est prete a afficher des rappels.
  bool get isReady => _ready;

  Future<void> init() async {
    // On ne memorise que le succes : si l'utilisateur a refuse la permission
    // puis l'accorde depuis les reglages Android, la tentative suivante
    // reussira au lieu de rester bloquee sur l'echec initial.
    if (_ready) return;
    _ready = await _scheduler.init();
  }

  Future<void> rescheduleAll({
    required List<Flashcard> cards,
    required Settings settings,
    DateTime? now,
  }) async {
    await init();
    if (!_ready) return;

    await _scheduler.cancelAll();

    final reminders = planReminders(
      cards: cards,
      settings: settings,
      now: now ?? DateTime.now(),
    );
    for (final reminder in reminders) {
      await _scheduler.schedule(reminder);
    }
  }

  /// Envoie une notification IMMEDIATE (pas programmee), pour verifier la
  /// chaine Android — permission, canal, affichage — independamment de la
  /// programmation a une heure precise.
  ///
  /// Si celle-ci s'affiche mais que les rappels programmes n'arrivent pas, le
  /// probleme est du cote des alarmes : receivers absents du manifeste ou
  /// alarmes exactes refusees.
  Future<bool> showTestNotification() async {
    await init();
    if (!_ready) return false;

    await _scheduler.showNow(
      id: kDebugNotificationId,
      title: 'MémoTack',
      body: 'Notification de test — la chaîne fonctionne.',
    );
    return true;
  }
}
