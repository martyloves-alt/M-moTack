import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memotack/notifications.dart';
import 'package:memotack/secure_store.dart';
import 'package:memotack/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_scheduler.dart';

const String _kCardsKey = 'memotack_cards';

void main() {
  // AppState ecrit dans SharedPreferences : sans valeurs simulees, l'appel
  // au canal de plateforme echouerait sous `flutter test`.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeScheduler fake;
  late InMemorySecureStore secure;
  late AppState state;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeScheduler();
    secure = InMemorySecureStore();
    state = AppState(
      notifications: NotificationService(scheduler: fake),
      secureStore: secure,
    );
  });

  group('updateCard', () {
    test('une modification preserve la progression Leitner', () async {
      final echeance = DateTime(2026, 6, 1, 10, 0);
      final original = card(
        id: 'a',
        front: 'Anasarque',
        back: 'Oedeme generalise',
        nextReviewAt: echeance,
        level: 3,
      );
      await state.addCard(original);

      // L'utilisateur corrige le recto, le verso et l'etiquette.
      await state.updateCard(
        original.copyWith(
          front: 'Anasarque (corrige)',
          back: 'Oedeme generalise du tissu sous-cutane',
          tagId: 'perso',
        ),
      );

      final updated = state.cards.single;
      expect(updated.front, 'Anasarque (corrige)');
      expect(updated.back, 'Oedeme generalise du tissu sous-cutane');
      expect(updated.tagId, 'perso');

      // Le coeur du test : corriger une faute ne reinitialise pas la
      // progression durement acquise.
      expect(updated.level, 3);
      expect(updated.nextReviewAt, echeance);
      expect(updated.createdAt, original.createdAt);
      expect(updated.id, 'a');
    });

    test('ne touche pas aux autres cartes', () async {
      await state.addCard(card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2026, 6, 1), level: 2));
      await state.addCard(card(id: 'b', front: 'Dyspnee', nextReviewAt: DateTime(2026, 6, 2), level: 4));

      await state.updateCard(state.cards.first.copyWith(front: 'Modifie'));

      final autre = state.cards.firstWhere((c) => c.id == 'b');
      expect(autre.front, 'Dyspnee');
      expect(autre.level, 4);
    });

    test('replanifie les rappels apres modification', () async {
      await state.addCard(card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2020, 1, 1)));
      fake.calls.clear();

      await state.updateCard(state.cards.single.copyWith(front: 'Nouveau recto'));

      expect(fake.calls, contains('cancel'));
      expect(fake.pendingBodies, contains('Nouveau recto'));
      expect(fake.pendingBodies, isNot(contains('Anasarque')));
    });
  });

  group('deleteCard', () {
    test('retire la carte et ses notifications en attente', () async {
      // Echeances passees : les deux cartes sont dues, donc reellement
      // programmees.
      await state.addCard(card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2020, 1, 1)));
      await state.addCard(card(id: 'b', front: 'Dyspnee', nextReviewAt: DateTime(2020, 1, 2)));

      expect(fake.pendingBodies, containsAll(['Anasarque', 'Dyspnee']));

      await state.deleteCard('a');

      // La carte a disparu du stockage...
      expect(state.cards.map((c) => c.id), ['b']);
      // ...et plus aucun rappel ne porte son recto : sinon une notification
      // arriverait pour une carte qui n'existe plus.
      expect(fake.pendingBodies, isNot(contains('Anasarque')));
      expect(fake.pendingBodies, contains('Dyspnee'));
    });

    test('supprimer la derniere carte ne laisse aucun rappel', () async {
      await state.addCard(card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2020, 1, 1)));
      expect(fake.scheduled, isNotEmpty);

      await state.deleteCard('a');

      expect(state.cards, isEmpty);
      expect(fake.scheduled, isEmpty);
    });

    test('un identifiant inconnu ne supprime rien', () async {
      await state.addCard(card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2020, 1, 1)));

      await state.deleteCard('inexistant');

      expect(state.cards.map((c) => c.id), ['a']);
    });

    test('la suppression est persistee', () async {
      await state.addCard(card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2020, 1, 1)));
      await state.addCard(card(id: 'b', front: 'Dyspnee', nextReviewAt: DateTime(2020, 1, 2)));
      await state.deleteCard('a');

      // Un nouvel AppState relit le meme stockage : la carte ne doit pas
      // reapparaitre au prochain lancement.
      final rechargee = AppState(
        notifications: NotificationService(scheduler: FakeScheduler()),
        secureStore: secure,
      );
      await rechargee.load();

      expect(rechargee.cards.map((c) => c.id), ['b']);
    });
  });

  group('stockage sécurisé', () {
    test('les cartes sont ecrites dans le stockage securise, pas dans les preferences', () async {
      await state.addCard(card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2020, 1, 1)));

      expect(secure.values[_kCardsKey], contains('Anasarque'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_kCardsKey), isNull);
    });

    test('des donnees illisibles ne font pas echouer le demarrage', () async {
      secure.values[_kCardsKey] = 'ceci n est pas du JSON';

      await state.load();

      expect(state.cards, isEmpty);
      expect(state.isLoaded, isTrue);
    });
  });

  group('migration silencieuse', () {
    /// Cartes telles qu'une version anterieure les laissait en clair.
    void semerDonneesAnciennes() {
      SharedPreferences.setMockInitialValues({
        _kCardsKey: jsonEncode([
          card(id: 'a', front: 'Anasarque', nextReviewAt: DateTime(2026, 6, 1), level: 3).toJson(),
        ]),
      });
    }

    test('les cartes existantes sont reprises sans perte', () async {
      semerDonneesAnciennes();

      await state.load();

      expect(state.cards, hasLength(1));
      expect(state.cards.single.front, 'Anasarque');
      // La progression traverse la migration.
      expect(state.cards.single.level, 3);
      expect(state.migratedFromPlainStorage, isTrue);
    });

    test('la copie en clair est effacee une fois la copie chiffree ecrite', () async {
      semerDonneesAnciennes();

      await state.load();

      expect(secure.values[_kCardsKey], contains('Anasarque'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_kCardsKey), isNull);
    });

    test('si le stockage securise refuse, les donnees restent en place', () async {
      // Le pire cas : ne surtout pas detruire la seule copie existante.
      semerDonneesAnciennes();
      secure.failWrites = true;

      await state.load();

      expect(state.cards, hasLength(1));
      expect(state.migratedFromPlainStorage, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_kCardsKey), isNotNull);
    });

    test('ne migre qu une fois', () async {
      semerDonneesAnciennes();
      await state.load();

      final rechargee = AppState(
        notifications: NotificationService(scheduler: FakeScheduler()),
        secureStore: secure,
      );
      await rechargee.load();

      expect(rechargee.cards, hasLength(1));
      expect(rechargee.migratedFromPlainStorage, isFalse);
    });

    test('une copie en clair residuelle est effacee au demarrage suivant', () async {
      // Cas d'une version anterieure qui aurait laisse les deux copies.
      secure.values[_kCardsKey] = jsonEncode([
        card(id: 'securisee', front: 'Depuis le Keystore', nextReviewAt: DateTime(2026, 6, 1)).toJson(),
      ]);
      SharedPreferences.setMockInitialValues({
        _kCardsKey: jsonEncode([
          card(id: 'claire', front: 'En clair', nextReviewAt: DateTime(2026, 6, 1)).toJson(),
        ]),
      });

      await state.load();

      // La version securisee fait foi...
      expect(state.cards.single.id, 'securisee');
      // ...et la copie en clair ne survit pas.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_kCardsKey), isNull);
    });
  });

  group('replaceCards', () {
    test('remplace tout le carnet et replanifie', () async {
      await state.addCard(card(id: 'a', front: 'Ancienne', nextReviewAt: DateTime(2020, 1, 1)));

      await state.replaceCards([
        card(id: 'x', front: 'Importee', nextReviewAt: DateTime(2020, 1, 1)),
      ]);

      expect(state.cards.map((c) => c.id), ['x']);
      expect(fake.pendingBodies, contains('Importee'));
      expect(fake.pendingBodies, isNot(contains('Ancienne')));
    });
  });
}
