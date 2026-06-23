import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../../core/models/demanda.dart';
import '../../../core/repositories/demanda_repository.dart';

/// Estado de leitura das duas listas do professor:
/// - **Prateleira** (UC08): demandas públicas disponíveis.
/// - **Minhas Demandas** (UC09–UC12): demandas atribuídas a ele.
///
/// Mantém duas `StreamSubscription` vivas enquanto o professor está logado e
/// re-subscreve a de "minhas" quando os filtros server-side mudam. A busca
/// textual é client-side (coerente com a arquitetura §7.3).
class ProfessorDemandasProvider extends ChangeNotifier {
  final DemandaRepository _repository;

  ProfessorDemandasProvider({DemandaRepository? repository})
      : _repository = repository ?? DemandaRepository();

  // ---- prateleira (UC08) ----
  StreamSubscription<List<Demanda>>? _subPrateleira;
  List<Demanda> _prateleira = [];
  String _buscaPrateleira = '';
  bool _carregandoPrateleira = false;
  String? _erroPrateleira;

  // ---- minhas demandas (UC09–UC12) ----
  StreamSubscription<List<Demanda>>? _subMinhas;
  List<Demanda> _minhas = [];
  String _buscaMinhas = '';
  StatusDemanda? _filtroStatus;
  FiltroPeriodo? _filtroPeriodo;
  bool _carregandoMinhas = false;
  String? _erroMinhas;

  String? _professorUid;

  /// IDs em rollback automático em andamento — evita disparar a mesma
  /// reconciliação várias vezes para o mesmo documento.
  final Set<String> _reconciliando = {};

  // ============== getters: prateleira ==============

  bool get carregandoPrateleira => _carregandoPrateleira;
  String? get erroPrateleira => _erroPrateleira;
  String get buscaPrateleira => _buscaPrateleira;

  List<Demanda> get prateleira {
    if (_buscaPrateleira.isEmpty) return _prateleira;
    final q = _buscaPrateleira.toLowerCase();
    return _prateleira
        .where((d) =>
            d.titulo.toLowerCase().contains(q) ||
            d.descricao.toLowerCase().contains(q))
        .toList();
  }

  // ============== getters: minhas ==============

  bool get carregandoMinhas => _carregandoMinhas;
  String? get erroMinhas => _erroMinhas;
  String get buscaMinhas => _buscaMinhas;
  StatusDemanda? get filtroStatus => _filtroStatus;
  FiltroPeriodo? get filtroPeriodo => _filtroPeriodo;

  int get filtrosAtivos {
    var n = 0;
    if (_filtroStatus != null) n++;
    if (_filtroPeriodo != null) n++;
    return n;
  }

  bool get temFiltrosAtivos => filtrosAtivos > 0;

  List<Demanda> get minhas {
    if (_buscaMinhas.isEmpty) return _minhas;
    final q = _buscaMinhas.toLowerCase();
    return _minhas.where((d) => d.titulo.toLowerCase().contains(q)).toList();
  }

  // ============== ciclo de vida ==============

  /// Inicia as observações. Idempotente para o mesmo professor.
  void observar(String professorUid) {
    if (_professorUid == professorUid &&
        _subPrateleira != null &&
        _subMinhas != null) {
      return;
    }
    _professorUid = professorUid;
    _observarPrateleira();
    _observarMinhas();
  }

  void _observarPrateleira() {
    _carregandoPrateleira = true;
    _erroPrateleira = null;
    notifyListeners();

    _subPrateleira?.cancel();
    _subPrateleira = _repository.listarPrateleira().listen(
      (lista) {
        _prateleira = lista;
        _carregandoPrateleira = false;
        _erroPrateleira = null;
        notifyListeners();
      },
      onError: (Object e) {
        _carregandoPrateleira = false;
        _erroPrateleira =
            e is AppException ? e.message : 'Erro ao carregar a prateleira';
        notifyListeners();
      },
    );
  }

  void _observarMinhas() {
    final uid = _professorUid;
    if (uid == null) return;

    _carregandoMinhas = true;
    _erroMinhas = null;
    notifyListeners();

    _subMinhas?.cancel();
    _subMinhas = _repository
        .listarDoProfessor(
      professorUid: uid,
      filtroStatus: _filtroStatus,
      filtroPeriodo: _filtroPeriodo,
    )
        .listen(
      (lista) {
        _minhas = lista;
        _carregandoMinhas = false;
        _erroMinhas = null;
        notifyListeners();
        _reconciliarExpiradas(lista, uid);
      },
      onError: (Object e) {
        _carregandoMinhas = false;
        _erroMinhas =
            e is AppException ? e.message : 'Erro ao carregar suas demandas';
        notifyListeners();
      },
    );
  }

  /// Rollback best-effort da janela de 24h (UC09 R04) enquanto não há Cloud
  /// Function. Ao receber a lista, devolve para a prateleira as demandas cuja
  /// análise expirou. Só o professor associado tem permissão de fazê-lo — por
  /// isso a reconciliação roda aqui, no contexto "Minhas Demandas". A Cloud
  /// Function fará isso globalmente e em tempo hábil (ver docs/CLOUD_FUNCTIONS.md).
  void _reconciliarExpiradas(List<Demanda> lista, String professorUid) {
    for (final d in lista) {
      if (!d.analiseExpirou || _reconciliando.contains(d.id)) continue;
      _reconciliando.add(d.id);
      _repository
          .rejeitarAnalise(
        demandaId: d.id,
        professorUid: professorUid,
        automatico: true,
      )
          .catchError((_) {
        /* best-effort: a CF cobrirá o que falhar */
      }).whenComplete(() => _reconciliando.remove(d.id));
    }
  }

  // ============== ações de filtro/busca ==============

  void atualizarBuscaPrateleira(String texto) {
    _buscaPrateleira = texto.trim();
    notifyListeners();
  }

  void atualizarBuscaMinhas(String texto) {
    _buscaMinhas = texto.trim();
    notifyListeners();
  }

  void aplicarFiltrosMinhas({
    StatusDemanda? status,
    FiltroPeriodo? periodo,
  }) {
    _filtroStatus = status;
    _filtroPeriodo = periodo;
    _observarMinhas();
  }

  void limparFiltrosMinhas() {
    aplicarFiltrosMinhas(status: null, periodo: null);
  }

  @override
  void dispose() {
    _subPrateleira?.cancel();
    _subMinhas?.cancel();
    super.dispose();
  }
}
