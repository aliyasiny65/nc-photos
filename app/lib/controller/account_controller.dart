import 'package:kiwi/kiwi.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/controller/account_pref_controller.dart';
import 'package:nc_photos/controller/collections_controller.dart';
import 'package:nc_photos/controller/persons_controller.dart';
import 'package:nc_photos/controller/places_controller.dart';
import 'package:nc_photos/controller/server_controller.dart';
import 'package:nc_photos/controller/session_controller.dart';
import 'package:nc_photos/controller/sharings_controller.dart';
import 'package:nc_photos/controller/sync_controller.dart';
import 'package:nc_photos/di_container.dart';

class AccountController {
  void setCurrentAccount(Account account) {
    _account = account;
    _collectionsController?.dispose();
    _collectionsController = null;
    _serverController?.dispose();
    _serverController = null;
    _accountPrefController?.dispose();
    _accountPrefController = null;
    _personsController?.dispose();
    _personsController = null;
    _syncController?.dispose();
    _syncController = null;
    _sessionController?.dispose();
    _sessionController = null;
    _sharingsController?.dispose();
    _sharingsController = null;
    _placesController?.dispose();
    _placesController = null;
  }

  Account get account => _account!;

  CollectionsController get collectionsController =>
      _collectionsController ??= CollectionsController(
        KiwiContainer().resolve<DiContainer>(),
        account: _account!,
        serverController: serverController,
      );

  ServerController get serverController =>
      _serverController ??= ServerController(
        account: _account!,
      );

  AccountPrefController get accountPrefController =>
      _accountPrefController ??= AccountPrefController(
        account: _account!,
      );

  PersonsController get personsController =>
      _personsController ??= PersonsController(
        KiwiContainer().resolve<DiContainer>(),
        account: _account!,
        accountPrefController: accountPrefController,
      );

  SyncController get syncController => _syncController ??= SyncController(
        account: _account!,
      );

  SessionController get sessionController =>
      _sessionController ??= SessionController();

  SharingsController get sharingsController =>
      _sharingsController ??= SharingsController(
        KiwiContainer().resolve(),
        account: _account!,
      );

  PlacesController get placesController =>
      _placesController ??= PlacesController(
        KiwiContainer().resolve<DiContainer>(),
        account: _account!,
      );

  Account? _account;
  CollectionsController? _collectionsController;
  ServerController? _serverController;
  AccountPrefController? _accountPrefController;
  PersonsController? _personsController;
  SyncController? _syncController;
  SessionController? _sessionController;
  SharingsController? _sharingsController;
  PlacesController? _placesController;
}
