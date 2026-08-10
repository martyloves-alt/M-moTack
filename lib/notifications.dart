import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'engine.dart';
import 'models.dart';

/// Gere la programmation des rappels sous forme de notifications Android.
///
/// Toute erreur est interceptee et journalisee sans jamais faire planter
/// l'application.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      tz_data.initializeTimeZones();
      // Fuseau fixe (UTC+1, comme Cotonou) : evite une dependance
      // supplementaire rien que pour detecter le fuseau de l'appareil.
      tz.setLocalLocation(tz.getLocation('Africa/Lagos'));

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _plugin.initialize(initSettings);

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();

      _initialized = true;
    } catch (e) {
      debugPrint('MémoTack: initialisation des notifications impossible ($e)');
    }
  }

  Flashcard? _findCard(List<Flashcard> cards, String id) {
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _scheduleOne({
    required int id,
    required String body,
    required DateTime time,
    required NotificationDetails details,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        'MémoTack',
        body,
        tz.TZDateTime.from(time, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id,
          'MémoTack',
          body,
          tz.TZDateTime.from(time, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('MémoTack: rappel $id impossible a programmer ($e)');
      }
    }
  }

  Future<void> rescheduleAll({
    required List<Flashcard> cards,
    required Settings settings,
  }) async {
    await init();
    if (!_initialized) return;

    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('MémoTack: annulation des rappels impossible ($e)');
    }

    final now = DateTime.now();
    final schedule = buildDailySchedule(cards: cards, settings: settings, now: now);

    const androidDetails = AndroidNotificationDetails(
      'memotack_rappels',
      'Rappels MémoTack',
      channelDescription: 'Rappels pour réviser tes mots et phrases',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    var id = 0;
    for (final slot in schedule) {
      final flashcardId = slot.flashcardId;
      if (flashcardId == null) continue;
      final card = _findCard(cards, flashcardId);
      if (card == null) continue;

      await _scheduleOne(id: id, body: card.front, time: slot.time, details: details);
      id++;
    }
  }

  /// TEST TEMPORAIRE : envoie une notification IMMEDIATE (pas programmee),
  /// pour verifier que la chaine Android (permission, canal, affichage)
  /// fonctionne, independamment de la programmation a une heure precise.
  /// A retirer une fois le diagnostic termine.
  Future<void> showTestNotification() async {
    await init();
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'memotack_rappels',
      'Rappels MémoTack',
      channelDescription: 'Rappels pour réviser tes mots et phrases',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(999999, 'MémoTack', 'Notification de test', details);
    } catch (e) {
      debugPrint('MémoTack: notification de test impossible ($e)');
    }
  }
}
