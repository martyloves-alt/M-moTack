import 'package:flutter/material.dart';

import '../models.dart';
import '../playback.dart';
import '../speech.dart';
import '../storage.dart';
import '../theme.dart';

/// Ecran de lecture vocale d'une carte.
///
/// Tout le contenu est accessible a tout moment : le texte defile
/// librement, independamment de la lecture.
class LectureScreen extends StatefulWidget {
  final AppState appState;
  final Flashcard card;
  final Tag tag;

  const LectureScreen({
    super.key,
    required this.appState,
    required this.card,
    required this.tag,
  });

  @override
  State<LectureScreen> createState() => _LectureScreenState();
}

class _LectureScreenState extends State<LectureScreen> {
  late final PlaybackController _controller;
  final ScrollController _scroll = ScrollController();

  /// Cles des segments, pour amener le segment courant a l'ecran.
  final Map<int, GlobalKey> _segmentKeys = {};

  /// Le defilement suit-il la lecture ?
  ///
  /// Repasse a `false` des le premier geste de l'utilisateur, et ne revient
  /// que s'il le redemande explicitement.
  bool _followReading = true;

  @override
  void initState() {
    super.initState();
    _controller = PlaybackController(speech: SpeechService.instance)
      ..addListener(_onPlaybackChanged);
    _controller.load(widget.card);
    // Ouvrir l'ecran depuis le haut-parleur veut dire « lis-moi ça ».
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlaybackChanged);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onPlaybackChanged() {
    if (mounted) setState(() {});
    if (_followReading) _scrollToCurrent();
  }

  void _scrollToCurrent() {
    final key = _segmentKeys[_controller.index];
    final context = key?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      alignment: 0.3,
    );
  }

  /// Un geste de l'utilisateur reprend la main sur le defilement.
  bool _onScrollNotification(ScrollNotification notification) {
    final manuel = notification is ScrollStartNotification &&
        notification.dragDetails != null;
    if (manuel && _followReading) {
      setState(() => _followReading = false);
    }
    return false;
  }

  Settings get _settings => widget.appState.settings;

  Future<void> _play() async {
    await _controller.play(settings: _settings);
    final outcome = _controller.lastOutcome;
    if (!mounted || outcome == null || outcome == SpeechOutcome.spoken) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(speechOutcomeMessage(outcome))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        elevation: 0,
        title: Text(
          widget.tag.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.paper,
                fontSize: 16,
              ),
        ),
        actions: [
          if (!_followReading)
            TextButton.icon(
              onPressed: () {
                setState(() => _followReading = true);
                _scrollToCurrent();
              },
              icon: const Icon(Icons.vertical_align_center, size: 16),
              label: const Text('Suivre'),
              style: TextButton.styleFrom(foregroundColor: AppColors.corail),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _controller.segments.length; i++)
                      _segment(i),
                  ],
                ),
              ),
            ),
          ),
          _controlBar(),
        ],
      ),
    );
  }

  Widget _segment(int i) {
    final key = _segmentKeys.putIfAbsent(i, GlobalKey.new);
    final actif = i == _controller.index;
    // Le premier segment est le recto : on lui laisse son poids visuel.
    final estRecto = i == 0;

    return Container(
      key: key,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: actif ? AppColors.corail.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: actif ? AppColors.corail : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Text(
        _controller.segments[i],
        style: TextStyle(
          color: actif ? AppColors.paper : AppColors.paperMuted,
          fontSize: estRecto ? 22 : 16,
          height: 1.5,
          fontWeight: estRecto ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _controlBar() {
    final c = _controller;
    final enCours = c.status == PlaybackStatus.playing;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.inkLight,
        border: Border(top: BorderSide(color: AppColors.paper.withValues(alpha: 0.08))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            c.segments.isEmpty
                ? 'Rien à lire'
                : 'Segment ${c.index + 1} sur ${c.segments.length}'
                    '${c.status == PlaybackStatus.paused ? ' — en pause' : ''}',
            style: TextStyle(color: AppColors.paperMuted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _control(
                icon: Icons.skip_previous,
                tooltip: 'Segment précédent',
                // Chaque commande est activee par la machine a etats, jamais
                // par ce que l'ecran croit savoir.
                onPressed: c.canPrevious ? () => c.previous(settings: _settings) : null,
              ),
              _control(
                icon: Icons.stop,
                tooltip: 'Arrêter',
                onPressed: c.canStop ? c.stop : null,
              ),
              _control(
                icon: enCours ? Icons.pause : Icons.play_arrow,
                tooltip: enCours ? 'Pause' : 'Lire',
                large: true,
                onPressed: enCours
                    ? (c.canPause ? c.pause : null)
                    : (c.canPlay ? _play : null),
              ),
              _control(
                icon: Icons.skip_next,
                tooltip: 'Segment suivant',
                onPressed: c.canNext ? () => c.next(settings: _settings) : null,
              ),
              _control(
                icon: Icons.replay,
                tooltip: 'Reprendre au début',
                onPressed: c.segments.isEmpty
                    ? null
                    : () async {
                        await c.stop();
                        await _play();
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _control({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool large = false,
  }) {
    final actif = onPressed != null;
    return IconButton(
      tooltip: tooltip,
      iconSize: large ? 38 : 26,
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: actif
            ? (large ? AppColors.corail : AppColors.paper)
            : AppColors.paperMuted.withValues(alpha: 0.3),
      ),
    );
  }
}
