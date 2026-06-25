set dotenv-load := false

app_env := env_var_or_default("APP_ENV", "dev")
python := ".venv/bin/python"
pip := ".venv/bin/pip"

default:
    just --list

setup: backend-install frontend-install

backend-install:
    python3 -m venv .venv
    {{pip}} install -r backend/requirements.txt

frontend-install:
    cd frontend && flutter pub get

backend-run:
    cd backend && APP_ENV={{app_env}} ../{{python}} app.py

backend-test:
    cd backend && APP_ENV=test ../{{python}} -m pytest

backend-smoke:
    cd backend && APP_ENV=test PYTHONPATH=. ../{{python}} ../scripts/backend_smoke.py

frontend-run:
    cd frontend && flutter run

frontend-analyze:
    cd frontend && flutter analyze

format:
    cd frontend && dart format lib

clean:
    rm -rf .venv backend/__pycache__ backend/routes/__pycache__ frontend/build frontend/.dart_tool

env-dev:
    cp backend/.env.dev backend/.env

env-prod:
    cp backend/.env.prod backend/.env
