import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'notifications.dart';

const _kCardsKey = 'memotack_cards';
const _kTagsKey = 'memotack_tags';
const _kSettingsKey = 'memotack_settings';

List<Tag> defaultTags() => const [
      Tag(id: 'medical', name: 'Médical', color: TagColor.corail),
      Tag(id: 'reseaux', name: 'Réseaux sociaux', color: TagColor.ambre),
      Tag(id: 'perso', name: 'Perso', color: TagColor.sauge),
    ];

class AppState extends ChangeNotifier {
  /// [notifications] n'est injecte que par les tests : la couche Android
  /// n'est pas disponible sous `flutter test`.
  AppState({NotificationService? notifications})
      : _notifications = notifications ?? NotificationService.instance;

  final NotificationService _notifications;

  List<Flashcard> cards = [];
  List<Tag> tags = defaultTags();
  Settings settings = Settings.defaults;
  bool isLoaded = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final cardsJson = prefs.getString(_kCardsKey);
    if (cardsJson != null) {
      final list = jsonDecode(cardsJson) as List<dynamic>;
      cards = list
          .map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final tagsJson = prefs.getString(_kTagsKey);
    if (tagsJson != null) {
      final list = jsonDecode(tagsJson) as List<dynamic>;
      tags = list.map((e) => Tag.fromJson(e as Map<String, dynamic>)).toList();
    }

    final settingsJson = prefs.getString(_kSettingsKey);
    if (settingsJson != null) {
      settings = Settings.fromJson(
        jsonDecode(settingsJson) as Map<String, dynamic>,
      );
    }

    isLoaded = true;
    notifyListeners();
    await _notifications.rescheduleAll(cards: cards, settings: settings);
  }

  Future<void> _saveCards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kCardsKey,
      jsonEncode(cards.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettingsKey, jsonEncode(settings.toJson()));
  }

  Future<void> addCard(Flashcard card) async {
    cards = [...cards, card];
    notifyListeners();
    await _saveCards();
    await _notifications.rescheduleAll(cards: cards, settings: settings);
  }

  Future<void> updateCard(Flashcard updated) async {
    cards = cards.map((c) => c.id == updated.id ? updated : c).toList();
    notifyListeners();
    await _saveCards();
    await _notifications.rescheduleAll(cards: cards, settings: settings);
  }

  /// Supprime une carte et reprogramme les rappels.
  ///
  /// La replanification n'est pas optionnelle : les rappels deja poses
  /// portent le recto de la carte. Sans elle, une notification arriverait
  /// pour une carte qui n'existe plus.
  Future<void> deleteCard(String id) async {
    cards = cards.where((c) => c.id != id).toList();
    notifyListeners();
    await _saveCards();
    await _notifications.rescheduleAll(cards: cards, settings: settings);
  }

  Future<void> updateSettings(Settings updated) async {
    settings = updated;
    notifyListeners();
    await _saveSettings();
    await _notifications.rescheduleAll(cards: cards, settings: settings);
  }
}
