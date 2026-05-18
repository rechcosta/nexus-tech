import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_tech/core/utils/validators.dart';

void main() {
  group('Validators.cpfCnpj — campos obrigatórios e formato', () {
    test('null retorna mensagem de obrigatório', () {
      expect(Validators.cpfCnpj(null), 'CPF/CNPJ é obrigatório');
    });

    test('string vazia retorna mensagem de obrigatório', () {
      expect(Validators.cpfCnpj(''), 'CPF/CNPJ é obrigatório');
    });

    test('só espaços retorna mensagem de obrigatório', () {
      expect(Validators.cpfCnpj('   '), 'CPF/CNPJ é obrigatório');
    });

    test('quantidade de dígitos inválida (nem CPF nem CNPJ)', () {
      expect(
        Validators.cpfCnpj('123'),
        'Digite um CPF (11 dígitos) ou CNPJ (14 dígitos)',
      );
      expect(
        Validators.cpfCnpj('123456789012'),
        'Digite um CPF (11 dígitos) ou CNPJ (14 dígitos)',
      );
    });
  });

  group('Validators.cpfCnpj — CPF', () {
    test('aceita CPF válido sem máscara (12345678909)', () {
      expect(Validators.cpfCnpj('12345678909'), isNull);
    });

    test('aceita CPF válido sem máscara (11144477735)', () {
      expect(Validators.cpfCnpj('11144477735'), isNull);
    });

    test('aceita CPF válido com máscara (123.456.789-09)', () {
      expect(Validators.cpfCnpj('123.456.789-09'), isNull);
    });

    test('rejeita CPF com DV2 errado', () {
      expect(Validators.cpfCnpj('12345678900'), 'CPF inválido');
    });

    test('rejeita CPF com DV1 errado', () {
      expect(Validators.cpfCnpj('12345678919'), 'CPF inválido');
    });

    test('rejeita sequências repetidas (proteção anti-fraude)', () {
      const sequencias = [
        '00000000000',
        '11111111111',
        '22222222222',
        '33333333333',
        '99999999999',
      ];
      for (final cpf in sequencias) {
        expect(
          Validators.cpfCnpj(cpf),
          'CPF inválido',
          reason: 'esperava rejeitar sequência $cpf',
        );
      }
    });
  });

  group('Validators.cpfCnpj — CNPJ', () {
    test('aceita CNPJ válido sem máscara (11222333000181)', () {
      expect(Validators.cpfCnpj('11222333000181'), isNull);
    });

    test('aceita CNPJ válido com máscara (11.222.333/0001-81)', () {
      expect(Validators.cpfCnpj('11.222.333/0001-81'), isNull);
    });

    test('rejeita CNPJ com dígito verificador errado', () {
      expect(Validators.cpfCnpj('11222333000180'), 'CNPJ inválido');
    });

    test('rejeita CNPJ com 14 dígitos repetidos', () {
      expect(Validators.cpfCnpj('11111111111111'), 'CNPJ inválido');
    });
  });

  group('Validators.telefone — comprimento e formato', () {
    test('null/vazio retornam obrigatório', () {
      expect(Validators.telefone(null), 'Telefone é obrigatório');
      expect(Validators.telefone(''), 'Telefone é obrigatório');
    });

    test('menos de 10 dígitos é rejeitado', () {
      expect(
        Validators.telefone('5198765'),
        'Telefone deve ter 10 ou 11 dígitos',
      );
    });

    test('mais de 11 dígitos é rejeitado', () {
      expect(
        Validators.telefone('551987654321'),
        'Telefone deve ter 10 ou 11 dígitos',
      );
    });
  });

  group('Validators.telefone — DDDs', () {
    test('aceita DDDs válidos de diferentes regiões', () {
      // 11 SP, 51 RS, 21 RJ, 71 BA, 81 PE, 91 PA
      expect(Validators.telefone('11987654321'), isNull);
      expect(Validators.telefone('51987654321'), isNull);
      expect(Validators.telefone('21987654321'), isNull);
      expect(Validators.telefone('71987654321'), isNull);
      expect(Validators.telefone('81987654321'), isNull);
      expect(Validators.telefone('91987654321'), isNull);
    });

    test('rejeita DDDs inexistentes', () {
      const dddsInvalidos = ['20', '23', '39', '50', '90'];
      for (final ddd in dddsInvalidos) {
        expect(
          Validators.telefone('${ddd}987654321'),
          'DDD inválido',
          reason: 'esperava rejeitar DDD $ddd',
        );
      }
    });
  });

  group('Validators.telefone — celular (11 dígitos)', () {
    test('aceita celular que começa com 9 após DDD', () {
      expect(Validators.telefone('51987654321'), isNull);
    });

    test('rejeita 11 dígitos que não começa com 9 após DDD', () {
      expect(
        Validators.telefone('51887654321'),
        'Celular deve começar com 9 após o DDD',
      );
    });

    test('aceita celular com máscara formatada', () {
      expect(Validators.telefone('(51) 98765-4321'), isNull);
    });
  });

  group('Validators.telefone — fixo (10 dígitos)', () {
    test('aceita fixo válido', () {
      expect(Validators.telefone('5132345678'), isNull);
    });

    test('rejeita fixo começando com 0 após DDD', () {
      expect(Validators.telefone('5102345678'), 'Telefone fixo inválido');
    });

    test('rejeita fixo começando com 1 após DDD', () {
      expect(Validators.telefone('5112345678'), 'Telefone fixo inválido');
    });
  });

  group('Validators.nome', () {
    test('null/vazio retornam obrigatório', () {
      expect(Validators.nome(null), 'Nome é obrigatório');
      expect(Validators.nome('   '), 'Nome é obrigatório');
    });

    test('menos de 3 caracteres é muito curto', () {
      expect(Validators.nome('Ab'), 'Nome muito curto');
    });

    test('só dígitos é rejeitado', () {
      expect(Validators.nome('12345'), 'Nome inválido');
    });

    test('exige sobrenome (precisa ter espaço)', () {
      expect(Validators.nome('Gustavo'), 'Informe nome e sobrenome');
    });

    test('rejeita partes com menos de 2 letras', () {
      expect(Validators.nome('A B'), 'Nome inválido');
      expect(Validators.nome('Gustavo R'), 'Nome inválido');
    });

    test('aceita nome com acento', () {
      expect(Validators.nome('João Pedro'), isNull);
      expect(Validators.nome('María Aparecida'), isNull);
    });

    test('aceita nome composto com hífen', () {
      expect(Validators.nome('Ana-Clara Silva'), isNull);
    });

    test('rejeita nome com dígito no meio', () {
      expect(
        Validators.nome('Gustavo3 Costa'),
        'Nome contém caracteres inválidos',
      );
    });

    test('rejeita nome com caractere especial', () {
      expect(
        Validators.nome('Gustavo! Costa!'),
        'Nome contém caracteres inválidos',
      );
    });
  });

  group('Validators.siape', () {
    test('null/vazio retornam obrigatório', () {
      expect(Validators.siape(null), 'SIAPE é obrigatório');
    });

    test('exige exatamente 7 dígitos', () {
      expect(Validators.siape('123456'), 'SIAPE deve ter 7 dígitos');
      expect(Validators.siape('12345678'), 'SIAPE deve ter 7 dígitos');
    });

    test('aceita SIAPE de 7 dígitos', () {
      expect(Validators.siape('1234567'), isNull);
    });
  });
}
