# Plano de Testes — Interface Flutter

Este documento complementa o plano de testes backend da raiz do projeto e cobre o
aplicativo Flutter em `frontend/`.

## Comandos

```bash
cd frontend && flutter test
cd frontend && flutter test test/views_test.dart
just frontend-analyze
```

## Cenários de Frontend

| ID | Cenário | Tipo | Prioridade |
|---|---|---|---|
| UI-LOGIN-01 | Login vazio exibe validação visual para usuário e senha sem chamar backend | Widget | P0 |
| UI-REG-01 | Cadastro vazio exibe validação visual para usuário e senha sem chamar backend | Widget | P0 |
| UI-BOARD-01 | Board em loading inicial renderiza indicador centralizado | Widget | P0 |
| UI-BOARD-02 | Board com erro inicial renderiza mensagem e botão de retry | Widget | P0 |
| UI-BOARD-03 | Board sem colunas renderiza estado vazio | Widget | P1 |
| UI-BOARD-04 | Coluna sem tarefas renderiza estado vazio dentro da coluna | Widget | P1 |
| UI-BOARD-05 | Board com dados e refresh mantém colunas visíveis e mostra feedback não bloqueante | Widget | P1 |
| UI-TASK-01 | Diálogo de criação bloqueia título vazio com validação visual | Widget | P0 |
| UI-TASK-02 | Erro em movimentação otimista reverte estado local e mostra SnackBar | Unit/Widget | P0 |
| UI-TASK-03 | Erro em exclusão otimista reverte estado local e mostra SnackBar | Unit/Widget | P0 |

## Responsividade

- Validar login e cadastro em larguras estreitas e largas, mantendo largura máxima de
  420 px e rolagem vertical.
- Validar board em largura estreita, garantindo rolagem horizontal das colunas.
- Validar diálogo de criação em telas pequenas, sem overflow vertical.

## Acessibilidade

- Botões com ícones devem possuir tooltip ou rótulo semântico.
- Mensagens de erro e estados vazios devem ser textos renderizados.
- Campos de formulário devem possuir labels visíveis.
- Ações principais devem continuar acessíveis por controles Material padrão.

## Renderização Condicional

- `isLoading && columns.isEmpty`: loading centralizado.
- `isLoading && columns.isNotEmpty`: dados preservados com feedback de atualização.
- `error != null && columns.isEmpty`: erro com retry.
- `columns.isEmpty && !isLoading && error == null`: estado vazio.
- `column.tasks.isEmpty`: estado vazio por coluna.

## Integração com APIs

- Testes de widget não devem chamar rede real.
- Testes de integração devem validar que view models continuam usando `KanbanService`
  e preservam os contratos atuais de `/api/board`, `/api/tasks`, `/api/login` e
  `/api/register`.
- Cenários de timeout e erro HTTP devem confirmar que `friendlyErrorMessage` mantém
  mensagem textual para a UI.

## E2E e Regressão Visual

- Fluxo E2E manual mínimo: cadastro, login, carregamento do board, criação de tarefa,
  movimentação por drag-and-drop, exclusão e logout.
- Regressão visual manual mínima: login, cadastro, board vazio, coluna vazia, board
  com tarefas, loading inicial, refresh com dados e erro com retry.

## Usabilidade e Fallback

- Usuário deve receber feedback imediato ao tentar enviar formulário inválido.
- Usuário deve conseguir tentar carregar o board novamente após erro.
- A UI não deve esconder dados já carregados durante refresh.
- Falhas em ações otimistas devem restaurar o estado anterior e exibir SnackBar.
