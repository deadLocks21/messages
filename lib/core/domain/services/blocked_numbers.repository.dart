import 'package:messages/core/domain/model/address.dart';

/// Port des numéros bloqués.
///
/// La liste n'est pas à l'app : c'est celle du **système**
/// (`BlockedNumberContract`), partagée avec le composeur d'appel. C'est ce qui
/// permet de tenir la promesse du dialogue — « vous ne recevrez plus ni appels
/// ni messages de ce numéro » — plutôt que la moitié qui nous regarde. Y
/// écrire est réservé à l'app SMS par défaut et au composeur par défaut.
///
/// Bloquer ne supprime rien : le fil existant **reste**, dans « Spam et
/// bloqués » plutôt que dans la liste principale. C'est ce qu'annonce le
/// dialogue, et c'est tout ce qu'il annonce — les messages *suivants*, eux,
/// n'arrivent pas : depuis Android 7 la plateforme filtre elle-même les SMS
/// des numéros bloqués et ne diffuse pas `SMS_DELIVER`. Vérifié sur
/// l'émulateur : le message d'un numéro bloqué n'entre pas dans le stock.
abstract interface class BlockedNumbersRepository {
  Future<List<Address>> listAll();

  Future<void> block(Address address);

  Future<void> unblock(Address address);
}
