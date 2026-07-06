---
title: "コア概念 — Tools・Resources・Prompts・Sampling・Roots"
---

MCPは5つのプリミティブでサーバーとクライアントの間の情報のやり取りを定義している。それぞれ制御の主体が異なり、公式ドキュメントは各プリミティブを次のモデルに分類している。

| プリミティブ | 制御モデル | 方向 |
|---|---|---|
| Tools | model-controlled(モデル制御) | サーバー→モデルが発見・実行 |
| Resources | application-driven(アプリケーション主導) | サーバー→クライアントアプリが文脈組み込みを判断 |
| Prompts | user-controlled(ユーザー制御) | サーバー→ユーザーが明示的に選択 |
| Sampling | サーバーがクライアント経由でLLM呼び出しを要求 | サーバー→クライアント |
| Roots | クライアントがファイルシステム境界をサーバーに提示 | クライアント→サーバー |

この分類を理解しておくと、実装時に「この情報はモデルに自律的に使わせたいのか、アプリケーション側の判断に委ねたいのか、ユーザーに明示的に選ばせたいのか」という設計判断がしやすくなる。

## Tools

Tools仕様ページは次のように定義している[^tools]。

> The Model Context Protocol (MCP) allows servers to expose tools that can be invoked by language models. Tools enable models to interact with external systems, such as querying databases, calling APIs, or performing computations.

> the language model can discover and invoke tools automatically based on its contextual understanding and the user's prompts.

セキュリティに関する注記として、ツール呼び出しを拒否できる人間の介在を常に確保すべきとされている。

> there SHOULD always be a human in the loop with the ability to deny tool invocations.

capability宣言:

```json
{ "capabilities": { "tools": { "listChanged": true } } }
```

`tools/list`リクエストとレスポンス:

```json
{ "jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": { "cursor": "optional-cursor-value" } }
```

```json
{
  "jsonrpc": "2.0", "id": 1,
  "result": {
    "tools": [{
      "name": "get_weather",
      "title": "Weather Information Provider",
      "description": "Get current weather information for a location",
      "inputSchema": {
        "type": "object",
        "properties": { "location": { "type": "string", "description": "City name or zip code" } },
        "required": ["location"]
      }
    }],
    "nextCursor": "next-page-cursor"
  }
}
```

`tools/call`リクエストとレスポンス:

```json
{ "jsonrpc": "2.0", "id": 2, "method": "tools/call",
  "params": { "name": "get_weather", "arguments": { "location": "New York" } } }
```

```json
{ "jsonrpc": "2.0", "id": 2,
  "result": {
    "content": [{ "type": "text", "text": "Current weather in New York:\nTemperature: 72°F\nConditions: Partly cloudy" }],
    "isError": false
  }
}
```

ツール呼び出しのエラーには2種類ある。ひとつはプロトコルエラー(存在しないツール名を指定した場合など)で、通常のJSON-RPCエラーレスポンスとして返す。もうひとつはツール実行エラー(外部APIの呼び出し失敗など)で、`isError: true`を結果に含めて返す。後者はモデルにエラー内容を渡して自己修正させることを意図した設計である。2025-11-25仕様では、入力検証エラーはプロトコルエラーではなくツール実行エラーとして返すべきだと明確化された。

## Resources

Resources仕様ページの定義を引用する[^resources]。

> The Model Context Protocol (MCP) provides a standardized way for servers to expose resources to clients. Resources allow servers to share data that provides context to language models, such as files, database schemas, or application-specific information. Each resource is uniquely identified by a URI.

> host applications determining how to incorporate context based on their needs.

主なメソッドは`resources/list`、`resources/read`、URIテンプレートでパラメータ化されたリソース一覧を返す`resources/templates/list`、変更を購読する`resources/subscribe`である。

`resources/read`レスポンス例:

```json
{ "jsonrpc": "2.0", "id": 2,
  "result": {
    "contents": [{
      "uri": "file:///project/src/main.rs",
      "mimeType": "text/x-rust",
      "text": "fn main() {\n    println!(\"Hello world!\");\n}"
    }]
  }
}
```

標準的なURIスキームには、クライアントが直接web fetch可能な場合にのみ使うべき`https://`、ファイルシステム的リソースを表す`file://`、`git://`がある。

## Prompts

Prompts仕様ページの定義を引用する[^prompts]。

> The Model Context Protocol (MCP) provides a standardized way for servers to expose prompt templates to clients. Prompts allow servers to provide structured messages and instructions for interacting with language models.

> they are exposed from servers to clients with the intention of the user being able to explicitly select them for use.

スラッシュコマンドのような、ユーザーが明示的に呼び出すインターフェースが典型例として挙げられている。

`prompts/get`レスポンス例:

```json
{ "jsonrpc": "2.0", "id": 2,
  "result": {
    "description": "Code review prompt",
    "messages": [{
      "role": "user",
      "content": { "type": "text", "text": "Please review this Python code:\ndef hello():\n    print('world')" }
    }]
  }
}
```

## Sampling

Sampling仕様ページの定義を引用する[^sampling]。

> The Model Context Protocol (MCP) provides a standardized way for servers to request LLM sampling ("completions" or "generations") from language models via clients. This flow allows clients to maintain control over model access, selection, and permissions while enabling servers to leverage AI capabilities—with no server API keys necessary.

> Sampling in MCP allows servers to implement agentic behaviors, by enabling LLM calls to occur nested inside other MCP server features.

サーバーは特定のモデル名を直接指定できない。代わりに`costPriority`・`speedPriority`・`intelligencePriority`(いずれも0〜1の正規化された優先度)と、サブ文字列マッチでモデル名を示唆する`hints`を組み合わせてモデル選好を表現する。クライアント側はこれを見て別プロバイダの等価モデルにマッピングしてもよい。

```json
{ "jsonrpc": "2.0", "id": 1, "method": "sampling/createMessage",
  "params": {
    "messages": [{ "role": "user", "content": { "type": "text", "text": "What is the capital of France?" } }],
    "modelPreferences": { "hints": [{ "name": "claude-3-sonnet" }], "intelligencePriority": 0.8, "speedPriority": 0.5 },
    "systemPrompt": "You are a helpful assistant.",
    "maxTokens": 100
  }
}
```

Toolsと同様、サンプリング要求を拒否できる人間の介在を常に確保すべきとされている。

> there SHOULD always be a human in the loop with the ability to deny sampling requests.

## Roots

Roots仕様ページの定義を引用する[^roots]。

> The Model Context Protocol (MCP) provides a standardized way for clients to expose filesystem "roots" to servers. Roots define the boundaries of where servers can operate within the filesystem, allowing them to understand which directories and files they have access to.

`roots/list`レスポンス例:

```json
{ "jsonrpc": "2.0", "id": 1,
  "result": { "roots": [{ "uri": "file:///home/user/projects/myproject", "name": "My Project" }] } }
```

root の`uri`は現行仕様では`file://` URIでなければならないと規定されている。

## Elicitation(補足)

Elicitationは2025-06-18で新規追加された概念で、サーバーが対話の途中でユーザーから追加情報を取得する機能である。2025-11-25仕様ではURL modeでのelicitationや`EnumSchema`の標準化拡張が加わった。5つの主要プリミティブほど広く実装されているわけではないが、対話的な確認が必要なツール(破壊的操作の実行前確認など)を実装する際に利用できる。

次章から、ここで説明したTools・Resourcesを実際にコードとして実装していく。

[^tools]: MCP Specification, "Tools", https://modelcontextprotocol.io/specification/2025-06-18/server/tools
[^resources]: MCP Specification, "Resources", https://modelcontextprotocol.io/specification/2025-06-18/server/resources
[^prompts]: MCP Specification, "Prompts", https://modelcontextprotocol.io/specification/2025-06-18/server/prompts
[^sampling]: MCP Specification, "Sampling", https://modelcontextprotocol.io/specification/2025-06-18/client/sampling
[^roots]: MCP Specification, "Roots", https://modelcontextprotocol.io/specification/2025-06-18/client/roots
