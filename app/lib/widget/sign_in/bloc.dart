part of '../sign_in.dart';

@npLog
class _Bloc extends Bloc<_Event, _State> with BlocLogger {
  _Bloc({
    required this.npDb,
    required this.prefController,
  }) : super(_State.init()) {
    on<_SetScheme>(_onSetScheme);
    on<_SetServerUrl>(_onSetServerUrl);
    on<_Connect>(_onConnect);
    on<_SetConnectedAccount>(_onSetConnectedAccount);

    on<_SetError>(_onSetError);
  }

  @override
  String get tag => _log.fullName;

  @override
  void onError(Object error, StackTrace stackTrace) {
    // we need this to prevent onError being triggered recursively
    if (!isClosed && !_isHandlingError) {
      _isHandlingError = true;
      try {
        add(_SetError(error, stackTrace));
      } catch (_) {}
      _isHandlingError = false;
    }
    super.onError(error, stackTrace);
  }

  void _onSetScheme(_SetScheme ev, _Emitter emit) {
    _log.info(ev);
    emit(state.copyWith(scheme: ev.value));
  }

  void _onSetServerUrl(_SetServerUrl ev, _Emitter emit) {
    _log.info(ev);
    emit(state.copyWith(serverUrl: ev.value));
  }

  void _onConnect(_Connect ev, _Emitter emit) {
    _log.info(ev);
    final scheme = state.scheme.toValueString();
    final serverUrl = state.serverUrl.trim().trimRightAny("/");
    final uri = Uri.parse("$scheme://$serverUrl");
    _log.info("[_onConnect] Try connecting with url: $uri");
    emit(state.copyWith(connectUri: Unique(uri)));
  }

  Future<void> _onSetConnectedAccount(
      _SetConnectedAccount ev, _Emitter emit) async {
    _log.info(ev);
    emit(state.copyWith(isConnecting: true));
    try {
      await _persistAccount(ev.value);
      emit(state.copyWith(
        isCompleted: true,
        connectedAccount: ev.value,
      ));
    } catch (_) {
      emit(state.copyWith(isConnecting: false));
      rethrow;
    }
  }

  void _onSetError(_SetError ev, Emitter<_State> emit) {
    _log.info(ev);
    emit(state.copyWith(error: ExceptionEvent(ev.error, ev.stackTrace)));
  }

  Future<void> _persistAccount(Account account) async {
    await npDb.addAccounts([account.toDb()]);
    // only signing in with app password would trigger distinct
    final accounts = prefController.accountsValue.added(account).distinct();
    try {
      AccountPref.setGlobalInstance(
        account,
        await pref_util.loadAccountPref(account),
      );
    } catch (e, stackTrace) {
      _log.shout("[_persistAccount] Failed reading pref for account: $account",
          e, stackTrace);
    }
    unawaited(prefController.setAccounts(accounts));
    unawaited(prefController.setCurrentAccountIndex(accounts.indexOf(account)));
  }

  final NpDb npDb;
  final PrefController prefController;

  var _isHandlingError = false;
}
