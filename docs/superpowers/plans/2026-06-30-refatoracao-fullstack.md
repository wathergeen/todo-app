# Refatoracao Fullstack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplificar e modularizar backend Flask e frontend Flutter, removendo duplicidades e adicionando cache/job/fila leves sem alterar requisitos funcionais.

**Architecture:** O backend continua com Flask, blueprints e SQLAlchemy, mas move regras puras para serviços/helpers testáveis. O cache fica em memória por usuário para o board e é invalidado nas mutações; a fila local executa jobs simples em background quando a app não está em teste. O frontend mantém Riverpod/Dio e extrai lógica pura de board para arquivo próprio.

**Tech Stack:** Python 3.12, Flask, SQLAlchemy, pytest, Flutter/Dart, Riverpod, Dio, flutter_test.

---

### Task 1: Baseline de testes backend

**Files:**
- Create: `backend/tests/conftest.py`
- Create: `backend/tests/test_api_contract.py`
- Create: `backend/pytest.ini`

- [ ] Criar fixtures de app Flask, banco em memória, colunas padrão, cliente autenticado e helper de tarefas.
- [ ] Adicionar testes de contrato para registro/login, board, criação, movimentação e exclusão.
- [ ] Rodar `just backend-test` e confirmar a falha ou sucesso inicial da suíte.
- [ ] Corrigir apenas problemas necessários para estabilizar o contrato existente.
- [ ] Rodar `just backend-test` e `just backend-smoke`.

### Task 2: Serviços backend, cache e fila local

**Files:**
- Create: `backend/services/__init__.py`
- Create: `backend/services/board_cache.py`
- Create: `backend/services/job_queue.py`
- Create: `backend/services/tasks_service.py`
- Modify: `backend/app.py`
- Modify: `backend/routes/tasks.py`

- [ ] Mover serialização e reordenação para `tasks_service.py`.
- [ ] Adicionar cache em memória para payload de board por usuário.
- [ ] Invalidar cache em criação, movimentação e exclusão.
- [ ] Adicionar fila/job local para tarefas internas leves, desabilitada nos testes.
- [ ] Rodar `just backend-test` e `just backend-smoke`; corrigir falhas antes de avançar.

### Task 3: Testes e refatoração frontend

**Files:**
- Create: `frontend/test/models_test.dart`
- Create: `frontend/test/board_logic_test.dart`
- Create: `frontend/lib/view_models/board_logic.dart`
- Modify: `frontend/lib/view_models/board_view_model.dart`
- Modify: `frontend/lib/services/kanban_service.dart`

- [ ] Criar testes de parsing dos modelos e da reordenação local do board.
- [ ] Extrair `_applyMoveLocally`, `_reorder` e clone para `board_logic.dart`.
- [ ] Centralizar normalização de erro do frontend sem mudar textos exibidos.
- [ ] Rodar `cd frontend && flutter test`.
- [ ] Rodar `just frontend-analyze`; corrigir falhas.

### Task 4: Documentação e dependências

**Files:**
- Modify: `requirements.txt`
- Modify: `backend/requirements.txt`
- Modify: `README.md`
- Create: `refactor.md`

- [ ] Alinhar `requirements.txt` raiz e backend.
- [ ] Documentar arquitetura, cache/fila, comandos de teste e limitações.
- [ ] Registrar relatório detalhado em `refactor.md`.
- [ ] Rodar a verificação final: `just backend-test`, `just backend-smoke`, `cd frontend && flutter test`, `just frontend-analyze`.
