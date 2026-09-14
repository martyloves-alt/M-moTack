import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memotack/notifications.dart';
import 'package:memotack/screens/accueil_screen.dart';
import 'package:memotack/secure_store.dart';
import 'package:memotack/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_scheduler.dart';

/// Definition assez longue pour depasser la hauteur d'une feuille modale.
final String definitionLongue =
    List.generate(60, (i) => 'Phrase numéro $i de la définition.').join(' ');

Future<AppState> etatAvecCarte(String verso) async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState(
    notifications: NotificationService(scheduler: FakeScheduler()),
    secureStore: InMemorySecureStore(),
  );
  await state.addCard(
    card(
      id: 'a',
      front: 'Anasarque',
      back: verso,
      nextReviewAt: DateTime(2020, 1, 1),
    ),
  );
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Sans cela, GoogleFonts tenterait un telechargement pendant le test.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> ouvrirFiche(WidgetTester tester, AppState state) async {
    await tester.pumpWidget(MaterialApp(home: AccueilScreen(appState: state)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anasarque').first);
    await tester.pumpAndSettle();
  }

  group('fiche de révision', () {
    testWidgets('une définition longue ne déborde pas', (tester) async {
      // Avant correction, la feuille etait plafonnee a 9/16 de l'ecran sans
      // aucun scrollable : le Column debordait, ce que le test signale
      // lui-meme comme une erreur de rendu.
      final state = await etatAvecCarte(definitionLongue);
      await ouvrirFiche(tester, state);

      await tester.tap(find.text('Toucher pour voir la définition'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('les deux actions restent atteignables', (tester) async {
      final state = await etatAvecCarte(definitionLongue);
      await ouvrirFiche(tester, state);

      await tester.tap(find.text('Toucher pour voir la définition'));
      await tester.pumpAndSettle();

      // Le coeur du bug : les boutons etaient rognes avec le reste du
      // contenu, ce qui rendait la carte impossible a reviser.
      final bouton = find.text("Je m'en souviens");
      expect(bouton, findsOneWidget);

      final ecran = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(tester.getRect(bouton).bottom, lessThanOrEqualTo(ecran));

      // Preuve comportementale : le bouton repond vraiment.
      await tester.tap(bouton);
      await tester.pumpAndSettle();

      expect(state.cards.single.level, 1);
    });

    testWidgets('le contenu long est défilable', (tester) async {
      final state = await etatAvecCarte(definitionLongue);
      await ouvrirFiche(tester, state);

      await tester.tap(find.text('Toucher pour voir la définition'));
      await tester.pumpAndSettle();

      final zone = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(SingleChildScrollView),
      );
      expect(zone, findsOneWidget);

      final avant = tester.widget<SingleChildScrollView>(zone).controller?.offset;
      await tester.drag(zone, const Offset(0, -200));
      await tester.pumpAndSettle();

      // Le geste doit produire un defilement, pas un rebond immobile.
      final position = tester.state<ScrollableState>(
        find.descendant(of: zone, matching: find.byType(Scrollable)).first,
      ).position;
      expect(position.pixels, greaterThan(0));
      expect(avant, anyOf(isNull, 0.0));
    });

    testWidgets('une carte courte garde une feuille courte', (tester) async {
      // Flexible et non Expanded : sinon une carte d'un mot ouvrirait une
      // feuille occupant 85 % de l'ecran.
      final state = await etatAvecCarte('Œdème généralisé.');
      await ouvrirFiche(tester, state);

      final ecran = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final feuille = tester.getRect(find.byType(BottomSheet));

      expect(feuille.height, lessThan(ecran * 0.6));
    });
  });
}
