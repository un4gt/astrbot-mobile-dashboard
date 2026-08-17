/// MCP / function-tool service. Wraps `/api/tools/*` for MCP servers and
/// individual tool toggling.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class McpServer {
  final Map<String, dynamic> raw;
  McpServer(this.raw);

  String get name => (raw['name'] ?? '').toString();
  bool get active =>
      raw['active'] == true || raw['enable'] == true || raw['enabled'] == true;
  String get type =>
      (raw['type'] ?? raw['transport'] ?? 'stdio').toString();
  String? get command => raw['command']?.toString();
  String? get url => raw['url']?.toString();
}

class McpService {
  McpService(this._dio);
  final Dio _dio;

  Future<List<McpServer>> listServers() async {
    try {
      final res = await _dio.get<dynamic>('/api/tools/mcp/servers');
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((m) => McpServer(Map<String, dynamic>.from(m)))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }

  Future<void> addServer(Map<String, dynamic> server) =>
      _post('/api/tools/mcp/add', server);

  Future<void> updateServer(Map<String, dynamic> server) =>
      _post('/api/tools/mcp/update', server);

  Future<void> deleteServer(String name) =>
      _post('/api/tools/mcp/delete', {'name': name});

  Future<void> testServer(Map<String, dynamic> server) =>
      _post('/api/tools/mcp/test', server);

  Future<void> toggleTool(String name, bool active) =>
      _post('/api/tools/toggle-tool', {'name': name, 'active': active});

  Future<void> _post(String path, Map<String, dynamic> body) async {
    try {
      await _dio.post<dynamic>(path, data: body);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }
}

final mcpServiceProvider =
    Provider<McpService>((ref) => McpService(ref.watch(apiClientProvider)));

final mcpServersProvider = FutureProvider<List<McpServer>>((ref) async {
  ref.watch(apiClientProvider); // refresh on server-profile switch
  return ref.watch(mcpServiceProvider).listServers();
});
