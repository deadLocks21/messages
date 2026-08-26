import 'package:messages/core/domain/model/attachment.dart';

/// Port de lecture de la **configuration MMS de l'opérateur**.
///
/// Android résout cette configuration à partir de l'application de config
/// opérateur, de la SIM, ou de ses propres valeurs par défaut. C'est de là que
/// vient la taille maximale d'un MMS — une valeur qu'on lit plutôt que de la
/// coder en dur, puisqu'elle varie d'un opérateur à l'autre.
///
/// Attention à ce que cette limite signifie : c'est celle de **notre** réseau
/// pour l'émission. Celui du destinataire a la sienne, et transcodera le média
/// s'il est plus strict — sans que nous en soyons informés.
abstract interface class MmsConfiguration {
  Future<MmsLimits> limits();
}
