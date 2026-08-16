import 'package:flutter/foundation.dart';

const String kRedactedMarker = '[contenu masqué]';

/// Retire de [message] toute occurrence des valeurs [sensitive].
///
/// Les exceptions des canaux de plateforme reprennent parfois les arguments
/// qu'on leur a transmis : le message d'erreur de `zonedSchedule()` ou de
/// `speak()` peut donc contenir le recto d'une carte. Comme on ne maitrise
/// pas la forme de ces messages, on retire explicitement les valeurs qu'on
/// vient de leur passer, plutot que d'esperer qu'elles n'y figurent pas.
String redactSecrets(String message, Iterable<String> sensitive) {
  var safe = message;
  for (final value in sensitive) {
    final trimmed = value.trim();
    // En dessous de trois caracteres, le remplacement ferait plus de degats
    // que de bien : il masquerait des fragments de mots anodins.
    if (trimmed.length < 3) continue;
    safe = safe.replaceAll(trimmed, kRedactedMarker);
  }
  return safe;
}

/// Journalise en retirant d'abord les valeurs sensibles.
///
/// A utiliser partout ou le message peut deriver d'un appel ayant recu du
/// contenu de carte.
void debugPrintSafe(String message, {Iterable<String> sensitive = const []}) {
  debugPrint(redactSecrets(message, sensitive));
}
