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
just frontend-run     # app Flutter
just frontend-analyze # análise estática Flutter
```

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
