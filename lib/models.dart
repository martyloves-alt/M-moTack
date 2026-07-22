/// Couleurs disponibles pour les étiquettes.
/// Correspond exactement à la palette déjà validée dans l'aperçu visuel.
enum TagColor { corail, ambre, sauge, bleuEncre }

TagColor tagColorFromString(String value) {
  switch (value) {
    case 'corail':
      return TagColor.corail;
    case 'ambre':
      return TagColor.ambre;
    case 'sauge':
      return TagColor.sauge;
    case 'bleuEncre':
      return TagColor.bleuEncre;
    default:
      throw ArgumentError('Couleur d\'étiquette inconnue : $value');
  }
}

String tagColorToString(TagColor color) {
  switch (color) {
    case TagColor.corail:
      return 'corail';
    case TagColor.ambre:
      return 'ambre';
    case TagColor.sauge:
      return 'sauge';
    case TagColor.bleuEncre:
      return 'bleuEncre';
  }
}

class Tag {
  final String id;
  final String name;
  final TagColor color;

  const Tag({required this.id, required this.name, required this.color});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': tagColorToString(color),
      };

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
        id: json['id'] as String,
        name: json['name'] as String,
        color: tagColorFromString(json['color'] as String),
      );
}

/// Nombre de niveaux dans la progression de révision.
/// Niveau 0 = tout juste ajoutée, niveau 5 = bien mémorisée.
const int kMaxLevel = 5;

/// Intervalles en heures pour chaque niveau (0 à 5).
/// Repris tel quel du prototype : 1h, 4h, 12h, 1j, 3j, 7j.
const List<int> kLevelIntervalsHours = [1, 4, 12, 24, 72, 168];

class Flashcard {
  final String id;
  final String front; // mot ou phrase (150 caractères max, contrôlé côté écran)
  final String back; // définition/note, optionnelle (chaîne vide si absente)
  final String tagId;
  final int level; // 0 à kMaxLevel
  final DateTime nextReviewAt;
  final DateTime createdAt;

  const Flashcard({
    required this.id,
    required this.front,
    required this.back,
    required this.tagId,
    required this.level,
    required this.nextReviewAt,
    required this.createdAt,
  });

  Flashcard copyWith({
    String? front,
    String? back,
    String? tagId,
    int? level,
    DateTime? nextReviewAt,
  }) {
    return Flashcard(
      id: id,
      front: front ?? this.front,
      back: back ?? this.back,
      tagId: tagId ?? this.tagId,
      level: level ?? this.level,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'front': front,
        'back': back,
        'tagId': tagId,
        'level': level,
        'nextReviewAt': nextReviewAt.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        id: json['id'] as String,
        front: json['front'] as String,
        back: json['back'] as String? ?? '',
        tagId: json['tagId'] as String,
        level: json['level'] as int,
        nextReviewAt:
            DateTime.fromMillisecondsSinceEpoch(json['nextReviewAt'] as int),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      );
}

enum AppTheme { light, dark }

class Settings {
  final int remindersPerDay; // 1 à 10
  final String activeHoursStart; // "HH:mm"
  final String activeHoursEnd; // "HH:mm"
  final AppTheme theme;

  const Settings({
    required this.remindersPerDay,
    required this.activeHoursStart,
    required this.activeHoursEnd,
    required this.theme,
  });

  static const Settings defaults = Settings(
    remindersPerDay: 4,
    activeHoursStart: '08:00',
    activeHoursEnd: '23:00',
    theme: AppTheme.dark,
  );

  Settings copyWith({
    int? remindersPerDay,
    String? activeHoursStart,
    String? activeHoursEnd,
    AppTheme? theme,
  }) {
    return Settings(
      remindersPerDay: remindersPerDay ?? this.remindersPerDay,
      activeHoursStart: activeHoursStart ?? this.activeHoursStart,
      activeHoursEnd: activeHoursEnd ?? this.activeHoursEnd,
      theme: theme ?? this.theme,
    );
  }

  Map<String, dynamic> toJson() => {
        'remindersPerDay': remindersPerDay,
        'activeHoursStart': activeHoursStart,
        'activeHoursEnd': activeHoursEnd,
        'theme': theme == AppTheme.dark ? 'dark' : 'light',
      };

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
        remindersPerDay: json['remindersPerDay'] as int,
        activeHoursStart: json['activeHoursStart'] as String,
        activeHoursEnd: json['activeHoursEnd'] as String,
        theme: (json['theme'] as String) == 'dark'
            ? AppTheme.dark
            : AppTheme.light,
      );
}

/// Un créneau de rappel prévu pour aujourd'hui : une heure, et la carte
/// (si une carte est due) à montrer à ce moment-là.
class ScheduledReminder {
  final DateTime time;
  final String? flashcardId; // null = rien à réviser à ce créneau

  const ScheduledReminder({required this.time, this.flashcardId});
}
