import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const _kCardsKey = 'memotack_cards';
const _kTagsKey = 'memotack_tags';
const _kSettingsKey = 'memotack_settings';

/// Étiquettes par défaut, reprises du prototype.
List<Tag> defaultTags() => const [
      Tag(id: 'medical', name: 'Médical', color: TagColor.corail),
      Tag(id: 'reseaux', name: 'Réseaux sociaux', color: TagColor.ambre),
      Tag(id: 'perso', name: 'Perso', color: TagColor.sauge),
    ];

/// Garde en mémoire les cartes, étiquettes et réglages de l'appli,
/// et les sauvegarde sur le téléphone à chaque changement.
class AppState extends ChangeNotifier {
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
  }

  Future<void> updateCard(Flashcard updated) async {
    cards = cards.map((c) => c.id == updated.id ? updated : c).toList();
    notifyListeners();
    await _saveCards();
  }

  Future<void> updateSettings(Settings updated) async {
    settings = updated;
    notifyListeners();
    await _saveSettings();
  }
}
