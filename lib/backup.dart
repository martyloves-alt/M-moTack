import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';

/// Identifiant de format, pour refuser tot un fichier qui n'en est pas un.
const String kBackupFormat = 'memotack-export';
const int kBackupVersion = 1;

/// Iterations PBKDF2. Volontairement enregistrees dans le fichier : ce
/// nombre pourra etre releve plus tard sans rendre illisibles les
/// sauvegardes deja produites.
const int kBackupIterations = 210000;

/// Longueur minimale du mot de passe. Le fichier peut etre attaque hors
/// ligne, autant de fois que voulu : un mot de passe court n'y resiste pas.
const int kMinPasswordLength = 8;

const int _saltLength = 16;
const int _nonceLength = 12; // taille standard pour AES-GCM

/// Echec d'export ou d'import, avec un message affichable tel quel.
///
/// Ne contient jamais de contenu de carte ni de mot de passe.
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

Future<SecretKey> _deriveKey(String password, List<int> salt, int iterations) {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  return pbkdf2.deriveKeyFromPassword(password: password, nonce: salt);
}

/// Arguments transferables vers un isolate.
class _BackupRequest {
  final String payload;
  final String password;
  const _BackupRequest(this.payload, this.password);
}

Future<String> _exportInIsolate(_BackupRequest r) =>
    exportCards(cards: _decodeCards(r.payload), password: r.password);

Future<String> _importInIsolate(_BackupRequest r) async =>
    jsonEncode((await importCards(archive: r.payload, password: r.password))
        .map((c) => c.toJson())
        .toList());

List<Flashcard> _decodeCards(String json) => (jsonDecode(json) as List<dynamic>)
    .map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
    .toList();

/// Comme [exportCards], mais hors du fil principal.
///
/// La derivation PBKDF2 dure plusieurs secondes : executee sur le fil de
/// l'interface, elle figerait l'application au point de faire croire a un
/// plantage — et pousserait a la fermer en pleine operation.
Future<String> exportCardsInBackground({
  required List<Flashcard> cards,
  required String password,
}) {
  final payload = jsonEncode(cards.map((c) => c.toJson()).toList());
  return compute(_exportInIsolate, _BackupRequest(payload, password));
}

/// Comme [importCards], mais hors du fil principal.
Future<List<Flashcard>> importCardsInBackground({
  required String archive,
  required String password,
}) async {
  final json = await compute(_importInIsolate, _BackupRequest(archive, password));
  return _decodeCards(json);
}

/// Chiffre les cartes en un document autonome, protege par [password].
///
/// Le resultat ne contient aucune metadonnee exploitable : ni nombre de
/// cartes, ni date, ni etiquettes en clair.
Future<String> exportCards({
  required List<Flashcard> cards,
  required String password,
}) async {
  if (password.length < kMinPasswordLength) {
    throw const BackupException(
      'Le mot de passe doit faire au moins $kMinPasswordLength caractères.',
    );
  }

  final salt = _randomBytes(_saltLength);
  final nonce = _randomBytes(_nonceLength);
  final key = await _deriveKey(password, salt, kBackupIterations);

  final payload = utf8.encode(
    jsonEncode(cards.map((c) => c.toJson()).toList()),
  );

  final box = await AesGcm.with256bits().encrypt(
    payload,
    secretKey: key,
    nonce: nonce,
  );

  return jsonEncode({
    'format': kBackupFormat,
    'version': kBackupVersion,
    'kdf': 'pbkdf2-hmac-sha256',
    'iterations': kBackupIterations,
    'salt': base64Encode(salt),
    'nonce': base64Encode(box.nonce),
    'ciphertext': base64Encode(box.cipherText),
    'mac': base64Encode(box.mac.bytes),
  });
}

/// Dechiffre un document produit par [exportCards].
///
/// Leve une [BackupException] si le fichier n'est pas reconnu, si le mot de
/// passe est faux, ou si le contenu a ete altere — AES-GCM authentifie le
/// chiffre, les trois cas sont donc detectes.
Future<List<Flashcard>> importCards({
  required String archive,
  required String password,
}) async {
  Map<String, dynamic> header;
  try {
    header = jsonDecode(archive) as Map<String, dynamic>;
  } catch (_) {
    throw const BackupException("Ce fichier n'est pas une sauvegarde MémoTack.");
  }

  if (header['format'] != kBackupFormat) {
    throw const BackupException("Ce fichier n'est pas une sauvegarde MémoTack.");
  }

  final version = header['version'];
  if (version is! int || version > kBackupVersion) {
    throw const BackupException(
      'Cette sauvegarde vient d\'une version plus récente de MémoTack.',
    );
  }

  final List<int> salt;
  final List<int> nonce;
  final List<int> ciphertext;
  final List<int> mac;
  final int iterations;
  try {
    salt = base64Decode(header['salt'] as String);
    nonce = base64Decode(header['nonce'] as String);
    ciphertext = base64Decode(header['ciphertext'] as String);
    mac = base64Decode(header['mac'] as String);
    iterations = header['iterations'] as int;
  } catch (_) {
    throw const BackupException('Sauvegarde illisible ou incomplète.');
  }

  final key = await _deriveKey(password, salt, iterations);

  List<int> clear;
  try {
    clear = await AesGcm.with256bits().decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
      secretKey: key,
    );
  } on SecretBoxAuthenticationError {
    // Mot de passe faux et fichier altere sont indistinguables, et c'est
    // voulu : le message ne doit pas aider a deviner lequel des deux.
    throw const BackupException(
      'Mot de passe incorrect, ou sauvegarde altérée.',
    );
  } catch (_) {
    throw const BackupException('Sauvegarde illisible ou incomplète.');
  }

  try {
    final list = jsonDecode(utf8.decode(clear)) as List<dynamic>;
    return list
        .map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    // Le dechiffrement a reussi mais le contenu ne ressemble pas a des
    // cartes : surtout ne rien afficher de ce contenu.
    throw const BackupException('Sauvegarde déchiffrée mais illisible.');
  }
}
