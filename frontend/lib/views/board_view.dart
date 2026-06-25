import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/column_model.dart';
import '../models/task_model.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/board_view_model.dart';

class BoardView extends ConsumerStatefulWidget {
  const BoardView({super.key});

  @override
  ConsumerState<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends ConsumerState<BoardView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(boardProvider.notifier).fetchBoard());
  }

  @override
  Widget build(BuildContext context) {
    final boardState = ref.watch(boardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(boardProvider.notifier).fetchBoard(),
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(context),
          ),
        ],
      ),
      body: _body(boardState),
      floatingActionButton: FloatingActionButton(
        onPressed: boardState.columns.isEmpty
            ? null
            : () => _showCreateTaskDialog(boardState.columns),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _body(BoardState state) {
    if (state.isLoading && state.columns.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.columns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(state.error!, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      itemCount: state.columns.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        return _ColumnWidget(column: state.columns[index]);
      },
    );
  }

  Future<void> _showCreateTaskDialog(List<ColumnModel> columns) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var selectedColumnId = columns.first.id;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nova tarefa'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedColumnId,
                      decoration: const InputDecoration(
                        labelText: 'Lista',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final column in columns)
                          DropdownMenuItem(
                            value: column.id,
                            child: Text(column.title),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedColumnId = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      return;
                    }
                    Navigator.pop(dialogContext);
                    await ref.read(boardProvider.notifier).createTask(
                          title,
                          selectedColumnId,
                          descriptionController.text.trim(),
                          context,
                        );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Criar'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
  }
}

class _ColumnWidget extends ConsumerWidget {
  const _ColumnWidget({required this.column});

  final ColumnModel column;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<TaskModel>(
      onAcceptWithDetails: (details) {
        ref.read(boardProvider.notifier).moveTaskOptimistic(
              details.data.id,
              column.id,
              column.tasks.length,
              context,
            );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 300,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isHovering
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      column.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(label: Text(column.tasks.length.toString())),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: column.tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return DragTarget<TaskModel>(
                      onAcceptWithDetails: (details) {
                        ref.read(boardProvider.notifier).moveTaskOptimistic(
                              details.data.id,
                              column.id,
                              index,
                              context,
                            );
                      },
                      builder: (context, candidateData, rejectedData) {
                        return _TaskCard(task: column.tasks[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateFormat('dd/MM/yyyy HH:mm').format(task.updatedAt.toLocal());

    final card = Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onLongPress: () => _showOptions(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: Theme.of(context).textTheme.titleSmall),
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(task.description),
              ],
              const SizedBox(height: 8),
              Text(
                date,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );

    return LongPressDraggable<TaskModel>(
      data: task,
      feedback: SizedBox(
        width: 280,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Opacity(opacity: 0.9, child: card),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  Future<void> _showOptions(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Excluir'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ref.read(boardProvider.notifier).deleteTask(
                        task.id,
                        task.columnId,
                        context,
                      );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
