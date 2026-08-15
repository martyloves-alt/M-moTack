import 'package:flutter_test/flutter_test.dart';
import 'package:memotack/notifications.dart';
import 'package:memotack/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_scheduler.dart';

void main() {
  // AppState ecrit dans SharedPreferences : sans valeurs simulees, l'appel
  // au canal de plateforme echouerait sous `flutter test`.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeScheduler fake;
  late AppState state;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeScheduler();
    state = AppState(notifications: NotificationService(scheduler: fake));
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

      // Un nouvel AppState relit SharedPreferences : la carte ne doit pas
      // reapparaitre au prochain lancement.
      final rechargee = AppState(notifications: NotificationService(scheduler: FakeScheduler()));
      await rechargee.load();

      expect(rechargee.cards.map((c) => c.id), ['b']);
    });
  });
}
