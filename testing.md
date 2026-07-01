# Plano de Testes — Sistema Todo List
**Metodologia:** TDD First (Red → Green → Refactor)
**Escopo:** backend Flask neste arquivo; frontend Flutter em `doc/testing.md`.

Para testes de interface, responsividade, acessibilidade, renderização condicional,
integração com APIs, E2E manual, regressão visual e estados de loading/skeleton/error,
usar `doc/testing.md`.

---

## 1. Estratégia Geral

Cada endpoint/regra de negócio descrito na especificação será implementado seguindo
o ciclo clássico de TDD:

1. **Red** — escrever o teste que descreve o comportamento esperado (deve falhar, pois a
   implementação ainda não existe).
2. **Green** — implementar o mínimo de código em `models.py` / `routes/*.py` para o teste passar.
3. **Refactor** — limpar a implementação mantendo a suíte verde.

Nenhum endpoint é considerado "concluído" sem teste associado. A suíte completa roda
em todo `push`/`pull_request` (ver seção 8) e atua como **guarda de regressão**: qualquer
alteração futura em `routes/tasks.py` (ex.: lógica de reordenação) que quebre um
contrato já validado falha o pipeline antes do merge.

### Pirâmide de testes adotada

| Camada | O que cobre | Ferramenta | Proporção aproximada |
|---|---|---|---|
| Unitário | Modelos (`models.py`), validações isoladas, helpers | `pytest` puro | ~40% |
| Integração | Rotas Flask completas (request → resposta HTTP → estado no banco) | `pytest-flask` + cliente de teste | ~55% |
| Configuração/Contrato | `config.py` (variáveis de ambiente obrigatórias) | `pytest` + `monkeypatch` | ~5% |

Não há testes E2E neste plano porque o front-end Flutter é desacoplado e versionado em
módulo separado — a integração real é validada manualmente/contrato (ver seção 9).

---

## 2. Estrutura de Diretórios de Teste

```
backend/
├── app.py
├── config.py
├── models.py
├── routes/
│   ├── auth.py
│   └── tasks.py
├── tests/
│   ├── conftest.py              # fixtures globais (app, client, db, factories, auth_headers)
│   ├── factories.py             # UserFactory, ColumnFactory, TaskFactory (factory-boy)
│   ├── unit/
│   │   ├── test_models.py
│   │   └── test_config.py
│   └── integration/
│       ├── test_auth_routes.py
│       ├── test_board_route.py
│       ├── test_tasks_create.py
│       ├── test_tasks_patch_reorder.py
│       └── test_tasks_delete.py
├── pytest.ini
└── requirements.txt
```

`pytest.ini` sugerido:
```ini
[pytest]
testpaths = tests
addopts = -v --cov=. --cov-report=term-missing --cov-report=xml --cov-fail-under=85
```

---

## 3. Fixtures Base (`conftest.py`)

Banco de testes: **SQLite em memória**, recriado a cada teste (`function`-scoped) para
garantir isolamento total — nenhum teste depende de estado deixado por outro.

```python
import pytest
from app import create_app
from models import db, User, Column

@pytest.fixture
def app():
    app = create_app(testing=True)
    app.config.update(
        SQLALCHEMY_DATABASE_URI="sqlite:///:memory:",
        TESTING=True,
        JWT_SECRET_KEY="test-secret",
    )
    with app.app_context():
        db.create_all()
        yield app
        db.drop_all()

@pytest.fixture
def client(app):
    return app.test_client()

@pytest.fixture
def default_columns(app):
    cols = [Column(title="A Fazer", order=0),
            Column(title="Em Progresso", order=1),
            Column(title="Concluído", order=2)]
    db.session.add_all(cols)
    db.session.commit()
    return cols

@pytest.fixture
def auth_headers(client):
    client.post("/api/register", json={"username": "joaosilva", "password": "senha123"})
    resp = client.post("/api/login", json={"username": "joaosilva", "password": "senha123"})
    token = resp.get_json()["access_token"]
    return {"Authorization": f"Bearer {token}"}
```

> **Observação de arquitetura:** isso pressupõe uma factory `create_app()` em `app.py`
> em vez de instância global — necessário para que cada teste suba uma app isolada
> com config própria. Se `app.py` for implementado como instância única no módulo,
> este é o primeiro ajuste exigido pelo TDD (o teste de fixture nasce antes do código).

---

## 4. Casos de Teste por Funcionalidade

Prioridade: **P0 (Crítico)** = bloqueia release · **P1 (Alto)** · **P2 (Médio)**

### 4.1 `config.py`

| ID | Cenário | Tipo | Prioridade |
|---|---|---|---|
| CFG-01 | `JWT_SECRET_KEY` ausente no ambiente → levanta exceção na inicialização | Unit | P0 |
| CFG-02 | `FLASK_DEBUG` ausente → `DEBUG` assume `False` por padrão | Unit | P2 |

### 4.2 `models.py`

| ID | Cenário | Tipo | Prioridade |
|---|---|---|---|
| MOD-01 | Criar dois `User` com `username` igual → `IntegrityError` (constraint única) | Unit | P0 |
| MOD-02 | `Task.created_at`/`updated_at` recebem `datetime.utcnow()` por padrão | Unit (`freezegun`) | P1 |
| MOD-03 | `Column.tasks` retorna ordenado por `Task.order` | Unit | P2 |

### 4.3 `POST /api/register`

| ID | Cenário | Prioridade |
|---|---|---|
| REG-01 | Payload válido → `201`, usuário persistido, `password_hash` ≠ senha em texto puro | **P0** |
| REG-02 | `username` com menos de 3 caracteres → `400` | **P0** |
| REG-03 | `password` com menos de 6 caracteres → `400` | **P0** |
| REG-04 | `username` já existente → `409` | **P0** |
| REG-05 | `username`/`password` ausentes do payload → `400` (não `500`) | P1 |

### 4.4 `POST /api/login`

| ID | Cenário | Prioridade |
|---|---|---|
| LOG-01 | Credenciais corretas → `200` + `access_token` presente e decodificável | **P0** |
| LOG-02 | Usuário inexistente → `401` (mesma mensagem genérica de LOG-03, sem enumeração de usuários) | **P0** |
| LOG-03 | Senha incorreta → `401` | **P0** |
| LOG-04 | Campos ausentes → `400` | P1 |
| LOG-05 | Token gerado tem `identity == str(user.id)` (assert via decode do JWT) | P1 |

### 4.5 `GET /api/board`

| ID | Cenário | Prioridade |
|---|---|---|
| BOARD-01 | Sem header `Authorization` → `401` | **P0** |
| BOARD-02 | Token válido → `200` com colunas ordenadas por `order` e tarefas aninhadas ordenadas por `order` | **P0** |
| BOARD-03 | **Isolamento multi-usuário**: tarefas do usuário B não aparecem no board do usuário A | **P0** (segurança) |
| BOARD-04 | Campos `created_at`/`updated_at` no formato ISO 8601 UTC (`...T...Z`) | P1 |
| BOARD-05 | Coluna sem tarefas retorna `"tasks": []` (não omite a coluna) | P2 |

### 4.6 `POST /api/tasks`

| ID | Cenário | Prioridade |
|---|---|---|
| TC-01 | Payload válido → `201`, `order` calculado como `max(order na coluna) + 1` | **P0** |
| TC-02 | Primeira tarefa de uma coluna vazia → `order == 0` | **P0** |
| TC-03 | `title` ausente ou string vazia/whitespace → `400` | **P0** |
| TC-04 | `column_id` ausente → `400` | **P0** |
| TC-05 | `column_id` inexistente → `404` | **P0** |
| TC-06 | `description` ausente no payload → persistida como string vazia | P2 |
| TC-07 | Sem token → `401` | **P0** |
| TC-08 | `order` calculado é isolado por `user_id` (duas pessoas na mesma coluna não colidem de ordem) | P1 |

### 4.7 `PATCH /api/tasks/<id>` — núcleo crítico do sistema

Esta é a regra de negócio de maior risco (reordenação com efeitos colaterais em
registros vizinhos) e recebe a maior densidade de testes.

| ID | Cenário | Prioridade |
|---|---|---|
| PATCH-01 | Tarefa não existe ou pertence a outro usuário → `404` | **P0** |
| PATCH-02 | `column_id` ou `order` ausentes no payload → `400` | **P0** |
| PATCH-03 | `order` negativo → `400` | **P0** |
| PATCH-04 | `column_id` de destino inexistente → `404` | **P0** |
| PATCH-05 | Reordenar dentro da mesma coluna (mover do meio para o topo): tarefas entre a posição antiga e a nova são reindexadas em ±1, sem colisão de `order` | **P0** |
| PATCH-06 | Mover entre colunas: coluna de origem fecha a lacuna (`order -= 1` nos posteriores), coluna de destino abre espaço (`order += 1` nos posteriores/iguais) | **P0** |
| PATCH-07 | Mover para o final da coluna destino (`order == len(tasks_destino)`) — não deve gerar furo nem duplicar `order` | P1 |
| PATCH-08 | Atomicidade: se o commit falhar a meio da operação (mock de `db.session.commit` lançando exceção), nenhuma alteração parcial é persistida | **P0** |
| PATCH-09 | `updated_at` é atualizado após o PATCH (`freezegun` fixa o "antes" e o "depois") | P1 |
| PATCH-10 | Sem token → `401` | **P0** |
| PATCH-11 | Usuário tenta mover tarefa de outro usuário → `404` (não `403`, conforme contrato) | **P0** (segurança) |

> **Teste de regressão obrigatório (PATCH-05/06):** após qualquer reordenação, a
> invariante `{0, 1, ..., n-1}` sem duplicatas e sem lacunas deve valer para **todas**
> as colunas envolvidas — não apenas para a tarefa movida. Sugestão de assertion
> helper reutilizável:
> ```python
> def assert_orders_are_contiguous(column_id, user_id):
>     orders = [t.order for t in Task.query.filter_by(
>         column_id=column_id, user_id=user_id).order_by(Task.order).all()]
>     assert orders == list(range(len(orders)))
> ```

### 4.8 `DELETE /api/tasks/<id>`

| ID | Cenário | Prioridade |
|---|---|---|
| DEL-01 | Exclusão válida → `200`, registro removido do banco | **P0** |
| DEL-02 | Tarefa inexistente/de outro usuário → `404` | **P0** |
| DEL-03 | Vizinhos posteriores na mesma coluna são reindexados (`order -= 1`), sem lacunas | **P0** |
| DEL-04 | Sem token → `401` | **P0** |

### 4.9 Cross-cutting — Segurança e Autenticação

| ID | Cenário | Prioridade |
|---|---|---|
| SEC-01 | Token JWT expirado → `401` em qualquer rota protegida | P1 |
| SEC-02 | Token malformado/assinatura inválida → `401` | P1 |
| SEC-03 | Senha nunca retornada em nenhum payload de resposta (register, login, board) | **P0** |

---

## 5. Estratégia de Mocks

Mocks isolam a unidade testada de dependências externas/custosas ou de
não-determinismo, conforme a tabela abaixo:

| Dependência | Quando mockar | Como | Justificativa |
|---|---|---|---|
| `datetime.utcnow()` | Testes de `created_at`/`updated_at` | `freezegun.freeze_time("2026-06-22T12:00:00Z")` | Resultado determinístico, evita asserts com tolerância de tempo |
| `db.session.commit()` | Teste de atomicidade (PATCH-08) | `mocker.patch("models.db.session.commit", side_effect=SQLAlchemyError)` | Simula falha de infraestrutura sem precisar corromper o banco real |
| `bcrypt.check_password_hash` | Testes de rota de login quando o foco é o fluxo HTTP, não a criptografia | `mocker.patch.object(bcrypt, "check_password_hash", return_value=True)` | Acelera testes e isola a lógica de roteamento da lógica de hashing |
| `create_access_token` / `get_jwt_identity` | Testes unitários de helpers que dependem de identidade, sem subir o fluxo de login completo | `mocker.patch("flask_jwt_extended.get_jwt_identity", return_value="1")` | Reduz acoplamento e setup repetitivo |

**Regra prática:** testes de **integração** (rota completa) usam bcrypt e JWT reais
— eles validam o contrato HTTP de ponta a ponta. Mocks de criptografia/JWT ficam
reservados a testes **unitários** que focam exclusivamente em lógica de negócio
(ex.: cálculo de `order`), evitando que a suíte vire uma "verdade mockada" que não
reflete o comportamento real do sistema.

---

## 6. Cobertura de Código e Métricas de Qualidade

- Ferramenta: `pytest-cov` (relatório `term-missing` local + `coverage.xml` no CI).
- **Meta mínima global:** 85% (`--cov-fail-under=85` no `pytest.ini`, falha o build abaixo disso).
- **Meta para `routes/tasks.py` (PATCH/DELETE):** 100% das branches de reordenação —
  é a lógica de maior risco de regressão silenciosa.
- Relatório de cobertura publicado como artefato do CI (ver seção 8) para visibilidade
  em PRs.

---

## 7. Dados de Teste (Factories)

Para evitar fixtures hardcoded e reduzir duplicação, usar `factory-boy`:

```python
# tests/factories.py
import factory
from models import db, User, Column, Task

class UserFactory(factory.alchemy.SQLAlchemyModelFactory):
    class Meta:
        model = User
        sqlalchemy_session = db.session
    username = factory.Sequence(lambda n: f"user{n}")
    password_hash = factory.LazyFunction(lambda: "hash-fake")

class ColumnFactory(factory.alchemy.SQLAlchemyModelFactory):
    class Meta:
        model = Column
        sqlalchemy_session = db.session
    title = "A Fazer"
    order = factory.Sequence(lambda n: n)

class TaskFactory(factory.alchemy.SQLAlchemyModelFactory):
    class Meta:
        model = Task
        sqlalchemy_session = db.session
    title = factory.Sequence(lambda n: f"Tarefa {n}")
    order = factory.Sequence(lambda n: n)
    column = factory.SubFactory(ColumnFactory)
```

---

## 8. Integração com CI/CD (GitHub Actions + Docker)

A suíte roda **dentro do mesmo ambiente Docker usado em produção** (mesma imagem base
`python:3.11-slim`), garantindo paridade dev/CI/prod conforme a Descrição Preliminar
do projeto.

`.github/workflows/backend-tests.yml` (proposta):

```yaml
name: Backend Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend
    steps:
      - uses: actions/checkout@v4

      - name: Build imagem Docker (mesma do runtime)
        run: docker build -t todo-backend:test .

      - name: Executar suíte de testes dentro do container
        run: |
          docker run --rm \
            -e JWT_SECRET_KEY=ci-test-secret \
            -e FLASK_DEBUG=False \
            -v ${{ github.workspace }}/backend:/app \
            todo-backend:test \
            pytest

      - name: Publicar relatório de cobertura
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: backend/coverage.xml
```

**Política de gate de merge:** o job `test` é marcado como *required status check* na
branch `main`/`develop` — nenhum PR é mesclado com a suíte vermelha ou com cobertura
abaixo do limiar definido na seção 6.

---

## 9. Fora de Escopo / Validação Complementar

- **Testes E2E mobile↔API:** não cobertos por `pytest`; validados via testes de
  widget/integration do Flutter (`flutter_test`) contra o board já testado aqui,
  ou via contrato (coleção Postman/Insomnia versionada) — pode ser adicionado
  como item futuro deste plano se necessário.
- **Teste de carga/performance:** fora do escopo deste plano funcional; recomenda-se
  avaliação futura com `locust` caso o volume de usuários justifique.

---

## 10. Checklist de Execução TDD por Funcionalidade

Para cada item da seção 4, o fluxo de trabalho obrigatório é:

- [ ] Escrever o teste (estado **Red**: falha por `ImportError`/`AssertionError`/`404` inesperado)
- [ ] Implementar o mínimo necessário em `models.py`/`routes/*.py` (estado **Green**)
- [ ] Rodar a suíte completa localmente (`pytest`) — nenhuma regressão em testes já verdes
- [ ] Refatorar se necessário, mantendo a suíte verde
- [ ] Commit com teste + implementação juntos (nunca implementação sem teste correspondente)
- [ ] PR só é aberto com o job de CI (seção 8) verde
