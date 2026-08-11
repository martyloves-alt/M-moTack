import 'dart:async';

import 'package:flutter/material.dart';

import '../notifications.dart';
import '../storage.dart';
import '../theme.dart';

class ReglagesScreen extends StatefulWidget {
  final AppState appState;
  const ReglagesScreen({super.key, required this.appState});

  @override
  State<ReglagesScreen> createState() => _ReglagesScreenState();
}

class _ReglagesScreenState extends State<ReglagesScreen> with WidgetsBindingObserver {
  AppState get appState => widget.appState;

  /// Secondes restantes avant le declenchement du rappel de test.
  /// `null` tant qu'aucun test programme n'est en cours.
  int? _secondsLeft;
  Timer? _countdown;

  /// Instant vise par le rappel de test, source de verite du compte a rebours.
  DateTime? _deadline;

  NotificationDiagnostics? _diagnostics;
  Timer? _diagnosticsRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshDiagnostics();
    _diagnosticsRefresh = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshDiagnostics(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdown?.cancel();
    _diagnosticsRefresh?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Au retour de l'ecran systeme « Alarmes et rappels », la valeur doit
    // basculer immediatement plutot qu'au prochain tick.
    if (state == AppLifecycleState.resumed) {
      _refreshDiagnostics();
    }
  }

  Future<void> _refreshDiagnostics() async {
    final result = await NotificationService.instance.diagnostics();
    if (!mounted) return;
    setState(() => _diagnostics = result);
  }

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
                  'Les deux boutons ne testent pas la même chose.\n\n'
                  '• Immédiate : affiche une notification tout de suite, sans passer '
                  'par une alarme. Vérifie l\'autorisation et l\'affichage.\n\n'
                  '• Programmée : emprunte exactement le chemin des vrais rappels '
                  '(alarme Android + receiver), mais à 60 secondes.\n\n'
                  'Si l\'immédiate apparaît et pas la programmée, le problème vient '
                  'des alarmes, pas de l\'affichage.',
                  style: TextStyle(color: AppColors.soot.withValues(alpha: 0.6), fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _sendTestNotification(context),
                    icon: const Icon(Icons.notifications_active_outlined, size: 18),
                    label: const Text('Tester une notification immédiate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.inkBlue,
                      foregroundColor: AppColors.paper,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _secondsLeft != null ? null : () => _scheduleTestReminder(context),
                    icon: const Icon(Icons.alarm_outlined, size: 18),
                    label: const Text('Tester un rappel programmé (60 s)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.corail,
                      foregroundColor: AppColors.paper,
                      disabledBackgroundColor: AppColors.soot.withValues(alpha: 0.12),
                      disabledForegroundColor: AppColors.soot.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openExactAlarmSettings,
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Ouvrir « Alarmes et rappels »'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.inkBlue,
                      side: BorderSide(color: AppColors.inkBlue.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (_secondsLeft != null) ...[
                  const SizedBox(height: 12),
                  _countdownPanel(),
                ],
                const SizedBox(height: 12),
                _diagnosticsPanel(),
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

  Future<void> _scheduleTestReminder(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final scheduled = await NotificationService.instance.scheduleTestReminder();
    if (!mounted) return;

    if (!scheduled) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Impossible : les notifications ne sont pas autorisées pour MémoTack.'),
        ),
      );
      return;
    }

    _countdown?.cancel();
    // On vise un instant absolu plutot que de decrementer un compteur : si
    // l'ecran est mis en arriere-plan pendant le test — ce qui est le cas
    // normal pour voir arriver la notification — le compte a rebours reste
    // juste au retour.
    _deadline = DateTime.now().add(kDebugScheduledDelay);
    setState(() => _secondsLeft = kDebugScheduledDelay.inSeconds);

    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final deadline = _deadline;
      if (!mounted || deadline == null) {
        timer.cancel();
        return;
      }
      final left = deadline.difference(DateTime.now()).inSeconds;
      setState(() => _secondsLeft = left > 0 ? left : 0);
      if (left <= 0) timer.cancel();
    });
  }

  Future<void> _openExactAlarmSettings() async {
    await NotificationService.instance.openExactAlarmSettings();
    if (!mounted) return;
    // Si la permission etait deja accordee, le plugin n'ouvre aucun ecran :
    // le rafraichissement rend au moins l'etat courant visible.
    await _refreshDiagnostics();
  }

  Widget _diagnosticsPanel() {
    final d = _diagnostics;
    if (d == null) {
      return Text(
        'Lecture de l\'état…',
        style: TextStyle(color: AppColors.soot.withValues(alpha: 0.5), fontSize: 12),
      );
    }

    // Le point decisif : sans alarmes exactes, les rappels retombent sur des
    // alarmes inexactes, que le systeme peut retarder de plusieurs minutes.
    final exactOk = d.canScheduleExactAlarms == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.soot.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ÉTAT DU SYSTÈME', style: stampStyle(color: AppColors.soot.withValues(alpha: 0.5))),
          const SizedBox(height: 8),
          _diagnosticRow('Notifications autorisées', _boolLabel(d.notificationsEnabled),
              ok: d.notificationsEnabled == true),
          _diagnosticRow('Alarmes exactes', _boolLabel(d.canScheduleExactAlarms), ok: exactOk),
          _diagnosticRow('Rappels en attente', '${d.pendingCount}', ok: d.pendingCount > 0),
          _diagnosticRow('Version', d.appVersion, neutral: true),
          if (!exactOk) ...[
            const SizedBox(height: 8),
            Text(
              'Les alarmes exactes ne sont pas autorisées : c\'est ce qui empêche '
              'les rappels programmés d\'arriver à l\'heure. Ouvre « Alarmes et '
              'rappels » ci-dessus et autorise MémoTack.',
              style: TextStyle(color: AppColors.corail, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  String _boolLabel(bool? value) {
    if (value == null) return 'inconnu';
    return value ? 'oui' : 'non';
  }

  Widget _diagnosticRow(String label, String value, {bool ok = false, bool neutral = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.soot.withValues(alpha: 0.7), fontSize: 12)),
          Row(
            children: [
              if (!neutral) ...[
                Icon(
                  ok ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: ok ? AppColors.sauge : AppColors.corail,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                value,
                style: TextStyle(
                  color: neutral ? AppColors.soot.withValues(alpha: 0.7) : AppColors.soot,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _dismissCountdown() {
    _countdown?.cancel();
    _countdown = null;
    _deadline = null;
    setState(() => _secondsLeft = null);
  }

  Widget _countdownPanel() {
    final left = _secondsLeft ?? 0;
    final done = left <= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (done ? AppColors.corail : AppColors.inkBlue).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!done) ...[
            Row(
              children: [
                Text(
                  '$left',
                  style: TextStyle(
                    color: AppColors.inkBlue,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    's',
                    style: TextStyle(color: AppColors.inkBlue, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Rappel programmé. Tu peux quitter l\'application : la notification '
              'doit arriver même écran éteint.',
              style: TextStyle(color: AppColors.soot.withValues(alpha: 0.7), fontSize: 12),
            ),
          ] else ...[
            Text(
              'La notification aurait dû apparaître.',
              style: TextStyle(
                color: AppColors.soot,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Si rien ne s\'est affiché, vérifie l\'optimisation de la batterie : '
              'sur Xiaomi, Huawei, Samsung et OnePlus, elle bloque les alarmes '
              'exactes même quand tout est correctement autorisé. Il faut exclure '
              'MémoTack de l\'optimisation, et autoriser les alarmes et rappels '
              'dans les paramètres de l\'application.',
              style: TextStyle(color: AppColors.soot.withValues(alpha: 0.7), fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _dismissCountdown,
                child: Text('Fermer', style: TextStyle(color: AppColors.inkBlue)),
              ),
            ),
          ],
        ],
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
