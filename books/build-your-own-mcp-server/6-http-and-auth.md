---
title: "Streamable HTTPサーバーへの拡張とOAuth 2.1認証"
---

## Streamable HTTPサーバーの実装

2章で説明した通り、Streamable HTTPは2025-03-26仕様で旧HTTP+SSE transportを置き換える形で導入された、複数クライアントからの接続を1プロセスで受け付けるためのtransportである。ここでは4章のタスク管理サーバーをExpress上のStreamable HTTPサーバーとして書き直す。

TypeScript SDKにはExpressアプリケーションの雛形を作る`createMcpExpressApp()`というヘルパーが用意されている。このヘルパーはリクエストボディのJSONパースを設定するだけでなく、ホストが`127.0.0.1`・`localhost`・`::1`のいずれかである場合にDNS rebinding対策のミドルウェアを自動的に有効にする[^express-helper]。これは2章で触れた「サーバーはOriginヘッダーを検証してDNS rebinding攻撃を防がなければならない」という仕様要件に対応する実装である。

必要なパッケージを追加する。

```bash
npm install express
npm install -D @types/express
```

`src/http-server.ts`:

```typescript
import { randomUUID } from "node:crypto";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { createMcpExpressApp } from "@modelcontextprotocol/sdk/server/express.js";
import { isInitializeRequest } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";

function createServer(): McpServer {
  const server = new McpServer({ name: "task-memo-http-server", version: "1.0.0" });

  server.registerTool(
    "add_task",
    {
      title: "Add Task",
      description: "新しいタスクを追加する",
      inputSchema: { title: z.string() },
    },
    async ({ title }) => ({
      content: [{ type: "text", text: `タスクを追加しました: ${title}` }],
    })
  );

  return server;
}

const app = createMcpExpressApp();

// セッションIDごとにtransportを保持する
const transports: Record<string, StreamableHTTPServerTransport> = {};

app.post("/mcp", async (req, res) => {
  const sessionId = req.headers["mcp-session-id"] as string | undefined;

  try {
    if (sessionId && transports[sessionId]) {
      await transports[sessionId].handleRequest(req, res, req.body);
      return;
    }

    if (!sessionId && isInitializeRequest(req.body)) {
      const transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: () => randomUUID(),
        onsessioninitialized: (sid) => {
          transports[sid] = transport;
        },
      });
      transport.onclose = () => {
        if (transport.sessionId) delete transports[transport.sessionId];
      };

      const server = createServer();
      await server.connect(transport);
      await transport.handleRequest(req, res, req.body);
      return;
    }

    res.status(400).json({
      jsonrpc: "2.0",
      error: { code: -32000, message: "Bad Request: No valid session ID provided" },
      id: null,
    });
  } catch (err) {
    console.error("MCPリクエスト処理エラー:", err);
    if (!res.headersSent) {
      res.status(500).json({
        jsonrpc: "2.0",
        error: { code: -32603, message: "Internal server error" },
        id: null,
      });
    }
  }
});

app.get("/mcp", async (req, res) => {
  const sessionId = req.headers["mcp-session-id"] as string | undefined;
  if (!sessionId || !transports[sessionId]) {
    res.status(400).send("Invalid or missing session ID");
    return;
  }
  await transports[sessionId].handleRequest(req, res);
});

app.delete("/mcp", async (req, res) => {
  const sessionId = req.headers["mcp-session-id"] as string | undefined;
  if (!sessionId || !transports[sessionId]) {
    res.status(400).send("Invalid or missing session ID");
    return;
  }
  await transports[sessionId].handleRequest(req, res);
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`task-memo-http-server: http://127.0.0.1:${PORT}/mcp で待受中`);
});
```

このコードは公式リポジトリの`src/examples/server/simpleStreamableHttp.ts`にある、セッションIDをキーにしたtransportのマップ管理パターンを、OAuthやイベントストアによる再開機能を除いた最小構成に簡略化したものである[^official-example]。POSTハンドラは、セッションIDが既存であればそのtransportを再利用し、セッションIDがなく`initialize`リクエストであれば新しいtransportを作成してセッションを開始し、それ以外は400エラーを返す。GETハンドラはサーバーからクライアントへのServer-Sent Eventsストリームを、DELETEハンドラはMCP仕様が定めるセッション終了リクエストをそれぞれ扱う。

ビルドして起動する。

```bash
npm run build
node build/http-server.js
```

curlで初期化リクエストを送ると、レスポンスヘッダーの`mcp-session-id`にセッションIDが返る。

```bash
curl -i -X POST http://127.0.0.1:3000/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl-test","version":"0.0.1"}}}'
```

以降のリクエストではこのセッションIDを`mcp-session-id`ヘッダーに含めて送信する。

```bash
SESSION="(上のレスポンスで得たmcp-session-idの値)"
curl -X POST http://127.0.0.1:3000/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "mcp-session-id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"add_task","arguments":{"title":"牛乳"}}}'
```

セッションを終了する場合はDELETEリクエストを送る。

```bash
curl -X DELETE http://127.0.0.1:3000/mcp -H "mcp-session-id: $SESSION"
```

なお、Python SDK(FastMCP)でStreamable HTTPサーバーを起動する場合は、5章の`mcp.run()`を`mcp.run(transport="streamable-http")`に置き換えるだけでよい。セッション管理やDNS rebinding対策はSDK内部で行われるため、TypeScript版のような手動のtransportマップ管理は不要である。

## OAuth 2.1による認可

MCPの認可フレームワークは2025-03-26仕様でOAuth 2.1を基盤として初めて導入され、その後のバージョンで段階的に強化されてきた[^auth-changelog]。

2025-03-26仕様では、OAuth 2.1の実装がMUST、Dynamic Client Registration(RFC 7591)とAuthorization Server Metadata(RFC 8414)の実装がSHOULDとされ、認可自体はHTTP系transportに限定されたオプション機能として位置づけられた。

2025-06-18仕様では次の変更が加わった。

> Classify MCP servers as OAuth Resource Servers, adding protected resource metadata to discover the corresponding Authorization server (PR #338)
> Require MCP clients to implement Resource Indicators as described in RFC 8707 to prevent malicious servers from obtaining access tokens (PR #734)

MCPサーバーはOAuthのResource Serverとして分類され、対応するAuthorization Serverを発見するためのProtected Resource Metadataを提供する。クライアントはRFC 8707のResource Indicatorsを実装し、悪意あるサーバーがアクセストークンを不正に取得することを防止しなければならない。あわせてPKCEが必須化され、Implicit GrantやResource Owner Password Credentials Grantが廃止された。トークンのaudience bindingが必須化され、下流APIへのトークンのパススルーも禁止された。

2025-11-25仕様ではさらにOpenID Connect Discovery 1.0への対応、`WWW-Authenticate`ヘッダーによる段階的スコープ同意、OAuth Client ID Metadata Documents(SEP-991)が追加された。Client ID Metadata Documentsは、Dynamic Client Registrationの複雑さを解消するために追加された、クライアント登録のための代替手段である。

Python SDKでは、`TokenVerifier`を実装したクラスと`AuthSettings`を`FastMCP`に渡すことでResource Serverとしての認可を組み込める。公式ドキュメントの例を引用する[^py-auth-docs]。

```python
from mcp.server.auth.provider import AccessToken, TokenVerifier
from mcp.server.auth.settings import AuthSettings
from mcp.server.fastmcp import FastMCP
from pydantic import AnyHttpUrl


class SimpleTokenVerifier(TokenVerifier):
    async def verify_token(self, token: str) -> AccessToken | None:
        # 実際の実装では、Authorization Serverへの問い合わせや
        # JWTの署名検証を行い、有効であればAccessTokenを返す
        ...


mcp = FastMCP(
    "Weather Service",
    json_response=True,
    token_verifier=SimpleTokenVerifier(),
    auth=AuthSettings(
        issuer_url=AnyHttpUrl("https://auth.example.com"),
        resource_server_url=AnyHttpUrl("http://localhost:3001"),
        required_scopes=["user"],
    ),
)
```

`verify_token`の実装はサーバーごとに異なり、実際のAuthorization Serverとの通信やトークンの署名検証が必要になるため、本書では雛形のみを示す。自作サーバーで認可を実装する場合は、まず対象とするAuthorization Server(Auth0、Keycloak、あるいは自前のOAuthサーバーなど)を用意した上で、2025-06-18仕様の[Authorization](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization)ページに記載された要件(Protected Resource Metadata、Resource Indicators、PKCE必須化)を満たす形でTokenVerifierを実装することになる。

TypeScript SDKにも同様に、`requireBearerAuth`ミドルウェアや`mcpAuthMetadataRouter`といったOAuth関連のユーティリティが用意されている。認可を伴う完全な実装は複雑になるため、公式リポジトリの`src/examples/server/simpleStreamableHttp.ts`に含まれる`--oauth`フラグ付きの実行パスと、付随する`demoInMemoryOAuthProvider.ts`を参照することを推奨する[^official-example]。

ローカル開発やCI環境など、信頼できるネットワーク内でのみ動作させる場合は、認可を実装せずにネットワークレベルのアクセス制御(ファイアウォール、リバースプロキシでの認証)で代替する設計も現実的な選択肢である。ただし、その場合もOriginヘッダーの検証とlocalhostへのバインドは仕様上の要件として満たしておく必要がある。

[^express-helper]: GitHub, modelcontextprotocol/typescript-sdk, v1.xブランチ, src/server/express.ts (パッケージ同梱コードより確認)
[^official-example]: GitHub, modelcontextprotocol/typescript-sdk, v1.xブランチ, src/examples/server/simpleStreamableHttp.ts, https://github.com/modelcontextprotocol/typescript-sdk/blob/v1.x/src/examples/server/simpleStreamableHttp.ts
[^auth-changelog]: MCP Specification, "Changelog (2025-06-18)", https://modelcontextprotocol.io/specification/2025-06-18/changelog / "Changelog (2025-11-25)", https://modelcontextprotocol.io/specification/2025-11-25/changelog
[^py-auth-docs]: GitHub, modelcontextprotocol/python-sdk, v1.xブランチ, docs/authorization.md, https://github.com/modelcontextprotocol/python-sdk/blob/v1.x/docs/authorization.md
