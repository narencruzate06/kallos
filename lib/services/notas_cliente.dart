import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NotaCliente {
  final String alerta;
  final String notas;
  final DateTime? actualizada;

  const NotaCliente({this.alerta = '', this.notas = '', this.actualizada});

  bool get tieneAlerta => alerta.trim().isNotEmpty;
  bool get vacia => alerta.trim().isEmpty && notas.trim().isEmpty;

  Map<String, dynamic> toJson() => {
        'alerta': alerta,
        'notas': notas,
        'actualizada': actualizada?.toIso8601String(),
      };

  factory NotaCliente.fromJson(Map<String, dynamic> j) => NotaCliente(
        alerta: (j['alerta'] ?? '').toString(),
        notas: (j['notas'] ?? '').toString(),
        actualizada: DateTime.tryParse((j['actualizada'] ?? '').toString()),
      );
}

class NotasClienteService {
  NotasClienteService._();
  static final NotasClienteService instance = NotasClienteService._();

  static const _clave = 'kallos_notas_clientes';

  Future<Map<int, NotaCliente>> todas() async {
    final s = (await SharedPreferences.getInstance()).getString(_clave);
    if (s == null) return {};
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return {
        for (final e in m.entries)
          int.parse(e.key): NotaCliente.fromJson(Map<String, dynamic>.from(e.value as Map))
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> guardar(int clienteId, NotaCliente nota) async {
    final m = await todas();
    if (nota.vacia) {
      m.remove(clienteId);
    } else {
      m[clienteId] = nota;
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _clave, jsonEncode({for (final e in m.entries) '${e.key}': e.value.toJson()}));
  }
}
