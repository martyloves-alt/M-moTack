import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'notifications.dart';
import 'secure_store.dart';

/// Cle des cartes. Le contenu des cartes est la seule donnee reellement
/// personnelle de l'application : il vit dans le stockage securise, adosse
/// au Keystore. Les etiquettes et les reglages restent dans
/// SharedPreferences, ce sont des preferences d'affichage.
const _kCardsKey = 'memotack_cards';
const _kTagsKey = 'memotack_tags';
const _kSettingsKey = 'memotack_settings';

List<Tag> defaultTags() => const [
      Tag(id: 'medical', name: 'Médical', color: TagColor.corail),
      Tag(id: 'reseaux', name: 'Réseaux sociaux', color: TagColor.ambre),
      Tag(id: 'perso', name: 'Perso', color: TagColor.sauge),
    ];

class AppState extends ChangeNotifier {
  /// [notifications] et [secureStore] ne sont injectes que par les tests :
  /// ni la couche Android ni le Keystore ne sont disponibles sous
  /// `flutter test`.
  AppState({NotificationService? notifications, SecureStore? secureStore})
      : _notifications = notifications ?? NotificationService.instance,
        _secureStore = secureStore ?? KeystoreSecureStore();

  final NotificationService _notifications;
  final SecureStore _secureStore;

  /// Vrai si des cartes ont ete deplacees depuis SharedPreferences au
  /// dernier [load]. Sert aux tests ; l'utilisateur ne voit rien.
  bool migratedFromPlainStorage = false;

  List<Flashcard> cards = [];
  List<Tag> tags = defaultTags();
  Settings settings = Settings.defaults;
  bool isLoaded = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    cards = await _loadCards(prefs);

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

  /// Lit les cartes depuis le stockage securise, en migrant au passage
  /// celles laissees par une version anterieure dans SharedPreferences.
  Future<List<Flashcard>> _loadCards(SharedPreferences prefs) async {
    final secure = await _secureStore.read(_kCardsKey);
    if (secure != null) {
      // Une version anterieure a pu laisser une copie en clair derriere
      // elle ; on s'en debarrasse des qu'on la croise.
      await prefs.remove(_kCardsKey);
      return _decodeCards(secure);
    }

    final legacy = prefs.getString(_kCardsKey);
    if (legacy == null) return [];

    final migrated = _decodeCards(legacy);

    // La copie en clair n'est effacee qu'une fois la copie chiffree
    // ecrite : si le Keystore refuse, mieux vaut des donnees en clair que
    // pas de donnees du tout.
    try {
      await _secureStore.write(_kCardsKey, legacy);
      await prefs.remove(_kCardsKey);
      migratedFromPlainStorage = true;
    } catch (_) {
      debugPrint('MémoTack: migration vers le stockage sécurisé impossible, '
          'les cartes restent en place.');
    }

    return migrated;
  }

  List<Flashcard> _decodeCards(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Surtout ne pas journaliser `raw` : c'est le contenu des cartes.
      debugPrint('MémoTack: cartes illisibles, elles sont ignorées.');
      return [];
    }
  }

  Future<void> _saveCards() async {
    await _secureStore.write(
      _kCardsKey,
      jsonEncode(cards.map((c) => c.toJson()).toList()),
    );
  }

  /// Remplace toutes les cartes, par exemple apres un import.
  Future<void> replaceCards(List<Flashcard> replacement) async {
    cards = List<Flashcard>.of(replacement);
    notifyListeners();
    await _saveCards();
    await _notifications.rescheduleAll(cards: cards, settings: settings);
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
