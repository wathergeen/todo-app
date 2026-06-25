import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/column_model.dart';
import '../models/task_model.dart';

const baseUrl = 'http://10.0.2.2:5000/api';

class KanbanService {
  KanbanService._()
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            validateStatus: (_) => true,
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static final KanbanService instance = KanbanService._();

  final Dio _dio;
  String? _token;

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  Future<String?> loadTokenFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
    return _token;
  }

  Future<void> register(String username, String password) async {
    final response = await _dio.post(
      '/register',
      data: {'username': username, 'password': password},
    );
    if (response.statusCode != 201) {
      throw Exception(_errorMessage(response, 'Erro ao cadastrar usuário'));
    }
  }

  Future<String> login(String username, String password) async {
    final response = await _dio.post(
      '/login',
      data: {'username': username, 'password': password},
    );
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Erro ao entrar'));
    }

    final token = response.data['access_token'] as String;
    await setToken(token);
    return token;
  }

  Future<List<ColumnModel>> getBoard() async {
    final response = await _dio.get('/board');
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Erro ao carregar board'));
    }

    return ((response.data['columns'] as List<dynamic>?) ?? [])
        .map((column) => ColumnModel.fromJson(column as Map<String, dynamic>))
        .toList();
  }

  Future<TaskModel> createTask(
    String title,
    int columnId,
    String description,
  ) async {
    final response = await _dio.post(
      '/tasks',
      data: {
        'title': title,
        'column_id': columnId,
        'description': description,
      },
    );
    if (response.statusCode != 201) {
      throw Exception(_errorMessage(response, 'Erro ao criar tarefa'));
    }

    return TaskModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TaskModel> moveTask(
    int taskId,
    int targetColumnId,
    int targetOrder,
  ) async {
    final response = await _dio.patch(
      '/tasks/$taskId',
      data: {'column_id': targetColumnId, 'order': targetOrder},
    );
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Erro ao mover tarefa'));
    }

    return TaskModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteTask(int taskId) async {
    final response = await _dio.delete('/tasks/$taskId');
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Erro ao deletar tarefa'));
    }
  }

  String _errorMessage(Response<dynamic> response, String fallback) {
    final data = response.data;
    if (data is Map<String, dynamic> && data['error'] is String) {
      return data['error'] as String;
    }
    return fallback;
  }
}
