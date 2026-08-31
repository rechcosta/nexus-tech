import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../../core/models/notificacao.dart';
import '../../../core/repositories/notificacao_repository.dart';

/// Central de notificações in-app.
///
/// Mantém **um único stream** para os dois consumidores — o badge do sino e a
/// tela da central. Abrir a tela não custa leitura nova, e o badge nunca fica
/// dessincronizado da lista, porque ambos derivam da mesma fonte.
class NotificacoesProvider extends ChangeNotifier {
  final NotificacaoRepository _repository;

  NotificacoesProvider({NotificacaoRepository? repository})
      : _repository = repository ?? NotificacaoRepository();

  StreamSubscription<List<Notificacao>>? _sub;
  List<Notificacao> _notificacoes = const [];
  bool _carregando = false;
  String? _erro;
  String? _uid;

  List<Notificacao> get notificacoes => _notificacoes;
  bool get carregando => _carregando;
  String? get erro => _erro;

  int get naoLidas => _notificacoes.where((n) => !n.lida).length;
  bool get temNaoLidas => naoLidas > 0;

  /// Inicia a observação. Idempotente para o mesmo usuário — chamada dos
  /// `initState` das telas raiz de cada papel.
  void observar(String uid) {
    if (_uid == uid && _sub != null) return;
    _uid = uid;

    _carregando = true;
    _erro = null;
    notifyListeners();

    _sub?.cancel();
    _sub = _repository.observar(uid).listen(
      (lista) {
        _notificacoes = lista;
        _carregando = false;
        _erro = null;
        notifyListeners();
      },
      onError: (Object e) {
        _carregando = false;
        _erro = e is AppException
            ? e.message
            : 'Não foi possível carregar suas notificações.';
        notifyListeners();
      },
    );
  }

  /// Encerra a observação (logout). Zera a lista para que o badge do próximo
  /// usuário não herde a contagem do anterior.
  void limpar() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    _notificacoes = const [];
    _erro = null;
    notifyListeners();
  }

  /// Marca como lida. Não faz nada se já estiver lida — evita escrita inútil
  /// a cada toque numa notificação antiga.
  Future<void> marcarComoLida(Notificacao n) async {
    if (n.lida) return;
    try {
      await _repository.marcarComoLida(n.id);
    } on AppException catch (e) {
      _erro = e.message;
      notifyListeners();
    }
  }

  Future<void> marcarTodasComoLidas() async {
    final uid = _uid;
    if (uid == null || !temNaoLidas) return;
    try {
      await _repository.marcarTodasComoLidas(uid);
    } on AppException catch (e) {
      _erro = e.message;
      notifyListeners();
    }
  }

  void limparErro() {
    if (_erro == null) return;
    _erro = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
