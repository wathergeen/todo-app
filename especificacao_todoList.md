# Especificação Técnica — Sistema Todo List
> Gerada a partir da Descrição Preliminar de Projeto  
> Padrão: Determinístico · Granular · Sem Ambiguidade

---

## Índice

1. [Back-end (Flask)](#backend)
2. [Front-end (Flutter)](#frontend)

---

## 1. Back-end (Flask) {#backend}

---

### `backend/Dockerfile`
- **Ação:** criar
- **Descrição:** Define o contêiner Docker para o servidor Flask com Python 3.x, instala dependências e expõe a porta 5000.

```pseudo
USE imagem base: python:3.11-slim
SET diretório de trabalho: /app
COPY requirements.txt → /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY . → /app
EXPOSE porta 5000
CMD ["python", "app.py"]
```

---

### `backend/requirements.txt`
- **Ação:** criar
- **Descrição:** Lista todas as dependências Python necessárias para executar o servidor Flask com autenticação e persistência SQLite.

```pseudo
LISTAR dependências:
  flask              # framework web
  flask-sqlalchemy   # ORM para SQLite
  flask-bcrypt       # hash de senhas
  flask-jwt-extended # geração e validação de tokens JWT
  python-dotenv      # leitura de variáveis de ambiente
```

---

### `backend/config.py`
- **Ação:** criar
- **Descrição:** Centraliza todos os parâmetros de configuração do servidor: caminho do banco de dados SQLite, chave secreta JWT e modo de debug.

```pseudo
CARREGAR variáveis de ambiente via dotenv

DEFINIR classe Config:
  SQLALCHEMY_DATABASE_URI = "sqlite:///todo.db"   # caminho relativo ao diretório /app
  JWT_SECRET_KEY          = LER env var "JWT_SECRET_KEY"
                            SE ausente: LANÇAR exceção com mensagem "JWT_SECRET_KEY não definida"
  DEBUG                   = LER env var "FLASK_DEBUG" como booleano (padrão: False)
  SQLALCHEMY_TRACK_MODIFICATIONS = False
```

---

### `backend/models.py`
- **Ação:** criar
- **Descrição:** Define as três entidades relacionais do sistema — `User`, `Column` e `Task` — mapeadas via SQLAlchemy para tabelas SQLite.

```pseudo
IMPORTAR db de app (instância SQLAlchemy)

DEFINIR modelo User:
  id           : INTEGER, chave primária, auto-incremento
  username     : VARCHAR(80), único, não nulo
  password_hash: VARCHAR(256), não nulo
  tasks        : relacionamento 1-N com Task (backref="owner")

DEFINIR modelo Column:
  id    : INTEGER, chave primária, auto-incremento
  title : VARCHAR(80), não nulo
  order : INTEGER, não nulo           # posição horizontal da coluna (0..n)
  tasks : relacionamento 1-N com Task (backref="column", order_by="Task.order")

DEFINIR modelo Task:
  id         : INTEGER, chave primária, auto-incremento
  title      : VARCHAR(200), não nulo
  description: TEXT, nullable
  order      : INTEGER, não nulo      # posição dentro da coluna (0..n)
  created_at : DATETIME, não nulo, padrão = datetime.utcnow()
  updated_at : DATETIME, não nulo, padrão = datetime.utcnow(), atualizado em cada SAVE
  column_id  : INTEGER, chave estrangeira → Column.id, não nulo
  user_id    : INTEGER, chave estrangeira → User.id, não nulo
```

---

### `backend/app.py`
- **Ação:** criar
- **Descrição:** Ponto de entrada do servidor. Inicializa Flask, registra extensões (SQLAlchemy, Bcrypt, JWT), registra os blueprints de rotas e cria o banco de dados na primeira execução.

```pseudo
CRIAR instância Flask: app

CARREGAR Config de config.py

INICIALIZAR extensões:
  db.init_app(app)
  bcrypt.init_app(app)
  jwt.init_app(app)

REGISTRAR blueprints:
  auth_bp  com prefixo "/api"    (de routes/auth.py)
  tasks_bp com prefixo "/api"    (de routes/tasks.py)

SE __name__ == "__main__":
  COM contexto app:
    db.create_all()   # cria tabelas se não existirem
  app.run(host="0.0.0.0", port=5000, debug=Config.DEBUG)
```

---

### `backend/routes/auth.py`
- **Ação:** criar
- **Descrição:** Blueprint com os endpoints de registro e login de usuários.

#### `POST /api/register`

```pseudo
RECEBER JSON: { "username": string, "password": string }

VALIDAR:
  SE username ausente OU len(username) < 3  → retornar 400 { "error": "username inválido" }
  SE password ausente OU len(password) < 6  → retornar 400 { "error": "password inválido" }
  SE User.query.filter_by(username=username).first() existe → retornar 409 { "error": "username já cadastrado" }

EXECUTAR:
  hash = bcrypt.generate_password_hash(password).decode("utf-8")
  user = User(username=username, password_hash=hash)
  db.session.add(user)
  db.session.commit()

RETORNAR 201 { "message": "Usuário criado com sucesso", "user_id": user.id }
```

#### `POST /api/login`

```pseudo
RECEBER JSON: { "username": string, "password": string }

VALIDAR:
  SE username ou password ausentes → retornar 400 { "error": "Campos obrigatórios ausentes" }

BUSCAR user = User.query.filter_by(username=username).first()

SE user é None OU bcrypt.check_password_hash(user.password_hash, password) é False:
  RETORNAR 401 { "error": "Credenciais inválidas" }

GERAR token = create_access_token(identity=str(user.id))

RETORNAR 200 { "access_token": token }
```

---

### `backend/routes/tasks.py`
- **Ação:** criar
- **Descrição:** Blueprint com os endpoints protegidos por JWT para leitura, criação, atualização e exclusão de tarefas.  
  Todas as rotas exigem header `Authorization: Bearer <token>`. Falha de autenticação retorna 401.

#### `GET /api/board`

```pseudo
OBTER user_id a partir do token JWT (get_jwt_identity())

BUSCAR colunas = Column.query.order_by(Column.order).all()

PARA cada coluna:
  BUSCAR tarefas = Task.query
    .filter_by(column_id=coluna.id, user_id=user_id)
    .order_by(Task.order)
    .all()
  SERIALIZAR tarefas como lista de objetos:
    { "id", "title", "description", "order", "column_id",
      "created_at" (ISO 8601 UTC), "updated_at" (ISO 8601 UTC) }

RETORNAR 200:
{
  "columns": [
    {
      "id": int,
      "title": string,
      "order": int,
      "tasks": [ { ... } ]
    },
    ...
  ]
}
```

#### `POST /api/tasks`

```pseudo
OBTER user_id a partir do token JWT

RECEBER JSON: { "title": string, "column_id": int, "description": string (opcional) }

VALIDAR:
  SE title ausente OU len(title.strip()) == 0 → retornar 400 { "error": "title obrigatório" }
  SE column_id ausente                         → retornar 400 { "error": "column_id obrigatório" }
  SE Column.query.get(column_id) é None        → retornar 404 { "error": "Coluna não encontrada" }

CALCULAR próxima ordem:
  max_order = db.session.query(func.max(Task.order))
    .filter_by(column_id=column_id, user_id=user_id)
    .scalar()
  order = (max_order + 1) SE max_order não é None, SENÃO 0

CRIAR task = Task(
  title       = title.strip(),
  description = description (ou ""),
  column_id   = column_id,
  user_id     = user_id,
  order       = order,
  created_at  = datetime.utcnow(),
  updated_at  = datetime.utcnow()
)
db.session.add(task)
db.session.commit()

RETORNAR 201 { "id", "title", "description", "order", "column_id", "created_at", "updated_at" }
```

#### `PATCH /api/tasks/<id>`

```pseudo
OBTER user_id a partir do token JWT

BUSCAR task = Task.query.filter_by(id=id, user_id=user_id).first()
SE task é None → retornar 404 { "error": "Tarefa não encontrada" }

RECEBER JSON: { "column_id": int, "order": int }

VALIDAR:
  SE column_id ausente OU order ausente      → retornar 400 { "error": "column_id e order são obrigatórios" }
  SE order < 0                               → retornar 400 { "error": "order não pode ser negativo" }
  SE Column.query.get(column_id) é None      → retornar 404 { "error": "Coluna não encontrada" }

INICIAR transação de banco de dados:

  # Remover lacuna na coluna de origem
  BUSCAR tarefas_origem = Task.query
    .filter(Task.column_id == task.column_id,
            Task.user_id   == user_id,
            Task.order     >  task.order,
            Task.id        != task.id)
    .all()
  PARA cada t em tarefas_origem: t.order -= 1

  # Abrir espaço na coluna de destino
  BUSCAR tarefas_destino = Task.query
    .filter(Task.column_id == column_id,
            Task.user_id   == user_id,
            Task.order     >= order,
            Task.id        != task.id)
    .all()
  PARA cada t em tarefas_destino: t.order += 1

  # Mover tarefa
  task.column_id = column_id
  task.order     = order
  task.updated_at = datetime.utcnow()

COMMIT transação

RETORNAR 200 { "id", "title", "description", "order", "column_id", "updated_at" }
```

#### `DELETE /api/tasks/<id>`

```pseudo
OBTER user_id a partir do token JWT

BUSCAR task = Task.query.filter_by(id=id, user_id=user_id).first()
SE task é None → retornar 404 { "error": "Tarefa não encontrada" }

INICIAR transação:
  # Fechar lacuna na coluna
  BUSCAR tarefas_vizinhas = Task.query
    .filter(Task.column_id == task.column_id,
            Task.user_id   == user_id,
            Task.order     >  task.order)
    .all()
  PARA cada t: t.order -= 1

  db.session.delete(task)
COMMIT transação

RETORNAR 200 { "message": "Tarefa removida com sucesso" }
```

---

### `backend/templates/` e `backend/static/`
- **Ação:** criar (estrutura mínima)
- **Descrição:** Diretório para templates Jinja2 e assets Bootstrap opcionais para painel interno de documentação. Não afeta endpoints da API.

```pseudo
CRIAR backend/templates/index.html:
  Renderizar lista de endpoints disponíveis (apenas para uso interno de desenvolvimento)

CRIAR backend/static/:
  Hospedar bootstrap.min.css e bootstrap.min.js (via CDN ou local)
```

---

## 2. Front-end (Flutter) {#frontend}

---

### `frontend/pubspec.yaml`
- **Ação:** criar
- **Descrição:** Declara o projeto Flutter e todas as dependências de terceiros necessárias.

```pseudo
DEFINIR nome: todo_list_app
DEFINIR sdk: ">=3.0.0 <4.0.0"

LISTAR dependências:
  dio: ^5.x          # cliente HTTP com interceptors
  flutter_riverpod   # gerenciamento de estado reativo
  shared_preferences # persistência local do token JWT
  intl               # formatação de datas ISO 8601

LISTAR dev_dependencies:
  flutter_test
  flutter_lints
```

---

### `frontend/lib/main.dart`
- **Ação:** criar
- **Descrição:** Ponto de entrada do aplicativo Flutter. Inicializa o Riverpod e define a rota inicial com base na presença de token JWT armazenado.

```pseudo
FUNÇÃO main():
  runApp(
    ProviderScope(         # wrapper do Riverpod
      child: TodoApp()
    )
  )

WIDGET TodoApp (StatelessWidget):
  CONSTRUIR MaterialApp:
    title = "Todo List"
    initialRoute:
      SE SharedPreferences.getString("access_token") não é null:
        ROTA → "/board"
      SENÃO:
        ROTA → "/login"
    REGISTRAR rotas:
      "/login"  → LoginView
      "/board"  → BoardView
```

---

### `frontend/lib/models/user_model.dart`
- **Ação:** criar
- **Descrição:** Classe de dados que espelha o payload de autenticação retornado pelo Flask.

```pseudo
CLASSE UserModel:
  CAMPOS:
    accessToken : String

  CONSTRUTOR fromJson(Map<String, dynamic> json):
    accessToken = json["access_token"]

  MÉTODO toJson() → Map:
    retornar { "access_token": accessToken }
```

---

### `frontend/lib/models/task_model.dart`
- **Ação:** criar
- **Descrição:** Classe de dados imutável que espelha a entidade `Task` do back-end.

```pseudo
CLASSE TaskModel:
  CAMPOS (todos final/imutáveis):
    id          : int
    title       : String
    description : String
    order       : int
    columnId    : int
    createdAt   : DateTime (UTC)
    updatedAt   : DateTime (UTC)

  CONSTRUTOR fromJson(Map<String, dynamic> json):
    id          = json["id"]
    title       = json["title"]
    description = json["description"] ?? ""
    order       = json["order"]
    columnId    = json["column_id"]
    createdAt   = DateTime.parse(json["created_at"]).toUtc()
    updatedAt   = DateTime.parse(json["updated_at"]).toUtc()

  MÉTODO toJson() → Map:
    retornar {
      "id": id, "title": title, "description": description,
      "order": order, "column_id": columnId,
      "created_at": createdAt.toIso8601String(),
      "updated_at": updatedAt.toIso8601String()
    }

  MÉTODO copyWith({int? order, int? columnId, ...}) → TaskModel:
    retornar nova instância com campos substituídos
```

---

### `frontend/lib/models/column_model.dart`
- **Ação:** criar
- **Descrição:** Classe de dados imutável que espelha a entidade `Column` do back-end.

```pseudo
CLASSE ColumnModel:
  CAMPOS (todos final/imutáveis):
    id    : int
    title : String
    order : int
    tasks : List<TaskModel>

  CONSTRUTOR fromJson(Map<String, dynamic> json):
    id    = json["id"]
    title = json["title"]
    order = json["order"]
    tasks = (json["tasks"] as List)
              .map((t) => TaskModel.fromJson(t))
              .toList()

  MÉTODO copyWith({List<TaskModel>? tasks}) → ColumnModel:
    retornar nova instância com lista de tarefas substituída
```

---

### `frontend/lib/services/kanban_service.dart`
- **Ação:** criar
- **Descrição:** Classe singleton que encapsula **toda** a comunicação HTTP com o back-end Flask via `Dio`. Nenhuma outra camada realiza chamadas de rede diretamente.

```pseudo
CONSTANTE BASE_URL = "http://10.0.2.2:5000/api"
  # 10.0.2.2 é o alias do localhost do host no emulador Android

CLASSE KanbanService (singleton):
  CAMPO _dio : instância Dio
  CAMPO _token : String? (nullable)

  CONSTRUTOR privado:
    _dio = Dio(BaseOptions(baseUrl: BASE_URL, connectTimeout: 10s, receiveTimeout: 10s))
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        SE _token não é null:
          options.headers["Authorization"] = "Bearer $_token"
        handler.next(options)
      }
    ))

  MÉTODO setToken(String token):
    _token = token
    SharedPreferences.setString("access_token", token)

  MÉTODO clearToken():
    _token = null
    SharedPreferences.remove("access_token")

  MÉTODO loadTokenFromStorage() → Future<void>:
    _token = SharedPreferences.getString("access_token")

  # --- Auth ---

  MÉTODO register(String username, String password) → Future<void>:
    ENVIAR POST "/register" com body { "username": username, "password": password }
    SE statusCode != 201: LANÇAR exceção com message do campo "error"

  MÉTODO login(String username, String password) → Future<String>:
    ENVIAR POST "/login" com body { "username": username, "password": password }
    SE statusCode != 200: LANÇAR exceção com message do campo "error"
    token = response.data["access_token"]
    setToken(token)
    RETORNAR token

  # --- Board ---

  MÉTODO getBoard() → Future<List<ColumnModel>>:
    ENVIAR GET "/board"
    SE statusCode != 200: LANÇAR exceção "Erro ao carregar board"
    RETORNAR response.data["columns"].map(ColumnModel.fromJson).toList()

  # --- Tasks ---

  MÉTODO createTask(String title, int columnId, String description) → Future<TaskModel>:
    ENVIAR POST "/tasks" com body { "title": title, "column_id": columnId, "description": description }
    SE statusCode != 201: LANÇAR exceção com message do campo "error"
    RETORNAR TaskModel.fromJson(response.data)

  MÉTODO moveTask(int taskId, int targetColumnId, int targetOrder) → Future<TaskModel>:
    ENVIAR PATCH "/tasks/$taskId" com body { "column_id": targetColumnId, "order": targetOrder }
    SE statusCode != 200: LANÇAR exceção com message do campo "error"
    RETORNAR TaskModel.fromJson(response.data)

  MÉTODO deleteTask(int taskId) → Future<void>:
    ENVIAR DELETE "/tasks/$taskId"
    SE statusCode != 200: LANÇAR exceção "Erro ao deletar tarefa"
```

---

### `frontend/lib/view_models/auth_view_model.dart`
- **Ação:** criar
- **Descrição:** StateNotifier do Riverpod responsável pela lógica de autenticação e controle de carregamento/erro na tela de login.

```pseudo
ESTADO AuthState:
  isLoading : bool (padrão: false)
  error     : String? (padrão: null)
  isAuthenticated : bool (padrão: false)

PROVIDER authProvider = StateNotifierProvider<AuthViewModel, AuthState>

CLASSE AuthViewModel extends StateNotifier<AuthState>:

  MÉTODO login(String username, String password, BuildContext ctx) → Future<void>:
    SET state = state.copyWith(isLoading: true, error: null)
    TENTAR:
      CHAMAR KanbanService.login(username, password)
      SET state = state.copyWith(isLoading: false, isAuthenticated: true)
      Navigator.pushReplacementNamed(ctx, "/board")
    CAPTURAR exceção e:
      SET state = state.copyWith(isLoading: false, error: e.message)

  MÉTODO register(String username, String password) → Future<void>:
    SET state = state.copyWith(isLoading: true, error: null)
    TENTAR:
      CHAMAR KanbanService.register(username, password)
      SET state = state.copyWith(isLoading: false)
    CAPTURAR exceção e:
      SET state = state.copyWith(isLoading: false, error: e.message)

  MÉTODO logout(BuildContext ctx) → void:
    KanbanService.clearToken()
    SET state = AuthState() # resetar para padrão
    Navigator.pushReplacementNamed(ctx, "/login")
```

---

### `frontend/lib/view_models/board_view_model.dart`
- **Ação:** criar
- **Descrição:** StateNotifier do Riverpod que mantém o estado do board e implementa a lógica de **Optimistic Update** para movimentação de tarefas.

```pseudo
ESTADO BoardState:
  columns   : List<ColumnModel> (padrão: [])
  isLoading : bool (padrão: false)
  error     : String? (padrão: null)

PROVIDER boardProvider = StateNotifierProvider<BoardViewModel, BoardState>

CLASSE BoardViewModel extends StateNotifier<BoardState>:

  MÉTODO fetchBoard() → Future<void>:
    SET state = state.copyWith(isLoading: true, error: null)
    TENTAR:
      columns = AGUARDAR KanbanService.getBoard()
      SET state = state.copyWith(isLoading: false, columns: columns)
    CAPTURAR exceção e:
      SET state = state.copyWith(isLoading: false, error: e.message)

  MÉTODO moveTaskOptimistic(int taskId, int targetColumnId, int targetOrder) → Future<void>:
    # 1. Snapshot para rollback
    previousColumns = state.columns (cópia profunda)

    # 2. Aplicar mudança local imediatamente
    updatedColumns = _applyMoveLocally(state.columns, taskId, targetColumnId, targetOrder)
    SET state = state.copyWith(columns: updatedColumns)

    # 3. Enviar ao servidor em background
    TENTAR:
      AGUARDAR KanbanService.moveTask(taskId, targetColumnId, targetOrder)
    CAPTURAR exceção:
      # 4. Reverter para snapshot em caso de erro
      SET state = state.copyWith(columns: previousColumns)
      EXIBIR SnackBar com mensagem "Erro de sincronização. Alteração revertida."

  MÉTODO _applyMoveLocally(List<ColumnModel> cols, int taskId, int targetColId, int targetOrder)
    → List<ColumnModel>:

    # Localizar e remover tarefa da coluna de origem
    PARA cada coluna em cols:
      PARA cada task em coluna.tasks:
        SE task.id == taskId:
          taskToMove = task
          origemColId = coluna.id

    # Reconstruir coluna de origem sem a tarefa, reordenando os vizinhos
    novaListaOrigem = coluna_origem.tasks
      .where((t) => t.id != taskId)
      .toList()
      .enumerateComNovoOrder()

    # Inserir tarefa na coluna de destino na posição alvo
    novaListaDestino = coluna_destino.tasks.toList()
    novaListaDestino.insert(targetOrder, taskToMove.copyWith(columnId: targetColId))
    novaListaDestino.reenumerate()   # reindexar order de 0..n

    RETORNAR lista de colunas com as duas colunas substituídas

  MÉTODO createTask(String title, int columnId, String description) → Future<void>:
    TENTAR:
      novaTask = AGUARDAR KanbanService.createTask(title, columnId, description)
      # Inserir localmente ao final da coluna alvo
      updatedColumns = state.columns.map((col):
        SE col.id == columnId:
          RETORNAR col.copyWith(tasks: [...col.tasks, novaTask])
        RETORNAR col
      .toList()
      SET state = state.copyWith(columns: updatedColumns)
    CAPTURAR exceção e:
      EXIBIR SnackBar com e.message

  MÉTODO deleteTask(int taskId, int columnId) → Future<void>:
    previousColumns = state.columns (cópia profunda)
    # Otimista: remover localmente primeiro
    updatedColumns = state.columns.map((col):
      SE col.id == columnId:
        RETORNAR col.copyWith(tasks: col.tasks.where((t) => t.id != taskId).toList())
      RETORNAR col
    .toList()
    SET state = state.copyWith(columns: updatedColumns)

    TENTAR:
      AGUARDAR KanbanService.deleteTask(taskId)
    CAPTURAR exceção:
      SET state = state.copyWith(columns: previousColumns)
      EXIBIR SnackBar com "Erro ao deletar tarefa. Alteração revertida."
```

---

### `frontend/lib/views/login_view.dart`
- **Ação:** criar
- **Descrição:** Tela de autenticação com campos de usuário e senha, botão de login e botão de navegação para tela de registro.

```pseudo
WIDGET LoginView (ConsumerWidget):
  CAMPOS locais:
    _usernameController : TextEditingController
    _passwordController : TextEditingController

  CONSTRUIR:
    OBSERVAR authState via authProvider
    RENDERIZAR Scaffold:
      body → Column:
        TextField (controller: _usernameController, label: "Usuário")
        TextField (controller: _passwordController, label: "Senha", obscureText: true)

        SE authState.error não é null:
          EXIBIR Text(authState.error, color: vermelho)

        SE authState.isLoading:
          EXIBIR CircularProgressIndicator
        SENÃO:
          ElevatedButton "Entrar":
            onPressed → authViewModel.login(
              _usernameController.text.trim(),
              _passwordController.text,
              context
            )

        TextButton "Criar conta":
          onPressed → Navigator.pushNamed(context, "/register")
```

---

### `frontend/lib/views/board_view.dart`
- **Ação:** criar
- **Descrição:** Tela principal do Todo List. Exibe as colunas (categorias/status) em scroll horizontal, com as tarefas de cada coluna listadas verticalmente. Suporta arrastar e soltar tarefas entre colunas via `Draggable` e `DragTarget`.

```pseudo
WIDGET BoardView (ConsumerStatefulWidget):

  initState():
    CHAMAR boardViewModel.fetchBoard()

  CONSTRUIR:
    OBSERVAR boardState via boardProvider

    RENDERIZAR Scaffold:
      appBar → AppBar:
        title: "Minhas Tarefas"
        actions: [IconButton logout → authViewModel.logout(context)]

      SE boardState.isLoading: EXIBIR CircularProgressIndicator centralizado
      SE boardState.error != null: EXIBIR Text(boardState.error)

      body → ListView horizontal:
        PARA cada coluna em boardState.columns:
          RENDERIZAR _ColumnWidget(coluna)

      floatingActionButton → IconButton "+" → ABRIR diálogo _CreateTaskDialog

WIDGET _ColumnWidget(ColumnModel coluna):
  RENDERIZAR Container com título da coluna e largura fixa 280px

  DragTarget<TaskModel>:
    onAcceptWithDetails(TaskModel task, DragTargetDetails details):
      targetOrder = CALCULAR índice de inserção baseado em posição Y do drag
      boardViewModel.moveTaskOptimistic(task.id, coluna.id, targetOrder)

    builder → Column:
      Text(coluna.title)
      PARA cada task em coluna.tasks:
        RENDERIZAR _TaskCard(task)

WIDGET _TaskCard(TaskModel task):
  RENDERIZAR como Draggable<TaskModel>:
    data: task
    child: Card com title e description
    feedback: Card semitransparente (ghost durante drag)
    childWhenDragging: Container vazio (placeholder)

  GestureDetector:
    onLongPress → ABRIR diálogo _TaskOptionsDialog (editar / excluir)
```

---

### `frontend/lib/views/register_view.dart`
- **Ação:** criar
- **Descrição:** Tela de cadastro de novo usuário com campos de nome de usuário e senha.

```pseudo
WIDGET RegisterView (ConsumerWidget):
  CAMPOS locais:
    _usernameController : TextEditingController
    _passwordController : TextEditingController

  CONSTRUIR:
    OBSERVAR authState via authProvider
    RENDERIZAR Scaffold:
      body → Column:
        TextField (controller: _usernameController, label: "Usuário")
        TextField (controller: _passwordController, label: "Senha", obscureText: true)

        SE authState.error != null:
          EXIBIR Text(authState.error, color: vermelho)

        SE authState.isLoading:
          EXIBIR CircularProgressIndicator
        SENÃO:
          ElevatedButton "Cadastrar":
            onPressed →
              AGUARDAR authViewModel.register(
                _usernameController.text.trim(),
                _passwordController.text
              )
              SE nenhum erro: Navigator.pop(context)   # voltar para LoginView
```

---

## Resumo de Criação de Arquivos

| Arquivo | Ação |
|---|---|
| `backend/Dockerfile` | criar |
| `backend/requirements.txt` | criar |
| `backend/config.py` | criar |
| `backend/models.py` | criar |
| `backend/app.py` | criar |
| `backend/routes/auth.py` | criar |
| `backend/routes/tasks.py` | criar |
| `backend/templates/index.html` | criar |
| `backend/static/` | criar |
| `frontend/pubspec.yaml` | criar |
| `frontend/lib/main.dart` | criar |
| `frontend/lib/models/user_model.dart` | criar |
| `frontend/lib/models/task_model.dart` | criar |
| `frontend/lib/models/column_model.dart` | criar |
| `frontend/lib/services/kanban_service.dart` | criar |
| `frontend/lib/view_models/auth_view_model.dart` | criar |
| `frontend/lib/view_models/board_view_model.dart` | criar |
| `frontend/lib/views/login_view.dart` | criar |
| `frontend/lib/views/board_view.dart` | criar |
| `frontend/lib/views/register_view.dart` | criar |