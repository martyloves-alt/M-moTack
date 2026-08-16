import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memotack/backup.dart';

import 'fake_scheduler.dart';

void main() {
  final cartes = [
    card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2026, 6, 1), level: 3,
        back: 'Œdème généralisé'),
    card(id: 'b', front: 'Dyspnée', nextReviewAt: DateTime(2026, 6, 2), level: 1),
  ];

  const motDePasse = 'un-mot-de-passe-solide';

  group('aller-retour', () {
    test('les cartes reviennent identiques', () async {
      final archive = await exportCards(cards: cartes, password: motDePasse);
      final relues = await importCards(archive: archive, password: motDePasse);

      expect(relues, hasLength(2));
      expect(relues[0].id, 'a');
      expect(relues[0].front, 'Anasarque');
      expect(relues[0].back, 'Œdème généralisé');
      // La progression doit traverser le changement de telephone.
      expect(relues[0].level, 3);
      expect(relues[0].nextReviewAt, cartes[0].nextReviewAt);
      expect(relues[1].front, 'Dyspnée');
    });

    test('un carnet vide s exporte et se relit', () async {
      final archive = await exportCards(cards: const [], password: motDePasse);

      expect(await importCards(archive: archive, password: motDePasse), isEmpty);
    });

    test('deux exports du meme contenu different', () async {
      // Sel et nonce aleatoires : deux sauvegardes identiques ne doivent pas
      // produire le meme chiffre, sinon on apprend qu'elles sont identiques.
      final a = await exportCards(cards: cartes, password: motDePasse);
      final b = await exportCards(cards: cartes, password: motDePasse);

      expect(a, isNot(b));
    });
  });

  group('hors du fil principal', () {
    test('l aller-retour fonctionne aussi via un isolate', () async {
      // Chemin reellement emprunte par l'interface : la derivation PBKDF2
      // dure plusieurs secondes et ne doit pas figer l'application.
      final archive = await exportCardsInBackground(cards: cartes, password: motDePasse);
      final relues = await importCardsInBackground(archive: archive, password: motDePasse);

      expect(relues, hasLength(2));
      expect(relues[0].front, 'Anasarque');
      expect(relues[0].level, 3);
    });

    test('un mot de passe faux est aussi rejete via un isolate', () async {
      final archive = await exportCardsInBackground(cards: cartes, password: motDePasse);

      await expectLater(
        importCardsInBackground(archive: archive, password: 'mauvais-mot-de-passe'),
        throwsA(isA<BackupException>()),
      );
    });
  });

  group('confidentialite du fichier', () {
    test('aucun contenu de carte n apparait en clair', () async {
      final archive = await exportCards(cards: cartes, password: motDePasse);

      expect(archive, isNot(contains('Anasarque')));
      expect(archive, isNot(contains('Dyspnée')));
      expect(archive, isNot(contains('Œdème')));
      expect(archive, isNot(contains(motDePasse)));
    });

    test('aucune metadonnee exploitable', () async {
      final archive = await exportCards(cards: cartes, password: motDePasse);
      final entete = jsonDecode(archive) as Map<String, dynamic>;

      // Ni nombre de cartes, ni date : la taille du chiffre en dit deja
      // assez, inutile d'en ajouter.
      expect(entete.keys, isNot(contains('cardCount')));
      expect(entete.keys, isNot(contains('date')));
      expect(entete['format'], kBackupFormat);
    });
  });

  group('refus', () {
    test('un mot de passe faux est rejete sans reveler le contenu', () async {
      final archive = await exportCards(cards: cartes, password: motDePasse);

      await expectLater(
        importCards(archive: archive, password: 'mauvais-mot-de-passe'),
        throwsA(isA<BackupException>()),
      );
    });

    test('une sauvegarde alteree est rejetee', () async {
      final archive = await exportCards(cards: cartes, password: motDePasse);
      final entete = jsonDecode(archive) as Map<String, dynamic>;

      // On retourne un octet du chiffre : AES-GCM authentifie, donc la
      // modification doit etre detectee.
      final chiffre = base64Decode(entete['ciphertext'] as String);
      chiffre[0] = chiffre[0] ^ 0xFF;
      entete['ciphertext'] = base64Encode(chiffre);

      await expectLater(
        importCards(archive: jsonEncode(entete), password: motDePasse),
        throwsA(isA<BackupException>()),
      );
    });

    test('mot de passe faux et fichier altere donnent le meme message', () async {
      // Le message ne doit pas aider a deviner lequel des deux est en cause.
      final archive = await exportCards(cards: cartes, password: motDePasse);
      final entete = jsonDecode(archive) as Map<String, dynamic>;
      final chiffre = base64Decode(entete['ciphertext'] as String);
      chiffre[0] = chiffre[0] ^ 0xFF;
      entete['ciphertext'] = base64Encode(chiffre);

      String? messageMauvaisMotDePasse;
      String? messageAltere;
      try {
        await importCards(archive: archive, password: 'autre-mot-de-passe');
      } on BackupException catch (e) {
        messageMauvaisMotDePasse = e.message;
      }
      try {
        await importCards(archive: jsonEncode(entete), password: motDePasse);
      } on BackupException catch (e) {
        messageAltere = e.message;
      }

      expect(messageMauvaisMotDePasse, isNotNull);
      expect(messageAltere, messageMauvaisMotDePasse);
    });

    test('un fichier quelconque est refuse clairement', () async {
      await expectLater(
        importCards(archive: 'bonjour', password: motDePasse),
        throwsA(isA<BackupException>()),
      );
    });

    test('un format inconnu est refuse', () async {
      await expectLater(
        importCards(archive: '{"format":"autre-chose"}', password: motDePasse),
        throwsA(isA<BackupException>()),
      );
    });

    test('une version plus recente est refusee', () async {
      final archive = await exportCards(cards: cartes, password: motDePasse);
      final entete = jsonDecode(archive) as Map<String, dynamic>;
      entete['version'] = kBackupVersion + 1;

      await expectLater(
        importCards(archive: jsonEncode(entete), password: motDePasse),
        throwsA(isA<BackupException>()),
      );
    });

    test('un mot de passe trop court est refuse a l export', () async {
      await expectLater(
        exportCards(cards: cartes, password: 'court'),
        throwsA(isA<BackupException>()),
      );
    });
  });
}
