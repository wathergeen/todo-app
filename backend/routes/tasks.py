from datetime import datetime

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy import func

from models import Column, Task, db


tasks_bp = Blueprint("tasks", __name__)


def ensure_default_columns():
    if Column.query.count() > 0:
        return
    db.session.add_all(
        [
            Column(title="A Fazer", order=0),
            Column(title="Em Progresso", order=1),
            Column(title="Concluído", order=2),
        ]
    )
    db.session.commit()


def _iso_utc(value):
    return value.replace(microsecond=0).isoformat() + "Z"


def _serialize_task(task):
    return {
        "id": task.id,
        "title": task.title,
        "description": task.description or "",
        "order": task.order,
        "column_id": task.column_id,
        "created_at": _iso_utc(task.created_at),
        "updated_at": _iso_utc(task.updated_at),
    }


@tasks_bp.get("/board")
@jwt_required()
def get_board():
    user_id = int(get_jwt_identity())
    columns = Column.query.order_by(Column.order).all()
    payload = []

    for column in columns:
        tasks = (
            Task.query.filter_by(column_id=column.id, user_id=user_id)
            .order_by(Task.order)
            .all()
        )
        payload.append(
            {
                "id": column.id,
                "title": column.title,
                "order": column.order,
                "tasks": [_serialize_task(task) for task in tasks],
            }
        )

    return jsonify({"columns": payload}), 200


@tasks_bp.post("/tasks")
@jwt_required()
def create_task():
    user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}
    title = (data.get("title") or "").strip()
    column_id = data.get("column_id")

    if not title:
        return jsonify({"error": "title obrigatório"}), 400
    if column_id is None:
        return jsonify({"error": "column_id obrigatório"}), 400
    if db.session.get(Column, column_id) is None:
        return jsonify({"error": "Coluna não encontrada"}), 404

    max_order = (
        db.session.query(func.max(Task.order))
        .filter_by(column_id=column_id, user_id=user_id)
        .scalar()
    )
    now = datetime.utcnow()
    task = Task(
        title=title,
        description=data.get("description") or "",
        column_id=column_id,
        user_id=user_id,
        order=(max_order + 1) if max_order is not None else 0,
        created_at=now,
        updated_at=now,
    )
    db.session.add(task)
    db.session.commit()

    return jsonify(_serialize_task(task)), 201


@tasks_bp.patch("/tasks/<int:task_id>")
@jwt_required()
def update_task(task_id):
    user_id = int(get_jwt_identity())
    task = Task.query.filter_by(id=task_id, user_id=user_id).first()
    if task is None:
        return jsonify({"error": "Tarefa não encontrada"}), 404

    data = request.get_json(silent=True) or {}
    column_id = data.get("column_id")
    order = data.get("order")

    if column_id is None or order is None:
        return jsonify({"error": "column_id e order são obrigatórios"}), 400
    if order < 0:
        return jsonify({"error": "order não pode ser negativo"}), 400
    if db.session.get(Column, column_id) is None:
        return jsonify({"error": "Coluna não encontrada"}), 404

    source_column_id = task.column_id
    source_order = task.order
    destination_count = Task.query.filter_by(column_id=column_id, user_id=user_id).count()
    if source_column_id == column_id:
        order = min(order, max(destination_count - 1, 0))
        if order < source_order:
            neighbors = Task.query.filter(
                Task.column_id == column_id,
                Task.user_id == user_id,
                Task.id != task.id,
                Task.order >= order,
                Task.order < source_order,
            ).all()
            for neighbor in neighbors:
                neighbor.order += 1
        elif order > source_order:
            neighbors = Task.query.filter(
                Task.column_id == column_id,
                Task.user_id == user_id,
                Task.id != task.id,
                Task.order > source_order,
                Task.order <= order,
            ).all()
            for neighbor in neighbors:
                neighbor.order -= 1
    else:
        order = min(order, destination_count)
        source_neighbors = Task.query.filter(
            Task.column_id == source_column_id,
            Task.user_id == user_id,
            Task.order > source_order,
        ).all()
        for neighbor in source_neighbors:
            neighbor.order -= 1

        destination_neighbors = Task.query.filter(
            Task.column_id == column_id,
            Task.user_id == user_id,
            Task.order >= order,
        ).all()
        for neighbor in destination_neighbors:
            neighbor.order += 1

    task.column_id = column_id
    task.order = order
    task.updated_at = datetime.utcnow()
    db.session.commit()

    return jsonify(_serialize_task(task)), 200


@tasks_bp.delete("/tasks/<int:task_id>")
@jwt_required()
def delete_task(task_id):
    user_id = int(get_jwt_identity())
    task = Task.query.filter_by(id=task_id, user_id=user_id).first()
    if task is None:
        return jsonify({"error": "Tarefa não encontrada"}), 404

    column_id = task.column_id
    neighbors = Task.query.filter(
        Task.column_id == column_id,
        Task.user_id == user_id,
        Task.order > task.order,
    ).all()
    for neighbor in neighbors:
        neighbor.order -= 1
    db.session.delete(task)
    db.session.commit()

    return jsonify({"message": "Tarefa removida com sucesso"}), 200
