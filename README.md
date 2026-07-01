# Todo List

Monorepo com API Flask em `backend/` e aplicativo Flutter em `frontend/`.

## Ambiente

```bash
mise install
just setup
```

O arquivo `.mise.toml` padroniza Python 3.12, Flutter stable, Just e o virtualenv `.venv`.

## Variáveis de ambiente

O backend carrega `backend/.env.dev` por padrão. Para produção, rode com `APP_ENV=prod`.

Arquivos disponíveis:

- `backend/.env.dev`: desenvolvimento local
- `backend/.env.prod`: base de produção, troque a chave antes de usar
- `backend/.env.example`: modelo para novos ambientes
- `backend/.env`: override local opcional, ignorado pelo Git

## Comandos

```bash
just backend-run      # API em http://localhost:5000
just backend-smoke    # teste rápido da API
just backend-test     # pytest
cd backend && APP_ENV=test ../.venv/bin/python -m pytest
cd backend && APP_ENV=test PYTHONPATH=. ../.venv/bin/python ../scripts/backend_smoke.py
just frontend-run     # app Flutter
just frontend-analyze # análise estática Flutter
cd frontend && flutter test
cd frontend && flutter test test/views_test.dart
```

Se `just` não estiver instalado, use os comandos equivalentes acima.

## Arquitetura

O backend mantém Flask, blueprints e SQLAlchemy. As rotas de tarefas delegam regras de
negócio para `backend/services/tasks_service.py`, que centraliza serialização,
validação simples e reordenação. A leitura do board usa cache em memória por usuário
em `backend/services/board_cache.py`; mutações de tarefas invalidam o cache e
enfileiram um job local para reaquecer os dados.

A fila em `backend/services/job_queue.py` usa somente a biblioteca padrão do Python:
em produção/desenvolvimento ela processa jobs em uma thread daemon; em testes, executa
imediatamente para manter a suíte determinística. Não há dependência de Redis/Celery
porque o projeto atual não exige processamento distribuído.

No Flutter, a lógica pura de movimentação local do board fica em
`frontend/lib/view_models/board_logic.dart`, com testes em `frontend/test/`.

## Testes

O plano de testes backend permanece em `testing.md`. O plano de testes de interface
Flutter, incluindo cenários responsivos, acessibilidade, renderização condicional,
integração com APIs, E2E manual, regressão visual e estados de loading/error/fallback,
fica em `doc/testing.md`.

## Flutter Android

Abra a pasta `frontend/` no Android Studio com o plugin Flutter instalado. Em seguida rode:

```bash
flutter pub get
flutter run
```

No emulador Android, o app usa `http://10.0.2.2:5000/api`, que aponta para o backend rodando no `localhost` da máquina.

Se o Gradle pedir `local.properties`, o Flutter/Android Studio normalmente cria o arquivo automaticamente. O conteúdo esperado é:

```properties
flutter.sdk=/caminho/para/flutter
```
