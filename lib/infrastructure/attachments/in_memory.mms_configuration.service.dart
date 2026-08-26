import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/mms_configuration.service.dart';

/// Configuration MMS simulée.
///
/// [limits] est modifiable pour que les tests rejouent le cas d'un opérateur
/// généreux comme celui d'un opérateur avare — c'est toute la raison d'être de
/// cette lecture.
class InMemoryMmsConfiguration implements MmsConfiguration {
  MmsLimits value;

  /// Nombre de lectures, pour vérifier la mise en cache côté appelant.
  int readCount = 0;

  InMemoryMmsConfiguration({MmsLimits? value})
    : value = value ?? MmsLimits.fallback;

  @override
  Future<MmsLimits> limits() async {
    readCount++;
    return value;
  }
}
