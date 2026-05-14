import 'package:flutter/foundation.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../../core/models/area.dart';
import '../../../core/models/demandante.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/professor.dart';
import '../../../core/repositories/area_repository.dart';
import '../../../core/repositories/usuario_repository.dart';

enum CadastroStatus { initial, salvando, sucesso, erro }

class CadastroProvider extends ChangeNotifier {
  final UsuarioRepository _usuarioRepository;
  final AreaRepository _areaRepository;

  CadastroProvider({
    UsuarioRepository? usuarioRepository,
    AreaRepository? areaRepository,
  })  : _usuarioRepository = usuarioRepository ?? UsuarioRepository(),
        _areaRepository = areaRepository ?? AreaRepository();

  CadastroStatus _status = CadastroStatus.initial;
  String? _erro;

  List<Area> _areasTecnicas = [];
  List<Area> _areasInteresse = [];
  bool _carregandoAreas = false;

  CadastroStatus get status => _status;
  String? get erro => _erro;
  bool get salvando => _status == CadastroStatus.salvando;
  bool get carregandoAreas => _carregandoAreas;
  List<Area> get areasTecnicas => List.unmodifiable(_areasTecnicas);
  List<Area> get areasInteresse => List.unmodifiable(_areasInteresse);

  Future<void> carregarAreas() async {
    _carregandoAreas = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _areaRepository.listar(TipoArea.tecnica),
        _areaRepository.listar(TipoArea.interesse),
      ]);
      _areasTecnicas = results[0];
      _areasInteresse = results[1];
      _erro = null;
    } on AppException catch (e) {
      _erro = e.message;
    } catch (e) {
      _erro = 'Erro inesperado ao carregar áreas.';
    } finally {
      _carregandoAreas = false;
      notifyListeners();
    }
  }

  Future<String?> adicionarNovaArea({
    required TipoArea tipo,
    required String nomeBruto,
    required String criadoPorUid,
  }) async {
    try {
      final area = await _areaRepository.criarSeNaoExiste(
        tipo: tipo,
        nomeBruto: nomeBruto,
        criadoPorUid: criadoPorUid,
      );

      // Atualiza cache local
      if (tipo == TipoArea.tecnica) {
        if (!_areasTecnicas.any((a) => a.id == area.id)) {
          _areasTecnicas = [..._areasTecnicas, area]
            ..sort((a, b) => a.nome.compareTo(b.nome));
        }
      } else {
        if (!_areasInteresse.any((a) => a.id == area.id)) {
          _areasInteresse = [..._areasInteresse, area]
            ..sort((a, b) => a.nome.compareTo(b.nome));
        }
      }
      notifyListeners();
      return area.nome;
    } catch (e) {
      return null;
    }
  }

  Future<bool> cadastrarProfessor({
    required String uid,
    required String email,
    required String nome,
    required String siape,
    required List<String> areasTecnicas,
    required List<String> areasInteresse,
  }) async {
    try {
      _status = CadastroStatus.salvando;
      _erro = null;
      notifyListeners();

      final professor = Professor(
        uid: uid,
        email: email,
        nome: nome.trim(),
        criadoEm: DateTime.now(),
        siape: siape.trim(),
        areasTecnicas: areasTecnicas,
        areasInteresse: areasInteresse,
      );

      await _usuarioRepository.criarProfessor(professor);

      _status = CadastroStatus.sucesso;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _erro = e.message;
      _status = CadastroStatus.erro;
      notifyListeners();
      return false;
    } catch (e) {
      _erro = 'Erro inesperado ao concluir cadastro.';
      _status = CadastroStatus.erro;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cadastrarDemandante({
    required String uid,
    required String email,
    required String nome,
    required String telefone,
    required TipoDemandante tipo,
    required String cpfCnpj,
    required String endereco,
  }) async {
    try {
      _status = CadastroStatus.salvando;
      _erro = null;
      notifyListeners();

      final demandante = Demandante(
        uid: uid,
        email: email,
        nome: nome.trim(),
        criadoEm: DateTime.now(),
        telefone: telefone.replaceAll(RegExp(r'\D'), ''),
        tipo: tipo,
        cpfCnpj: cpfCnpj.replaceAll(RegExp(r'\D'), ''),
        endereco: endereco.trim(),
      );

      await _usuarioRepository.criarDemandante(demandante);

      _status = CadastroStatus.sucesso;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _erro = e.message;
      _status = CadastroStatus.erro;
      notifyListeners();
      return false;
    } catch (e) {
      _erro = 'Erro inesperado ao concluir cadastro.';
      _status = CadastroStatus.erro;
      notifyListeners();
      return false;
    }
  }
}
