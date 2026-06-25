import 'task_model.dart';

class ColumnModel {
  const ColumnModel({
    required this.id,
    required this.title,
    required this.order,
    required this.tasks,
  });

  final int id;
  final String title;
  final int order;
  final List<TaskModel> tasks;

  factory ColumnModel.fromJson(Map<String, dynamic> json) {
    return ColumnModel(
      id: json['id'] as int,
      title: json['title'] as String,
      order: json['order'] as int,
      tasks: ((json['tasks'] as List<dynamic>?) ?? [])
          .map((task) => TaskModel.fromJson(task as Map<String, dynamic>))
          .toList(),
    );
  }

  ColumnModel copyWith({List<TaskModel>? tasks}) {
    return ColumnModel(
      id: id,
      title: title,
      order: order,
      tasks: tasks ?? this.tasks,
    );
  }
}
