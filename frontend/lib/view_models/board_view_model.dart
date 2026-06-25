import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/column_model.dart';
import '../models/task_model.dart';
import '../services/kanban_service.dart';

class BoardState {
  const BoardState({
    this.columns = const [],
    this.isLoading = false,
    this.error,
  });

  final List<ColumnModel> columns;
  final bool isLoading;
  final String? error;

  BoardState copyWith({
    List<ColumnModel>? columns,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return BoardState(
      columns: columns ?? this.columns,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final boardProvider = StateNotifierProvider<BoardViewModel, BoardState>((ref) {
  return BoardViewModel(KanbanService.instance);
});

class BoardViewModel extends StateNotifier<BoardState> {
  BoardViewModel(this._service) : super(const BoardState());

  final KanbanService _service;

  Future<void> fetchBoard() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final columns = await _service.getBoard();
      state = state.copyWith(isLoading: false, columns: columns);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> createTask(
    String title,
    int columnId,
    String description,
    BuildContext context,
  ) async {
    try {
      final task = await _service.createTask(title, columnId, description);
      state = state.copyWith(
        columns: state.columns.map((column) {
          if (column.id != columnId) {
            return column;
          }
          return column.copyWith(tasks: [...column.tasks, task]);
        }).toList(),
      );
    } catch (error) {
      _showMessage(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> moveTaskOptimistic(
    int taskId,
    int targetColumnId,
    int targetOrder,
    BuildContext context,
  ) async {
    final previousColumns = _cloneColumns(state.columns);
    state = state.copyWith(
      columns: _applyMoveLocally(state.columns, taskId, targetColumnId, targetOrder),
    );

    try {
      await _service.moveTask(taskId, targetColumnId, targetOrder);
      await fetchBoard();
    } catch (_) {
      state = state.copyWith(columns: previousColumns);
      _showMessage(context, 'Erro de sincronização. Alteração revertida.');
    }
  }

  Future<void> deleteTask(
    int taskId,
    int columnId,
    BuildContext context,
  ) async {
    final previousColumns = _cloneColumns(state.columns);
    state = state.copyWith(
      columns: state.columns.map((column) {
        if (column.id != columnId) {
          return column;
        }
        final tasks = column.tasks.where((task) => task.id != taskId).toList();
        return column.copyWith(tasks: _reorder(tasks));
      }).toList(),
    );

    try {
      await _service.deleteTask(taskId);
    } catch (_) {
      state = state.copyWith(columns: previousColumns);
      _showMessage(context, 'Erro ao deletar tarefa. Alteração revertida.');
    }
  }

  List<ColumnModel> _applyMoveLocally(
    List<ColumnModel> columns,
    int taskId,
    int targetColumnId,
    int targetOrder,
  ) {
    TaskModel? taskToMove;
    final withoutTask = columns.map((column) {
      final nextTasks = <TaskModel>[];
      for (final task in column.tasks) {
        if (task.id == taskId) {
          taskToMove = task;
        } else {
          nextTasks.add(task);
        }
      }
      return column.copyWith(tasks: _reorder(nextTasks));
    }).toList();

    if (taskToMove == null) {
      return columns;
    }

    return withoutTask.map((column) {
      if (column.id != targetColumnId) {
        return column;
      }
      final tasks = [...column.tasks];
      final boundedOrder = targetOrder.clamp(0, tasks.length).toInt();
      tasks.insert(
        boundedOrder,
        taskToMove!.copyWith(columnId: targetColumnId, order: boundedOrder),
      );
      return column.copyWith(tasks: _reorder(tasks));
    }).toList();
  }

  List<TaskModel> _reorder(List<TaskModel> tasks) {
    return [
      for (var index = 0; index < tasks.length; index++)
        tasks[index].copyWith(order: index),
    ];
  }

  List<ColumnModel> _cloneColumns(List<ColumnModel> columns) {
    return [
      for (final column in columns)
        column.copyWith(tasks: [for (final task in column.tasks) task.copyWith()]),
    ];
  }

  void _showMessage(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
