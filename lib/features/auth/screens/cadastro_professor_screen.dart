import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/area_repository.dart';
import '../../../core/utils/validators.dart';
import '../providers/cadastro_provider.dart';
import '../widgets/auth_header.dart';
import '../widgets/form_label.dart';

class CadastroProfessorScreen extends StatefulWidget {
  const CadastroProfessorScreen({super.key});

  @override
  State<CadastroProfessorScreen> createState() =>
      _CadastroProfessorScreenState();
}

class _CadastroProfessorScreenState extends State<CadastroProfessorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _siape = TextEditingController();

  final Set<String> _areasTecnicasSelecionadas = {};
  final Set<String> _areasInteresseSelecionadas = {};

  bool _tentouSubmeter = false;

  @override
  void initState() {
    super.initState();
    // Carrega áreas do Firestore ao abrir a tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CadastroProvider>().carregarAreas();
    });
  }

  @override
  void dispose() {
    _nome.dispose();
    _siape.dispose();
    super.dispose();
  }

  Future<void> _adicionarArea({required TipoArea tipo}) async {
    final controller = TextEditingController();
    final nomeBruto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tipo == TipoArea.tecnica
              ? 'Nova área técnica'
              : 'Nova área de interesse',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nome da área'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (nomeBruto == null || nomeBruto.isEmpty) return;
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final cadastro = context.read<CadastroProvider>();
    final firebaseUser = auth.firebaseUser;
    if (firebaseUser == null) return;

    final nomeFinal = await cadastro.adicionarNovaArea(
      tipo: tipo,
      nomeBruto: nomeBruto,
      criadoPorUid: firebaseUser.uid,
    );

    if (!mounted) return;

    if (nomeFinal != null) {
      setState(() {
        if (tipo == TipoArea.tecnica) {
          _areasTecnicasSelecionadas.add(nomeFinal);
        } else {
          _areasInteresseSelecionadas.add(nomeFinal);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível adicionar a área')),
      );
    }
  }

  Future<void> _submeter() async {
    setState(() => _tentouSubmeter = true);

    final formOk = _formKey.currentState!.validate();
    final tecnicasOk = _areasTecnicasSelecionadas.isNotEmpty;
    final interessesOk = _areasInteresseSelecionadas.isNotEmpty;

    if (!formOk || !tecnicasOk || !interessesOk) return;

    final auth = context.read<AuthProvider>();
    final cadastro = context.read<CadastroProvider>();
    final firebaseUser = auth.firebaseUser;
    if (firebaseUser == null) return;

    final ok = await cadastro.cadastrarProfessor(
      uid: firebaseUser.uid,
      email: firebaseUser.email!,
      nome: _nome.text,
      siape: _siape.text,
      areasTecnicas: _areasTecnicasSelecionadas.toList(),
      areasInteresse: _areasInteresseSelecionadas.toList(),
    );

    if (!mounted) return;

    if (ok) {
      await auth.recarregarUsuario();
    } else if (cadastro.erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cadastro.erro!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cadastro = context.watch<CadastroProvider>();

    if (cadastro.carregandoAreas && cadastro.areasTecnicas.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuthHeader(titulo: 'Cadastro de Professor'),
                const FormLabel('Nome *'),
                TextFormField(
                  controller: _nome,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Digite seu nome completo',
                  ),
                  validator: Validators.nome,
                ),
                const SizedBox(height: 20),
                const FormLabel('SIAPE *'),
                TextFormField(
                  controller: _siape,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(7),
                  ],
                  decoration: const InputDecoration(hintText: 'XXXXXXX'),
                  validator: Validators.siape,
                ),
                const SizedBox(height: 20),
                const FormLabel('Áreas Técnicas *'),
                _ChipsSelector(
                  opcoes: cadastro.areasTecnicas
                      .map((a) => a.nome)
                      .toList(growable: false),
                  selecionadas: _areasTecnicasSelecionadas,
                  onToggle: (a) => setState(() {
                    if (_areasTecnicasSelecionadas.contains(a)) {
                      _areasTecnicasSelecionadas.remove(a);
                    } else {
                      _areasTecnicasSelecionadas.add(a);
                    }
                  }),
                  onAdicionar: () => _adicionarArea(tipo: TipoArea.tecnica),
                ),
                if (_tentouSubmeter && _areasTecnicasSelecionadas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Selecione ao menos uma área técnica',
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 20),
                const FormLabel('Áreas de Interesse *'),
                _ChipsSelector(
                  opcoes: cadastro.areasInteresse
                      .map((a) => a.nome)
                      .toList(growable: false),
                  selecionadas: _areasInteresseSelecionadas,
                  onToggle: (a) => setState(() {
                    if (_areasInteresseSelecionadas.contains(a)) {
                      _areasInteresseSelecionadas.remove(a);
                    } else {
                      _areasInteresseSelecionadas.add(a);
                    }
                  }),
                  onAdicionar: () => _adicionarArea(tipo: TipoArea.interesse),
                ),
                if (_tentouSubmeter && _areasInteresseSelecionadas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Selecione ao menos uma área de interesse',
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: cadastro.salvando ? null : _submeter,
                  child: cadastro.salvando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Concluir cadastro'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipsSelector extends StatelessWidget {
  final List<String> opcoes;
  final Set<String> selecionadas;
  final ValueChanged<String> onToggle;
  final VoidCallback onAdicionar;

  const _ChipsSelector({
    required this.opcoes,
    required this.selecionadas,
    required this.onToggle,
    required this.onAdicionar,
  });

  @override
  Widget build(BuildContext context) {
    // Une opções da fonte com selecionadas (caso o professor tenha acabado
    // de adicionar uma área que ainda não está na lista de opções).
    final todas = {...opcoes, ...selecionadas}.toList();

    if (todas.isEmpty) {
      return Wrap(
        children: [
          ActionChip(
            avatar: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text(
              'Adicionar primeira área',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.success,
            onPressed: onAdicionar,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...todas.map((area) {
          final selected = selecionadas.contains(area);
          return FilterChip(
            label: Text(area),
            selected: selected,
            onSelected: (_) => onToggle(area),
            selectedColor: AppColors.primary,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.primary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.primary),
            ),
          );
        }),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18, color: Colors.white),
          label: const Text(
            'Nova',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.success,
          onPressed: onAdicionar,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ],
    );
  }
}
