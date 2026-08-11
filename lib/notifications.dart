import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'engine.dart';
import 'models.dart';

const String kChannelId = 'memotack_rappels';
const String kChannelName = 'Rappels MémoTack';
const String kChannelDescription = 'Rappels pour réviser tes mots et phrases';

/// Nombre maximal de rappels reels programmes en une fois : deux jours de
/// creneaux, au maximum 10 par jour (borne imposee par l'ecran Reglages).
/// Les rappels reels occupent donc toujours les identifiants 0 a 19.
const int kMaxReminderCount = 20;

/// Identifiant de la notification de diagnostic immediate, hors de la plage
/// des rappels reels.
const int kDebugNotificationId = 999999;

/// Identifiant du rappel de diagnostic programme a 60 s. Distinct de
/// [kDebugNotificationId] pour que les deux tests puissent coexister, et lui
/// aussi hors de la plage des rappels reels : une replanification ne doit
/// jamais l'annuler.
const int kDebugScheduledNotificationId = 999998;

/// Duree par defaut avant le declenchement du rappel de diagnostic.
const Duration kDebugScheduledDelay = Duration(seconds: 60);

/// Etat reel de la chaine de notification, lu depuis Android.
///
/// Sert a distinguer les pannes qui se ressemblent vues de l'exterieur : une
/// notification programmee qui n'arrive pas peut venir d'une permission
/// refusee, d'alarmes exactes non autorisees, ou d'une alarme jamais posee.
class NotificationDiagnostics {
  /// `null` quand Android n'a pas su repondre (ou hors Android).
  final bool? notificationsEnabled;

  /// Correspond a `AlarmManager.canScheduleExactAlarms()`. A `false`, les
  /// rappels retombent sur des alarmes inexactes, que Doze peut retarder de
  /// plusieurs minutes : un test a 60 s semble alors ne rien declencher.
  final bool? canScheduleExactAlarms;

  /// Nombre d'alarmes reellement en attente cote Android.
  final int pendingCount;

  /// Version de l'application installee, lue depuis l'APK.
  final String appVersion;

  const NotificationDiagnostics({
    required this.notificationsEnabled,
    required this.canScheduleExactAlarms,
    required this.pendingCount,
    required this.appVersion,
  });
}

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

  /// Annule un rappel precis. Volontairement plus fin qu'un `cancelAll()` :
  /// une replanification ne doit annuler que les rappels reels, jamais les
  /// notifications de diagnostic.
  Future<void> cancel(int id);

  Future<void> schedule(PlannedReminder reminder);
  Future<void> showNow({required int id, required String title, required String body});

  /// Lit l'etat courant de la chaine Android.
  Future<NotificationDiagnostics> diagnostics();

  /// Ouvre l'ecran systeme « Alarmes et rappels ».
  Future<void> openExactAlarmSettings();
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
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('MémoTack: annulation du rappel $id impossible ($e)');
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

  @override
  Future<NotificationDiagnostics> diagnostics() async {
    // Volontairement tolerant : le diagnostic doit rester lisible meme quand
    // la chaine est cassee, c'est justement le cas qu'il sert a expliquer.
    bool? enabled;
    bool? exact;
    var pending = 0;
    var version = 'inconnue';

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    try {
      enabled = await androidImpl?.areNotificationsEnabled();
    } catch (e) {
      debugPrint('MémoTack: areNotificationsEnabled indisponible ($e)');
    }

    try {
      exact = await androidImpl?.canScheduleExactNotifications();
    } catch (e) {
      debugPrint('MémoTack: canScheduleExactNotifications indisponible ($e)');
    }

    try {
      pending = (await _plugin.pendingNotificationRequests()).length;
    } catch (e) {
      debugPrint('MémoTack: pendingNotificationRequests indisponible ($e)');
    }

    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (e) {
      debugPrint('MémoTack: version de l\'application indisponible ($e)');
    }

    return NotificationDiagnostics(
      notificationsEnabled: enabled,
      canScheduleExactAlarms: exact,
      pendingCount: pending,
      appVersion: version,
    );
  }

  @override
  Future<void> openExactAlarmSettings() async {
    try {
      // Ouvre ACTION_REQUEST_SCHEDULE_EXACT_ALARM. Note : le plugin
      // n'ouvre l'ecran que si la permission n'est PAS deja accordee.
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('MémoTack: ouverture des reglages d\'alarme impossible ($e)');
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

    // On annule la plage des rappels reels (0 a kMaxReminderCount - 1) plutot
    // que d'appeler cancelAll() : un cancelAll() emporterait aussi le rappel
    // de diagnostic programme, qui doit survivre a une replanification.
    for (var id = 0; id < kMaxReminderCount; id++) {
      await _scheduler.cancel(id);
    }

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

  /// Programme un rappel de diagnostic a `now + delay`, en empruntant
  /// EXACTEMENT le chemin des vrais rappels : meme [ReminderScheduler], donc
  /// meme `zonedSchedule()`, meme canal et meme receiver.
  ///
  /// C'est la difference avec [showTestNotification], qui affiche
  /// immediatement sans passer par AlarmManager : si celle-ci s'affiche mais
  /// pas celle-la, le probleme est bien du cote des alarmes.
  ///
  /// Son identifiant dedie la place hors de la plage annulee par
  /// [rescheduleAll], donc ajouter une carte pendant le compte a rebours ne
  /// l'annule pas.
  Future<bool> scheduleTestReminder({
    DateTime? now,
    Duration delay = kDebugScheduledDelay,
  }) async {
    await init();
    if (!_ready) return false;

    await _scheduler.schedule(
      PlannedReminder(
        id: kDebugScheduledNotificationId,
        body: 'Rappel programmé de test — la chaîne complète fonctionne.',
        time: (now ?? DateTime.now()).add(delay),
      ),
    );
    return true;
  }

  /// Etat courant de la chaine Android.
  ///
  /// Contrairement aux autres methodes, celle-ci ne s'interrompt PAS quand
  /// l'initialisation a echoue : c'est justement dans ce cas qu'il faut
  /// pouvoir lire pourquoi.
  Future<NotificationDiagnostics> diagnostics() async {
    await init();
    return _scheduler.diagnostics();
  }

  /// Ouvre l'ecran systeme « Alarmes et rappels ».
  Future<void> openExactAlarmSettings() => _scheduler.openExactAlarmSettings();
}
