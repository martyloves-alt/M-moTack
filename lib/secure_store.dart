import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage des donnees sensibles, isole derriere une interface sur le
/// modele de ReminderScheduler : le Keystore Android n'est pas disponible
/// sous `flutter test`.
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Implementation reelle, adossee au Keystore Android via
/// EncryptedSharedPreferences.
class KeystoreSecureStore implements SecureStore {
  // Par defaut, la v11 chiffre deja en AES-GCM avec une cle protegee par le
  // Keystore : le fichier devient illisible hors de l'appareil.
  static const AndroidOptions _androidOptions = AndroidOptions(
    // Le defaut est `true`, ce qui EFFACE l'entree quand le dechiffrement
    // echoue. Pour des cartes, cela detruirait le carnet sans prevenir : on
    // prefere une lecture en echec, qui laisse le contenu chiffre en place
    // et donc recuperable.
    resetOnError: false,

    // Les sauvegardes Android sont desactivees dans le manifeste ; ne pas
    // reintroduire de copie par ce biais.
    migrateWithBackup: false,
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
  );

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      // Jamais la valeur dans le message : elle est precisement ce que
      // l'on protege.
      debugPrint('MémoTack: lecture sécurisée impossible pour $key');
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('MémoTack: écriture sécurisée impossible pour $key');
      rethrow;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('MémoTack: suppression sécurisée impossible pour $key');
    }
  }
}

/// Stockage en memoire, pour les tests.
class InMemorySecureStore implements SecureStore {
  final Map<String, String> values = {};

  /// Fait echouer les ecritures, pour verifier que la migration ne detruit
  /// pas la source quand la destination refuse.
  bool failWrites = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw Exception('écriture refusée');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}
