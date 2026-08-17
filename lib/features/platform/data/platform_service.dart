/// Platform CRUD: `/api/config/platform/{new,update,delete}`. Toggle is just
/// update with `enable` flipped on the full config object.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class PlatformService {
  PlatformService(this._dio);
  final Dio _dio;

  Future<void> create(Map<String, dynamic> config) =>
      _post('/api/config/platform/new', config);

  /// Used both for full edits and for enable/disable toggling.
  Future<void> update(String id, Map<String, dynamic> config) =>
      _post('/api/config/platform/update', {'id': id, 'config': config});

  Future<void> delete(String id) =>
      _post('/api/config/platform/delete', {'id': id});

  Future<void> _post(String path, Map<String, dynamic> body) async {
    try {
      await _dio.post<dynamic>(path, data: body);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException.fromDio(e);
    }
  }
}

final platformServiceProvider = Provider<PlatformService>(
    (ref) => PlatformService(ref.watch(apiClientProvider)));
