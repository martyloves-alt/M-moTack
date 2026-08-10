import 'package:flutter/material.dart';

import '../notifications.dart';
import '../storage.dart';
import '../theme.dart';

class ReglagesScreen extends StatelessWidget {
  final AppState appState;
  const ReglagesScreen({super.key, required this.appState});

  int get _activeMinutes {
    final startParts = appState.settings.activeHoursStart.split(':');
    final endParts = appState.settings.activeHoursEnd.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    var endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    if (endMinutes <= startMinutes) {
      endMinutes += 24 * 60;
    }
    return endMinutes - startMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final settings = appState.settings;
    final totalMinutes = _activeMinutes;
    final perDayMinutes =
        settings.remindersPerDay > 0 ? totalMinutes / settings.remindersPerDay : 0.0;
    final intervalLabel = (perDayMinutes / 60).toStringAsFixed(1).replaceAll('.', ',');

    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        elevation: 0,
        title: Text(
          'Réglages',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.paper, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RAPPELS PAR JOUR', style: stampStyle(color: AppColors.soot.withValues(alpha: 0.6))),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _roundButton(
                      icon: Icons.remove,
                      background: AppColors.soot.withValues(alpha: 0.08),
                      iconColor: AppColors.soot,
                      onTap: () {
                        int next = settings.remindersPerDay - 1;
                        if (next < 1) next = 1;
                        appState.updateSettings(settings.copyWith(remindersPerDay: next));
                      },
                    ),
                    Text(
                      '${settings.remindersPerDay}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.soot, fontSize: 30),
                    ),
                    _roundButton(
                      icon: Icons.add,
                      background: AppColors.inkBlue,
                      iconColor: AppColors.paper,
                      onTap: () {
                        int next = settings.remindersPerDay + 1;
                        if (next > 10) next = 10;
                        appState.updateSettings(settings.copyWith(remindersPerDay: next));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Environ un rappel toutes les $intervalLabel h, entre ${settings.activeHoursStart} et ${settings.activeHoursEnd}.',
                  style: TextStyle(color: AppColors.soot.withValues(alpha: 0.6), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PLAGE HORAIRE ACTIVE', style: stampStyle(color: AppColors.soot.withValues(alpha: 0.6))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _timeButton(
                        context: context,
                        label: 'Début',
                        value: settings.activeHoursStart,
                        onPicked: (v) => appState.updateSettings(settings.copyWith(activeHoursStart: v)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _timeButton(
                        context: context,
                        label: 'Fin',
                        value: settings.activeHoursEnd,
                        onPicked: (v) => appState.updateSettings(settings.copyWith(activeHoursEnd: v)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DIAGNOSTIC', style: stampStyle(color: AppColors.soot.withValues(alpha: 0.6))),
                const SizedBox(height: 10),
                Text(
                  'Envoie une notification tout de suite. Si elle apparaît mais que '
                  'les rappels programmés n\'arrivent jamais, le problème vient des '
                  'alarmes, pas de l\'affichage.',
                  style: TextStyle(color: AppColors.soot.withValues(alpha: 0.6), fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _sendTestNotification(context),
                    icon: const Icon(Icons.notifications_active_outlined, size: 18),
                    label: const Text('Tester une notification'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.inkBlue,
                      foregroundColor: AppColors.paper,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendTestNotification(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final sent = await NotificationService.instance.showTestNotification();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Notification envoyée. Si tu ne la vois pas, vérifie les autorisations de MémoTack.'
              : 'Impossible : les notifications ne sont pas autorisées pour MémoTack.',
        ),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color background,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 18),
      ),
    );
  }

  Widget _timeButton({
    required BuildContext context,
    required String label,
    required String value,
    required ValueChanged<String> onPicked,
  }) {
    return GestureDetector(
      onTap: () async {
        final parts = value.split(':');
        final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        final picked = await showTimePicker(context: context, initialTime: initial);
        if (picked != null) {
          final formatted =
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
          onPicked(formatted);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.soot.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppColors.soot.withValues(alpha: 0.5), fontSize: 10)),
            Text(value, style: TextStyle(color: AppColors.soot, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
