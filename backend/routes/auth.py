from flask import Blueprint, jsonify, request
from flask_jwt_extended import create_access_token

from models import User, bcrypt, db


auth_bp = Blueprint("auth", __name__)


@auth_bp.post("/register")
def register():
    data = request.get_json(silent=True) or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""

    if len(username) < 3:
        return jsonify({"error": "username inválido"}), 400
    if len(password) < 6:
        return jsonify({"error": "password inválido"}), 400
    if User.query.filter_by(username=username).first():
        return jsonify({"error": "username já cadastrado"}), 409

    password_hash = bcrypt.generate_password_hash(password).decode("utf-8")
    user = User(username=username, password_hash=password_hash)
    db.session.add(user)
    db.session.commit()

    return jsonify({"message": "Usuário criado com sucesso", "user_id": user.id}), 201


@auth_bp.post("/login")
def login():
    data = request.get_json(silent=True) or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""

    if not username or not password:
        return jsonify({"error": "Campos obrigatórios ausentes"}), 400

    user = User.query.filter_by(username=username).first()
    if user is None or not bcrypt.check_password_hash(user.password_hash, password):
        return jsonify({"error": "Credenciais inválidas"}), 401

    token = create_access_token(identity=str(user.id))
    return jsonify({"access_token": token}), 200
