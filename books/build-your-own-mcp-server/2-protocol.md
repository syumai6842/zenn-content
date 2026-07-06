---
title: "プロトコルの基礎 — JSON-RPC、バージョニング、lifecycle、transport"
---

## バージョニング方式

MCPの公式仕様ページ「Versioning」は、バージョン識別子の形式を次のように定義している[^versioning]。

> The Model Context Protocol uses string-based version identifiers following the format `YYYY-MM-DD`, to indicate the last date backwards incompatible changes were made.

つまりバージョン番号は連番ではなく、後方互換性を破壊する変更が最後に行われた日付そのものである。後方互換な変更であればバージョン番号は上がらない、とも明記されている。

> The protocol version will *not* be incremented when the protocol is updated, as long as the changes maintain backwards compatibility.

各リビジョンには3つの状態がある(同ページより引用)。

- Draft: in-progress specifications, not yet ready for consumption.
- Current: the current protocol version, which is ready for use and may continue to receive backwards compatible changes.
- Final: past, complete specifications that will not be changed.

本書執筆時点(2026年7月)で確認できたバージョンとその位置づけを次に示す。

| バージョン | 状態 | 主要変更 |
|---|---|---|
| 2024-11-05 | Final(初版) | HTTP+SSE transport |
| 2025-03-26 | Final | OAuth 2.1認可フレームワーク追加、Streamable HTTP導入、JSON-RPCバッチング追加、tool annotations追加 |
| 2025-06-18 | Final | JSON-RPCバッチング削除、structured tool output、OAuth Resource Server化、elicitation追加、resource links追加 |
| 2025-11-25 | Current(現行) | OIDC Discovery対応、icons追加、実験的なtasks追加 |
| 2026-07-28 | Release Candidate(RC) | ステートレス化、Extensions framework、Tasks正式化、MCP Apps、Roots/Sampling/Loggingの非推奨化 |

各バージョンの変更点は公式changelogに列挙されている。2025-03-26の変更点のうち代表的なものを引用する[^changelog-0326]。

> Added a comprehensive authorization framework based on OAuth 2.1 (PR #133)
> Replaced the previous HTTP+SSE transport with a more flexible Streamable HTTP transport (PR #206)
> Added support for JSON-RPC batching (PR #228)

2025-06-18ではこのうちJSON-RPCバッチングが撤回されている[^changelog-0618]。

> Remove support for JSON-RPC batching (PR #416)
> Add support for structured tool output (PR #371)
> Classify MCP servers as OAuth Resource Servers, adding protected resource metadata to discover the corresponding Authorization server (PR #338)
> Require MCP clients to implement Resource Indicators as described in RFC 8707 to prevent malicious servers from obtaining access tokens (PR #734)

2026-07-28のリリース候補では、従来の`initialize`/`initialized`ハンドシェイクと`Mcp-Session-Id`ヘッダーによるセッション管理が廃止され、クライアント情報とプロトコルバージョンを毎リクエストの`_meta`フィールドで送信するステートレスな方式に変更される予定である[^rc-0728]。この変更により、スティッキーセッションや共有セッションストアなしで通常のロードバランサー配下にMCPサーバーを配置できるようになるとされている。本書のコード例は現行のCurrentバージョンである2025-11-25を基準に説明するが、2026-07-28以降に開発する場合はこの変更を前提に設計を見直す必要がある。

バージョンネゴシエーションは初期化時に行われ、クライアントとサーバーは複数バージョンを同時サポートしてもよいが、セッションでは単一バージョンに合意しなければならない、と規定されている[^versioning]。

> Version negotiation happens during initialization. Clients and servers MAY support multiple protocol versions simultaneously, but they MUST agree on a single version to use for the session.

## JSON-RPC 2.0メッセージの構造

MCP仕様は「クライアントとサーバー間のすべてのメッセージはJSON-RPC 2.0仕様に従わなければならない」と定めている[^basic]。

> All messages between MCP clients and servers MUST follow the JSON-RPC 2.0 specification.

MCPにおけるリクエストの型は次の通りである。

```typescript
{
  jsonrpc: "2.0";
  id: string | number;
  method: string;
  params?: {
    [key: string]: unknown;
  };
}
```

標準のJSON-RPC 2.0と異なり、MCPではリクエストIDに`null`を許容しない点が明記されている。

> Requests MUST include a string or integer ID.
> Unlike base JSON-RPC, the ID MUST NOT be null.
> The request ID MUST NOT have been previously used by the requestor within the same session.

レスポンスの型は次の通りで、`result`と`error`のどちらか一方のみを含まなければならない。

```typescript
{
  jsonrpc: "2.0";
  id: string | number;
  result?: { [key: string]: unknown };
  error?: {
    code: number;
    message: string;
    data?: unknown;
  };
}
```

通知(Notification)はIDを持たないメッセージであり、応答を期待しない一方向の送信に使う。

```typescript
{
  jsonrpc: "2.0";
  method: string;
  params?: { [key: string]: unknown };
}
```

## Lifecycle: initialize/initializedハンドシェイク

MCPのクライアント・サーバー間接続は、Initialization・Operation・Shutdownという3フェーズのlifecycleに従う[^lifecycle]。

> The Model Context Protocol (MCP) defines a rigorous lifecycle for client-server connections that ensures proper capability negotiation and state management.

初期化フェーズのシーケンスは次の通りである(仕様書のmermaid図をテキスト化)。

```
Client -> Server : initialize request
Server -> Client : initialize response
Client -- Server : initialized notification (通知、応答なし)
```

具体的なメッセージ例を仕様書から引用する。

initializeリクエスト:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2025-06-18",
    "capabilities": {
      "roots": { "listChanged": true },
      "sampling": {},
      "elicitation": {}
    },
    "clientInfo": {
      "name": "ExampleClient",
      "title": "Example Client Display Name",
      "version": "1.0.0"
    }
  }
}
```

initializeレスポンス:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2025-06-18",
    "capabilities": {
      "logging": {},
      "prompts": { "listChanged": true },
      "resources": { "subscribe": true, "listChanged": true },
      "tools": { "listChanged": true }
    },
    "serverInfo": {
      "name": "ExampleServer",
      "title": "Example Server Display Name",
      "version": "1.0.0"
    },
    "instructions": "Optional instructions for the client"
  }
}
```

initialized通知:

```json
{ "jsonrpc": "2.0", "method": "notifications/initialized" }
```

初期化中の挙動については次のように規定されている。

> The client SHOULD NOT send requests other than pings before the server has responded to the initialize request.
> The server SHOULD NOT send requests other than pings and logging before receiving the initialized notification.

バージョン不一致時のエラー例も仕様書に記載されている。

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32602,
    "message": "Unsupported protocol version",
    "data": { "supported": ["2024-11-05"], "requested": "1.0.0" }
  }
}
```

## Capability Negotiation

初期化時にクライアントとサーバーは、そのセッションで利用可能なオプション機能を宣言し合う。仕様書に記載されている主なcapabilityを次に示す。

| 分類 | Capability | 説明 |
|---|---|---|
| Client | roots | ファイルシステムのrootを提供できる |
| Client | sampling | LLMサンプリングリクエストに対応する |
| Client | elicitation | サーバーからの追加情報要求に対応する |
| Client | experimental | 非標準の実験的機能への対応を示す |
| Server | prompts | プロンプトテンプレートを提供する |
| Server | resources | 読み取り可能なリソースを提供する |
| Server | tools | 呼び出し可能なツールを公開する |
| Server | logging | 構造化ログメッセージを送出する |
| Server | completions | 引数の自動補完に対応する |
| Server | experimental | 非標準の実験的機能への対応を示す |

`listChanged`はリストの変更通知への対応を、`subscribe`はresourcesに限り個別リソースの変更購読への対応を示すサブcapabilityである。

## Shutdown

stdio transportでは、クライアントがstdinをクローズしてサーバーの終了を待機し、タイムアウトした場合にSIGTERM、さらにタイムアウトした場合にSIGKILLを送るという段階的な手順が規定されている。HTTP transportでは単にHTTP接続をクローズすることでシャットダウンを示す。

## Transport層: stdioとStreamable HTTP

MCP仕様は現在2つの標準transportを定義している[^transports]。

> The protocol currently defines two standard transport mechanisms for client-server communication: 1. stdio ... 2. Streamable HTTP ... Clients SHOULD support stdio whenever possible.

### stdio

> The client launches the MCP server as a subprocess. The server reads JSON-RPC messages from its standard input (stdin) and sends messages to its standard output (stdout). Messages are delimited by newlines, and MUST NOT contain embedded newlines. The server MAY write UTF-8 strings to its standard error (stderr) for logging purposes. The server MUST NOT write anything to its stdout that is not a valid MCP message.

ローカルで動作するプロセスとの通信に用いる。クライアントがサーバーをサブプロセスとして起動するため、ネットワーク設定が不要で、後述するMCP Inspectorでの検証もしやすい。

### Streamable HTTP

> This replaces the HTTP+SSE transport from protocol version 2024-11-05... the server operates as an independent process that can handle multiple client connections. This transport uses HTTP POST and GET requests. Server can optionally make use of Server-Sent Events (SSE) to stream multiple server messages.

サーバーは単一のHTTPエンドポイント(例: `https://example.com/mcp`)でPOSTとGET両方のメソッドをサポートしなければならない。セッション管理には`Mcp-Session-Id`ヘッダーが使われ、initializeレスポンスのHTTPヘッダーにセッションIDを含めることができる。以降のリクエストではクライアントがこのヘッダーを含めなければならない。

セキュリティ上の要件として次が明記されている。

> Servers MUST validate the Origin header on all incoming connections to prevent DNS rebinding attacks
> When running locally, servers SHOULD bind only to localhost (127.0.0.1) rather than all network interfaces (0.0.0.0)
> Servers SHOULD implement proper authentication for all connections

TypeScript SDKのREADMEは使い分けを次のように要約している[^ts-sdk-readme]。

> Streamable HTTP for remote servers (recommended).
> HTTP + SSE for backwards compatibility only.
> stdio for local, process-spawned integrations.

本書では4章・5章でstdioサーバーを、6章でStreamable HTTPサーバーを実装する。ローカルで完結するツール(ファイル操作、ローカルDB参照など)はstdio、複数クライアントから接続される共有サービスとして公開する場合はStreamable HTTPを選ぶ、という使い分けが公式ドキュメントの推奨に沿った判断基準になる。

[^versioning]: MCP Specification, "Versioning", https://modelcontextprotocol.io/specification/versioning
[^changelog-0326]: MCP Specification, "Changelog (2025-03-26)", https://modelcontextprotocol.io/specification/2025-03-26/changelog
[^changelog-0618]: MCP Specification, "Changelog (2025-06-18)", https://modelcontextprotocol.io/specification/2025-06-18/changelog
[^rc-0728]: MCP Blog, "The 2026-07-28 MCP Specification Release Candidate", https://blog.modelcontextprotocol.io/posts/2026-07-28-release-candidate/
[^basic]: MCP Specification, "Basic Protocol", https://modelcontextprotocol.io/specification/2025-06-18/basic
[^lifecycle]: MCP Specification, "Lifecycle", https://modelcontextprotocol.io/specification/2025-06-18/basic/lifecycle
[^transports]: MCP Specification, "Transports", https://modelcontextprotocol.io/specification/2025-06-18/basic/transports
[^ts-sdk-readme]: GitHub, modelcontextprotocol/typescript-sdk, v1.xブランチREADME, https://github.com/modelcontextprotocol/typescript-sdk/blob/v1.x/README.md
