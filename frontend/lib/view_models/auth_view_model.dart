import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/kanban_service.dart';

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isAuthenticated,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

final authProvider = StateNotifierProvider<AuthViewModel, AuthState>((ref) {
  return AuthViewModel(KanbanService.instance);
});

class AuthViewModel extends StateNotifier<AuthState> {
  AuthViewModel(this._service) : super(const AuthState());

  final KanbanService _service;

  Future<void> login(
    String username,
    String password,
    BuildContext context,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.login(username, password);
      state = state.copyWith(isLoading: false, isAuthenticated: true);
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/board');
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<bool> register(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.register(username, password);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> logout(BuildContext context) async {
    await _service.clearToken();
    state = const AuthState();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}
