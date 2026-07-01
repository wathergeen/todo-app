# Relatório de Refatoração

Data: 2026-06-30

## Objetivo

Simplificar e modularizar o projeto Todo List, reduzir duplicidades e adicionar cache,
fila e jobs leves conforme a arquitetura existente, sem inferir novos requisitos de
produto.

## Etapa 1 - Testes backend

- Criado `backend/pytest.ini`.
- Criadas fixtures isoladas em `backend/tests/conftest.py`.
- Criada suíte `backend/tests/test_api_contract.py` cobrindo:
  - registro e login;
  - board com isolamento entre usuários;
  - criação de tarefas;
  - cache aquecido após mutação;
  - movimentação entre colunas com ordens contíguas;
  - exclusão com reordenação.

Verificação executada:

```bash
cd backend && APP_ENV=test ../.venv/bin/python -m pytest
cd backend && APP_ENV=test PYTHONPATH=. ../.venv/bin/python ../scripts/backend_smoke.py
```

Resultado: 6 testes passaram e o smoke retornou `backend smoke ok`.

## Etapa 2 - Backend

- Criado `backend/services/tasks_service.py` para centralizar regras de tarefas,
  serialização, validações e reordenação.
- Criado `backend/services/board_cache.py` com cache em memória por usuário.
- Criado `backend/services/job_queue.py` com fila local:
  - execução em thread daemon fora de testes;
  - execução imediata em testes.
- Adicionado `JOB_QUEUE_ASYNC` em `backend/config.py` para controlar a execução
  assíncrona da fila por ambiente.
- `backend/routes/tasks.py` foi reduzido para adaptação HTTP.
- `backend/app.py` inicializa a fila no ciclo de criação da aplicação.
- Reordenação passou a usar updates em lote do SQLAlchemy, reduzindo loops Python
  sobre tarefas vizinhas.

## Etapa 3 - Frontend

- Criado `frontend/lib/view_models/board_logic.dart` com lógica pura de:
  - movimentação local otimista;
  - reordenação;
  - clonagem de colunas/tarefas.
- Criado `frontend/lib/view_models/error_message.dart` para normalização centralizada
  de mensagens de erro.
- `BoardViewModel` e `AuthViewModel` foram simplificados.
- Criados testes:
  - `frontend/test/models_test.dart`;
  - `frontend/test/board_logic_test.dart`.

## Dependências

Nenhuma dependência runtime nova foi adicionada. Cache, jobs e fila usam a biblioteca
padrão do Python. `requirements.txt` e `backend/requirements.txt` foram alinhados com
dependências runtime e de teste.

## Limitações de verificação

O comando `just` não está instalado no ambiente atual. Os comandos backend equivalentes
foram executados diretamente.

Os comandos Flutter não chegaram a iniciar porque o SDK local em
`/mnt/c/Users/wather/develop/flutter` falha com:

```text
/mnt/c/Users/wather/develop/flutter/bin/internal/shared.sh: line 5: $'\r': command not found
```

Isso indica problema de final de linha CRLF no SDK externo ao repositório. Os arquivos
Dart alterados foram revisados por leitura, mas `flutter test`, `flutter analyze` e
`dart format` precisam ser reexecutados após corrigir o SDK Flutter local.
