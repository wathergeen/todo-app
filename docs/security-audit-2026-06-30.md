# Auditoria de Ciberseguranca - Todo App

Data: 2026-06-30  
Escopo: `backend/` e `frontend/`  
Base: revisao estatica profunda, testes direcionados de entradas malformadas, execucao da suite backend e consulta OSV para dependencias declaradas.

## Resumo Executivo

| Severidade | Quantidade |
| --- | ---: |
| Critica | 1 |
| Alta | 3 |
| Media | 8 |
| Baixa | 2 |

### 5 acoes mais urgentes

1. Rotacionar `JWT_SECRET_KEY`, remover `backend/.env.prod` e `backend/.env.dev` versionados, e impedir inicializacao com segredos padrao.
2. Remover trafego HTTP em claro no app e no Android, exigir HTTPS e configurar HSTS no backend/proxy.
3. Trocar o armazenamento de JWT em `shared_preferences` por armazenamento seguro por plataforma e reduzir a exposicao do token.
4. Adicionar rate limiting, politica de senha mais forte e protecoes contra brute force nos endpoints de autenticacao.
5. Implementar validacao estrita de schema/tipos/tamanho para todos os JSONs de entrada e tratamento global consistente de erros.

## Metodologia e verificacoes

- Arquivos inspecionados com `rg`, `find`, `nl` e leitura manual.
- Testes backend executados: `cd backend && APP_ENV=test ../.venv/bin/python -m pytest` - 6 passed.
- Smoke backend executado: `cd backend && APP_ENV=test PYTHONPATH=. ../.venv/bin/python ../scripts/backend_smoke.py` - `backend smoke ok`.
- Testes direcionados confirmaram HTTP 500 para JSONs malformados em `POST /api/register`, `POST /api/tasks` e `PATCH /api/tasks/<id>`.
- Consulta OSV via `https://api.osv.dev/v1/query` confirmou vulnerabilidades em `Flask==3.0.3` e `python-dotenv==1.0.1`.
- `pip-audit` nao estava instalado no ambiente. O Flutter local falhou por CRLF no SDK externo (`/mnt/c/Users/wather/develop/flutter/bin/internal/shared.sh`), portanto `flutter test/analyze` nao foram reexecutados nesta auditoria.

## Achados

### SEC-001 - Segredo JWT previsivel e versionado para producao

Severidade: Critica  
OWASP: A04 Cryptographic Failures, A02 Security Misconfiguration, A08 Software or Data Integrity Failures  
CWE: CWE-798 Use of Hard-coded Credentials, CWE-321 Use of Hard-coded Cryptographic Key, CWE-522 Insufficiently Protected Credentials  
CVE: N/A

Localizacao:

- `backend/.env.prod`, linhas 1-4
- `backend/.env.dev`, linhas 1-4
- `backend/config.py`, linhas 10-27
- `README.md`, linhas 16-23

Descricao:

O repositorio contem arquivos `.env.dev` e `.env.prod` com `JWT_SECRET_KEY` fixa e previsivel. O `Config` carrega automaticamente `backend/.env.<APP_ENV>` e o README orienta que `APP_ENV=prod` usa `backend/.env.prod`. Se esse arquivo for usado, qualquer pessoa com acesso ao codigo consegue assinar JWTs validos.

Evidencia:

```env
# backend/.env.prod
APP_ENV=prod
FLASK_DEBUG=False
SQLALCHEMY_DATABASE_URI=sqlite:///todo-prod.db
JWT_SECRET_KEY=change-this-production-secret-with-at-least-32-bytes
```

```python
# backend/config.py
APP_ENV = os.getenv("APP_ENV", "dev").lower()
load_dotenv(BASE_DIR / f".env.{APP_ENV}")
load_dotenv(BASE_DIR / ".env", override=True)
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
```

Impacto potencial:

Forja de tokens JWT, acesso integral a contas conhecendo ou adivinhando `sub`, persistencia de acesso ate expiracao dos tokens e quebra completa da autenticacao.

Recomendacao:

- Remover `backend/.env.prod` e `backend/.env.dev` do controle de versao.
- Manter apenas `.env.example` sem valores reais ou previsiveis.
- Bloquear inicializacao em `prod` quando a chave contiver placeholders ou for curta.
- Rotacionar qualquer chave ja usada.

Exemplo:

```python
# backend/config.py
def _required_secret(name):
    value = os.getenv(name)
    forbidden = {
        "change-this-production-secret-with-at-least-32-bytes",
        "dev-todo-list-secret-with-at-least-32-bytes",
        "troque-esta-chave-com-pelo-menos-32-bytes",
    }
    if not value or value in forbidden or len(value) < 32:
        raise RuntimeError(f"{name} deve ser definido por secret manager")
    return value

class Config:
    JWT_SECRET_KEY = _required_secret("JWT_SECRET_KEY")
```

### SEC-002 - Credenciais e tokens trafegam em HTTP claro

Severidade: Alta  
OWASP: A04 Cryptographic Failures, A02 Security Misconfiguration  
CWE: CWE-319 Cleartext Transmission of Sensitive Information, CWE-523 Unprotected Transport of Credentials  
CVE: N/A

Localizacao:

- `frontend/lib/services/kanban_service.dart`, linhas 7 e 54-75
- `frontend/android/app/src/main/AndroidManifest.xml`, linhas 2 e 4-8
- `README.md`, linhas 27-29 e 73

Descricao:

O aplicativo usa `http://10.0.2.2:5000/api` e permite `android:usesCleartextTraffic="true"`. Login, senha e JWT sao transmitidos sem TLS.

Evidencia:

```dart
const baseUrl = 'http://10.0.2.2:5000/api';
```

```xml
<application
    android:usesCleartextTraffic="true">
```

Impacto potencial:

Interceptacao de usuario, senha e token em redes locais, proxies maliciosos, Wi-Fi publico ou ambiente corporativo inspecionado. Um token capturado permite chamadas autenticadas.

Recomendacao:

- Usar HTTPS por ambiente e nao compilar endpoint local em builds de producao.
- Definir `android:usesCleartextTraffic="false"` em release.
- Configurar HSTS no proxy/backend de producao.

Exemplo:

```dart
const baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.example.com/api',
);
```

```xml
<application
    android:usesCleartextTraffic="false">
```

### SEC-003 - JWT persistido em armazenamento local nao criptografado

Severidade: Alta  
OWASP: A04 Cryptographic Failures, A07 Authentication Failures  
CWE: CWE-922 Insecure Storage of Sensitive Information, CWE-522 Insufficiently Protected Credentials  
CVE: N/A

Localizacao:

- `frontend/lib/services/kanban_service.dart`, linhas 36-51
- `frontend/lib/main.dart`, linhas 9-16

Descricao:

O token de acesso e salvo em `SharedPreferences`. Em Android/iOS/web, esse mecanismo nao e equivalente a cofre criptografico de credenciais. O app tambem usa a existencia do token para iniciar direto em `/board`, sem validar expiracao antes da navegacao.

Evidencia:

```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('access_token', token);
_token = prefs.getString('access_token');
```

Impacto potencial:

Roubo de token por backup, dispositivo comprometido, debug bridge, malware local ou exposicao no armazenamento do navegador em builds web. Pode levar a takeover de sessao ate expiracao/revogacao.

Recomendacao:

- Usar `flutter_secure_storage` ou API equivalente por plataforma.
- Validar token no startup chamando endpoint autenticado e limpar token invalido.
- Preferir access token curto e refresh token com rotacao/revogacao.

Exemplo:

```dart
final storage = const FlutterSecureStorage();
await storage.write(key: 'access_token', value: token);
_token = await storage.read(key: 'access_token');
```

### SEC-004 - Ausencia de rate limiting e protecao contra brute force

Severidade: Alta  
OWASP: A07 Authentication Failures, A06 Insecure Design, A09 Security Logging and Alerting Failures  
CWE: CWE-307 Improper Restriction of Excessive Authentication Attempts, CWE-799 Improper Control of Interaction Frequency  
CVE: N/A

Localizacao:

- `backend/routes/auth.py`, linhas 10-45
- `backend/app.py`, linhas 14-20
- `backend/requirements.txt`, linhas 1-14

Descricao:

`POST /api/register` e `POST /api/login` nao possuem limite de tentativas, atraso progressivo, bloqueio temporario, CAPTCHA, nem auditoria de falhas. As dependencias nao incluem mecanismo como `Flask-Limiter`.

Evidencia:

```python
@auth_bp.post("/login")
def login():
    ...
    user = User.query.filter_by(username=username).first()
    if user is None or not bcrypt.check_password_hash(user.password_hash, password):
        return jsonify({"error": "Credenciais inválidas"}), 401
```

Impacto potencial:

Forca bruta de senhas, stuffing de credenciais, criacao massiva de contas e degradacao de disponibilidade por custo de bcrypt repetido.

Recomendacao:

Adicionar rate limiting por IP e por usuario, registrar falhas e considerar bloqueio temporario.

Exemplo:

```python
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(get_remote_address)
limiter.init_app(app)

@auth_bp.post("/login")
@limiter.limit("5 per minute")
def login():
    ...
```

### SEC-005 - Validade e ciclo de vida do JWT nao sao configurados explicitamente

Severidade: Media  
OWASP: A07 Authentication Failures, A06 Insecure Design  
CWE: CWE-613 Insufficient Session Expiration, CWE-287 Improper Authentication  
CVE: N/A

Localizacao:

- `backend/config.py`, linhas 21-30
- `backend/routes/auth.py`, linha 44
- `frontend/lib/services/kanban_service.dart`, linhas 48-51

Descricao:

O backend nao define `JWT_ACCESS_TOKEN_EXPIRES`, revogacao/lista de bloqueio, issuer/audience, algoritmo permitido ou estrategia de refresh. O frontend reutiliza qualquer token salvo.

Evidencia:

```python
class Config:
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
```

```python
token = create_access_token(identity=str(user.id))
```

Impacto potencial:

Sessao roubada permanece valida ate a expiracao padrao da biblioteca; nao ha revogacao no logout nem invalida tokens apos rotacao de senha.

Recomendacao:

Definir expiracao curta, issuer/audience e bloco de revogacao por `jti`.

Exemplo:

```python
from datetime import timedelta

class Config:
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(minutes=15)
    JWT_DECODE_ISSUER = "todo-app"
    JWT_ENCODE_ISSUER = "todo-app"
```

### SEC-006 - Validacao de tipos ausente gera HTTP 500 com entradas malformadas

Severidade: Media  
OWASP: A05 Injection, A10 Mishandling of Exceptional Conditions  
CWE: CWE-20 Improper Input Validation, CWE-248 Uncaught Exception, CWE-755 Improper Handling of Exceptional Conditions  
CVE: N/A

Localizacao:

- `backend/routes/auth.py`, linhas 12-18 e 33-38
- `backend/services/tasks_service.py`, linhas 62-70 e 98-104

Descricao:

Os handlers assumem que `username`, `title` e `order` possuem os tipos esperados. Payloads JSON com listas ou strings em campos numericos causam excecoes nao tratadas e retornam 500.

Evidencia:

```python
username = (data.get("username") or "").strip()
title = (data.get("title") or "").strip()
if order < 0:
    raise ServiceError("order não pode ser negativo", 400)
```

Teste direcionado executado:

```text
POST /api/register {"username":["bad"],"password":"senha123"} => 500
POST /api/tasks {"title":["x"],"column_id":1} => 500
PATCH /api/tasks/1 {"column_id":1,"order":"0"} => 500
```

Impacto potencial:

Negacao de servico por erros repetidos, ruido operacional, comportamento indefinido e vazamento de stack traces em ambientes com debug ativo.

Recomendacao:

Validar schema com biblioteca como Pydantic/Marshmallow ou validadores locais estritos.

Exemplo:

```python
def _string_field(data, name, *, min_len=1, max_len=200):
    value = data.get(name)
    if not isinstance(value, str):
        raise ServiceError(f"{name} inválido", 400)
    value = value.strip()
    if not (min_len <= len(value) <= max_len):
        raise ServiceError(f"{name} inválido", 400)
    return value

def _int_field(data, name, *, minimum=0):
    value = data.get(name)
    if not isinstance(value, int) or value < minimum:
        raise ServiceError(f"{name} inválido", 400)
    return value
```

### SEC-007 - Ausencia de limite de tamanho de request e de campos textuais

Severidade: Media  
OWASP: A06 Insecure Design, A10 Mishandling of Exceptional Conditions  
CWE: CWE-400 Uncontrolled Resource Consumption, CWE-770 Allocation of Resources Without Limits  
CVE: N/A

Localizacao:

- `backend/config.py`, linhas 21-30
- `backend/services/tasks_service.py`, linhas 62-90
- `backend/models.py`, linhas 35-36

Descricao:

Nao ha `MAX_CONTENT_LENGTH` no Flask, nem limites de tamanho para `description`. Embora `Task.title` tenha coluna `String(200)`, a aplicacao nao valida esse limite antes do banco. `description` e `Text` sem limite.

Evidencia:

```python
class Config:
    SQLALCHEMY_DATABASE_URI = os.getenv("SQLALCHEMY_DATABASE_URI", "sqlite:///todo.db")
```

```python
description=data.get("description") or ""
```

Impacto potencial:

Consumo excessivo de memoria/disco, aumento do banco SQLite, lentidao de serializacao/cache e falhas por payloads grandes.

Recomendacao:

Configurar limite global de request e limites por campo.

Exemplo:

```python
class Config:
    MAX_CONTENT_LENGTH = 64 * 1024

description = _string_field(data, "description", min_len=0, max_len=2000)
```

### SEC-008 - Cabecalhos HTTP de seguranca ausentes

Severidade: Media  
OWASP: A02 Security Misconfiguration  
CWE: CWE-693 Protection Mechanism Failure, CWE-1021 Improper Restriction of Rendered UI Layers or Frames  
CVE: N/A

Localizacao:

- `backend/app.py`, linhas 10-26
- `backend/templates/index.html`, linhas 1-22
- `backend/requirements.txt`, linhas 1-14

Descricao:

Nao ha configuracao de cabecalhos como `Content-Security-Policy`, `X-Content-Type-Options`, `X-Frame-Options`/`frame-ancestors`, `Referrer-Policy` e HSTS. A aplicacao tambem serve uma pagina HTML em `/`.

Evidencia:

```python
app = Flask(__name__)
...
@app.get("/")
def index():
    return render_template("index.html")
```

Impacto potencial:

Maior exposicao a clickjacking, MIME sniffing, vazamento de referencia e XSS caso a pagina passe a renderizar dados dinamicos.

Recomendacao:

Adicionar headers via `after_request` ou extensao como `flask-talisman`.

Exemplo:

```python
@app.after_request
def add_security_headers(response):
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Content-Security-Policy"] = "default-src 'self'"
    return response
```

### SEC-009 - Recurso de CDN sem SRI e CSP permissiva/ausente

Severidade: Media  
OWASP: A03 Software Supply Chain Failures, A08 Software or Data Integrity Failures  
CWE: CWE-829 Inclusion of Functionality from Untrusted Control Sphere, CWE-353 Missing Support for Integrity Check  
CVE: N/A

Localizacao:

- `backend/templates/index.html`, linha 7

Descricao:

A pagina raiz carrega CSS de `cdn.jsdelivr.net` sem Subresource Integrity (`integrity`) e sem CSP que restrinja origens. Mesmo sendo CSS, o recurso externo faz parte da superficie de supply chain do frontend servido pelo backend.

Evidencia:

```html
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
```

Impacto potencial:

Alteracao maliciosa ou comprometimento do recurso externo pode modificar a apresentacao e facilitar phishing visual. Se scripts forem adicionados no futuro, o risco aumenta.

Recomendacao:

Hospedar o CSS localmente ou adicionar SRI e CSP.

Exemplo:

```html
<link
  rel="stylesheet"
  href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
  integrity="sha384-..."
  crossorigin="anonymous">
```

### SEC-010 - Dependencias vulneraveis declaradas

Severidade: Media  
OWASP: A03 Software Supply Chain Failures  
CWE: CWE-1104 Use of Unmaintained Third Party Components, CWE-937 Using Components with Known Vulnerabilities  
CVE: CVE-2026-27205, CVE-2026-28684

Localizacao:

- `backend/requirements.txt`, linhas 2 e 6
- `requirements.txt`, linhas 2 e 6

Descricao:

Consulta OSV em 2026-06-30 encontrou vulnerabilidades nas versoes fixadas:

- `Flask==3.0.3`: GHSA-68rp-wp8r-4726 / CVE-2026-27205. Corrigido em `3.1.3`.
- `python-dotenv==1.0.1`: GHSA-mf9w-mj56-hr94 / CVE-2026-28684. Corrigido em `1.2.2`.

Evidencia:

```text
Flask==3.0.3
python-dotenv==1.0.1
```

Impacto potencial:

Risco de comportamento inseguro em sessoes Flask e, no caso do `python-dotenv`, risco local de sobrescrita arbitraria em uso de `set_key` com symlinks. Mesmo que o codigo atual use apenas `load_dotenv`, a dependencia vulneravel permanece no ambiente.

Recomendacao:

Atualizar dependencias e executar testes:

```text
Flask==3.1.3
python-dotenv==1.2.2
```

Referencias:

- https://osv.dev/vulnerability/GHSA-68rp-wp8r-4726
- https://osv.dev/vulnerability/GHSA-mf9w-mj56-hr94

### SEC-011 - Frontend sem lockfile de dependencias

Severidade: Media  
OWASP: A03 Software Supply Chain Failures, A08 Software or Data Integrity Failures  
CWE: CWE-494 Download of Code Without Integrity Check, CWE-1357 Reliance on Insufficiently Trustworthy Component  
CVE: N/A

Localizacao:

- `frontend/pubspec.yaml`, linhas 9-20
- ausencia de `frontend/pubspec.lock`

Descricao:

O projeto Flutter declara dependencias com ranges `^`, mas nao ha `pubspec.lock` no diretorio `frontend/`. Para aplicacoes, o lockfile deve ser versionado para builds reprodutiveis e auditorias de supply chain.

Evidencia:

```yaml
dependencies:
  dio: ^5.7.0
  flutter_riverpod: ^2.5.1
  shared_preferences: ^2.3.2
  intl: ^0.19.0
```

Impacto potencial:

Builds em maquinas diferentes podem resolver versoes transitivas distintas, dificultando reproducao, resposta a incidentes e confirmacao de CVEs.

Recomendacao:

Rodar `flutter pub get` em ambiente corrigido e versionar `frontend/pubspec.lock`. Preferir atualizacoes explicitas via PR e auditoria.

### SEC-012 - Container executa como root e usa servidor de desenvolvimento Flask

Severidade: Media  
OWASP: A02 Security Misconfiguration, A06 Insecure Design  
CWE: CWE-250 Execution with Unnecessary Privileges, CWE-266 Incorrect Privilege Assignment  
CVE: N/A

Localizacao:

- `backend/Dockerfile`, linhas 1-12
- `backend/app.py`, linhas 32-36

Descricao:

O Dockerfile nao cria usuario nao privilegiado e executa `python app.py`, que chama `app.run`. Esse servidor e adequado para desenvolvimento, nao para exposicao direta em producao.

Evidencia:

```dockerfile
FROM python:3.11-slim
...
CMD ["python", "app.py"]
```

```python
app.run(host="0.0.0.0", port=5000, debug=app.config["DEBUG"])
```

Impacto potencial:

Comprometimento da aplicacao pode virar execucao como root dentro do container. O servidor de desenvolvimento tem menor robustez operacional, sem hardening de workers/timeouts.

Recomendacao:

Usar usuario nao root e servidor WSGI.

Exemplo:

```dockerfile
RUN adduser --disabled-password --gecos "" appuser
USER appuser
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
```

### SEC-013 - Logging e alertas de seguranca insuficientes

Severidade: Baixa  
OWASP: A09 Security Logging and Alerting Failures  
CWE: CWE-778 Insufficient Logging, CWE-223 Omission of Security-relevant Information  
CVE: N/A

Localizacao:

- `backend/routes/auth.py`, linhas 31-45
- `backend/routes/tasks.py`, linhas 27-69
- `backend/services/job_queue.py`, linhas 33-38

Descricao:

Somente falhas de jobs em background sao logadas. Falhas de login, tokens invalidos, acessos negados, erros de validacao e operacoes sensiveis nao geram eventos estruturados.

Evidencia:

```python
except Exception:
    self._app.logger.exception("Background job failed")
```

Impacto potencial:

Dificulta deteccao de brute force, abuso de endpoints, tokens roubados e comportamento anomalamente ruidoso.

Recomendacao:

Logar eventos de seguranca sem expor senhas/tokens, com usuario/IP/status e correlation id.

Exemplo:

```python
current_app.logger.warning(
    "auth.login_failed",
    extra={"username": username, "remote_addr": request.remote_addr},
)
```

### SEC-014 - Politica de CORS nao documentada/configurada explicitamente

Severidade: Baixa  
OWASP: A02 Security Misconfiguration  
CWE: CWE-942 Permissive Cross-domain Policy with Untrusted Domains  
CVE: N/A

Localizacao:

- `backend/app.py`, linhas 10-20
- `backend/requirements.txt`, linhas 1-14

Descricao:

Nao ha configuracao explicita de CORS. Isso nao e uma permissao ampla por si so, pois Flask nao adiciona CORS automaticamente. O risco esta em evolucao insegura: quando o frontend web for hospedado em outra origem, a tendencia e adicionar CORS amplo (`*`) sem politica documentada.

Evidencia:

```python
app.register_blueprint(auth_bp, url_prefix="/api")
app.register_blueprint(tasks_bp, url_prefix="/api")
```

Impacto potencial:

Configuracoes futuras permissivas podem permitir que origens nao confiaveis leiam respostas autenticadas caso tokens sejam expostos no navegador.

Recomendacao:

Documentar e aplicar allowlist por ambiente quando CORS for necessario.

Exemplo:

```python
from flask_cors import CORS

CORS(app, resources={r"/api/*": {"origins": ["https://app.example.com"]}})
```

## Observacoes sobre SQL Injection, XSS e autorizacao

- SQL Injection: nao foram encontrados SQLs concatenados ou `text()` com entrada de usuario. O backend usa SQLAlchemy com `filter_by`, `filter` e `db.session.get`, o que reduz o risco de SQLi neste estado.
- XSS: no frontend Flutter, `Text(...)` renderiza conteudo como texto, nao como HTML. A pagina HTML do backend nao renderiza dados de usuario. O risco atual mais proximo de XSS esta na ausencia de CSP e no recurso externo sem SRI.
- Autorizacao: as rotas de tarefas usam `@jwt_required()` e filtram tarefas por `user_id` em leitura, atualizacao e exclusao. Nao foi encontrada IDOR direta para tarefas. As colunas sao globais por desenho; se a especificacao futura exigir colunas por usuario, sera necessario rever esse modelo.
- Cookies/CSRF: a API usa bearer token em header, nao cookies. Nao ha achado de CSRF de cookie no estado atual.
