/// Persona CRUD endpoints used by `views/PersonaPage.vue` and
/// `components/shared/PersonaForm.vue`.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class Persona {
  final Map<String, dynamic> raw;
  Persona(this.raw);

  String get id => (raw['persona_id'] ?? '').toString();
  String get systemPrompt => (raw['system_prompt'] ?? '').toString();
  List<String> get tools {
    final t = raw['tools'];
    if (t is List) return t.map((e) => e.toString()).toList();
    return const [];
  }

  List<Map<String, dynamic>> get beginDialogs {
    final d = raw['begin_dialogs'];
    if (d is List) {
      return d
          .map((e) => e is Map
              ? Map<String, dynamic>.from(e)
              : <String, dynamic>{'content': e.toString()})
          .toList();
    }
    return const [];
  }
}

class FunctionTool {
  final String name;
  final String? description;
  final String? mcpServerName;
  FunctionTool(this.name, {this.description, this.mcpServerName});

  factory FunctionTool.fromMap(Map raw) => FunctionTool(
        (raw['name'] ?? '').toString(),
        description: raw['description']?.toString(),
        mcpServerName: raw['mcp_server_name']?.toString(),
      );
}

class PersonaService {
  PersonaService(this._dio);
  final Dio _dio;

  Future<List<Persona>> list() async {
    try {
      final res = await _dio.get<dynamic>('/api/persona/list');
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((m) => Persona(Map<String, dynamic>.from(m)))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<void> save(Map<String, dynamic> persona, {required bool isNew}) =>
      _post(isNew ? '/api/persona/create' : '/api/persona/update', persona);

  Future<void> delete(String id) =>
      _post('/api/persona/delete', {'persona_id': id});

  Future<List<FunctionTool>> listTools() async {
    try {
      final res = await _dio.get<dynamic>('/api/tools/list');
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((m) => FunctionTool.fromMap(m))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    try {
      await _dio.post<dynamic>(path, data: body);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }
}

final personaServiceProvider = Provider<PersonaService>(
    (ref) => PersonaService(ref.watch(apiClientProvider)));

final personasProvider = FutureProvider<List<Persona>>((ref) async {
  ref.watch(apiClientProvider); // refresh on server-profile switch
  return ref.watch(personaServiceProvider).list();
});

final functionToolsProvider = FutureProvider<List<FunctionTool>>((ref) async {
  ref.watch(apiClientProvider); // refresh on server-profile switch
  return ref.watch(personaServiceProvider).listTools();
});
