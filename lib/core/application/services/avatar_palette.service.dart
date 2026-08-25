/// Attribue à chaque interlocuteur une pastille de couleur stable, comme
/// Google Messages : la couleur ne dépend que de l'identité (nom du contact ou
/// adresse), jamais de la position dans la liste.
///
/// Le service ne connaît pas les couleurs — il rend un **index de créneau**,
/// que le thème traduit en `Color`. La couche application reste sans Flutter.
abstract final class AvatarPaletteService {
  /// Nombre de créneaux de la palette. Doit rester aligné avec
  /// `GmPalette.avatarSlots`.
  static const slotCount = 8;

  /// Index déterministe pour [seed]. Insensible à la casse et aux espaces, pour
  /// qu'un contact renommé « alice » / « Alice » garde sa couleur.
  static int slotFor(String seed) {
    final normalized = seed.trim().toLowerCase();
    if (normalized.isEmpty) return 0;
    // FNV-1a 32 bits : court, stable d'une exécution à l'autre (contrairement
    // à `String.hashCode`, dont Dart ne garantit pas la stabilité).
    var hash = 0x811c9dc5;
    for (final unit in normalized.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash % slotCount;
  }
}
