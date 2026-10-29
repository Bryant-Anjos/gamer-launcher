import 'package:flutter/foundation.dart';
import 'package:gamer_launcher/backend/launcher_backend.dart';
import 'package:gamer_launcher/src/rust/api/files.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/state/launcher_state.dart';
import 'package:gamer_launcher/state/messages.dart';
import 'package:gamer_launcher/state/settings_edit.dart';

export 'package:gamer_launcher/state/launcher_state.dart';

/// Recentes lidos de uma vez; a tela inicial mostra só os primeiros.
const recentsLimit = 30;

/// Dono do estado da tela: configurações, apps, recentes e seção atual.
/// Toda falha vira aviso em [LauncherMessages]; nada derruba a tela.
class LauncherController extends ValueNotifier<LauncherState> {
  LauncherController(this._backend, this._messages)
    : super(LauncherState(settings: _backend.defaultSettings()));

  final LauncherBackend _backend;
  final LauncherMessages _messages;
  bool _disposed = false;

  @override
  set value(LauncherState next) {
    // leituras que terminam depois do fechamento do app são descartadas
    if (!_disposed) super.value = next;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<T?> _attempt<T>(Future<T> Function() call, String context) async {
    try {
      return await call();
    } on BackendException catch (error) {
      _messages.show('$context: ${error.message}');
      return null;
    }
  }

  Future<void> load() async {
    // As quatro leituras começam juntas: uma lenta não segura as outras.
    final settingsLoad = _attempt(
      _backend.loadSettings,
      'Configurações inválidas, usando o padrão',
    );
    final catalogLoad = _attempt(
      _backend.loadCatalog,
      'Não foi possível listar os apps',
    );
    final recentsLoad = _attempt(
      () => _backend.listRecents(recentsLimit),
      'Não foi possível ler os recentes',
    );
    final userNameLoad = _loadUserName();

    // A tela aparece assim que configurações e apps chegam (o necessário
    // para os favoritos); recentes e nome entram depois, sem segurá-la.
    final settings = await settingsLoad;
    final catalog = await catalogLoad;
    catalog?.warnings.forEach(_messages.show);
    if (settings != null) _applyButtonLayout(settings.buttonLayout);
    // `value` lido só agora: uma troca de seção durante a carga é mantida
    value = value.copyWith(
      settings: settings,
      catalog: catalog,
      lastAppId: catalog?.lastAppId,
      isReady: true,
    );
    final recents = await recentsLoad;
    final userName = await userNameLoad;
    if (_disposed) return;
    value = value.copyWith(recents: recents, userName: userName);
  }

  /// Sem nome a saudação só fica genérica; não vale um aviso.
  Future<String?> _loadUserName() async {
    try {
      return await _backend.userFirstName();
    } on BackendException {
      return null;
    }
  }

  Future<void> refreshRecents() async {
    final recents = await _attempt(
      () => _backend.listRecents(recentsLimit),
      'Não foi possível ler os recentes',
    );
    if (recents != null) value = value.copyWith(recents: recents);
  }

  void selectSection(Section section) {
    value = value.copyWith(section: section);
  }

  /// LB/RB: anda pelas seções dando a volta nas pontas; [among] são as que
  /// existem nesta máquina (a do Claude só com ele instalado).
  void cycleSection(int delta, {List<Section> among = Section.values}) {
    final current = among.indexOf(value.section);
    final next = (current + delta) % among.length;
    selectSection(among[next]);
  }

  /// Fila das gravações: cada edição parte do resultado da anterior.
  Future<void> _settingsQueue = Future.value();

  /// Aplica [edit] às configurações atuais, grava e só então mostra.
  /// Edições rápidas em sequência (dois favoritos seguidos) entram na fila
  /// em vez de partirem do mesmo estado antigo e se sobrescreverem.
  Future<void> editSettings(
    LauncherSettings Function(LauncherSettings current) edit,
  ) {
    final run = _settingsQueue.then((_) => _save(edit(value.settings)));
    // o erro chega a quem chamou por `run`; a fila segue para as próximas
    _settingsQueue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  /// Grava primeiro e só aplica se o núcleo aceitar.
  Future<void> _save(LauncherSettings next) async {
    final saved = await _attempt(() async {
      await _backend.saveSettings(next);
      return true;
    }, 'Não foi possível salvar as configurações');
    if (saved != true) return;
    final previous = value.settings.buttonLayout;
    value = value.copyWith(settings: next);
    if (next.buttonLayout != previous) _applyButtonLayout(next.buttonLayout);
  }

  /// O leitor do controle troca o layout na hora; recusa vira aviso (a
  /// escolha fica salva e vale na próxima abertura).
  void _applyButtonLayout(LauncherButtonLayout layout) {
    try {
      _backend.setButtonLayout(layout);
    } on BackendException catch (error) {
      _messages.show(
        'Não foi possível aplicar o layout dos botões: ${error.message}',
      );
    }
  }

  Future<void> updateSettings(LauncherSettings next) =>
      editSettings((_) => next);

  Future<void> toggleFavorite(String appId) =>
      editSettings((settings) => settings.toggleFavorite(appId));

  Future<void> launchApp(String appId) async {
    final name = value.appById(appId)?.name ?? appId;
    try {
      final warning = await _backend.launchApp(appId);
      if (warning != null) _messages.show(warning);
      value = value.copyWith(lastAppId: appId);
    } on BackendException catch (error) {
      _messages.show('Não foi possível abrir $name: ${error.message}');
    }
  }

  /// [label] diz qual página falhou no aviso ("de Bluetooth").
  Future<void> openSettingsPage(String page, String label) async {
    await _attempt(
      () => _backend.openSettingsPage(page),
      'Não foi possível abrir as configurações $label',
    );
  }

  Future<void> openRecent(RecentFile file) async {
    await _attempt(
      () => _backend.openPath(file.path),
      'Não foi possível abrir ${file.name}',
    );
  }
}
