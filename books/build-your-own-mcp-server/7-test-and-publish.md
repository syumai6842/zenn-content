---
title: "MCP Inspectorによるテストと公開手順"
---

## MCP Inspectorによる手動テスト

MCP Inspector(`@modelcontextprotocol/inspector`)は、開発中のMCPサーバーに接続してTools・Resources・Promptsの一覧表示と実行をブラウザ上で行える公式ツールである[^inspector]。追加のインストール作業なしに`npx`で起動できる。

```bash
npx @modelcontextprotocol/inspector node build/index.js
```

起動すると`http://localhost:6274`でUIが開く(クライアント側ポートとサーバー側プロキシポートはそれぞれ`CLIENT_PORT`・`SERVER_PORT`環境変数で変更できる)。環境変数やサーバー起動時の引数を渡す場合は次のように書く。

```bash
npx @modelcontextprotocol/inspector -e API_KEY=xxxx -- node build/index.js --some-flag
```

Dockerイメージも公式に提供されている。

```bash
docker run --rm -p 127.0.0.1:6274:6274 -p 127.0.0.1:6277:6277 \
  -e HOST=0.0.0.0 -e MCP_AUTO_OPEN_ENABLED=false \
  ghcr.io/modelcontextprotocol/inspector:latest
```

UIを開かずコマンドラインだけで確認したい場合は`--cli`フラグを使う。次のコマンドは4章で作成したタスク管理サーバーの`tools/list`を実行した結果を返す。

```bash
npx @modelcontextprotocol/inspector --cli node build/index.js --method tools/list
```

実行すると次のようなJSON(抜粋)が標準出力に返る。

```json
{
  "tools": [
    {
      "name": "add_task",
      "title": "Add Task",
      "description": "新しいタスクをメモリ上のリストに追加する",
      "inputSchema": {
        "type": "object",
        "properties": {
          "title": { "type": "string", "description": "タスクのタイトル" },
          "priority": { "type": "string", "enum": ["low", "medium", "high"], "default": "medium" }
        },
        "required": ["title"]
      }
    }
  ]
}
```

`--cli`モードでは`tools/call`も実行できる。

```bash
npx @modelcontextprotocol/inspector --cli node build/index.js \
  --method tools/call --tool-name add_task \
  --tool-arg title="牛乳を買う" --tool-arg priority=high
```

このコマンドを実際に実行すると、次の結果が返る。

```json
{
  "content": [
    { "type": "text", "text": "タスクを追加しました: #1 牛乳を買う (high)" }
  ]
}
```

`--cli`モードはシェルスクリプトやCIパイプラインに組み込んで、サーバーの基本的な疎通確認を自動化する用途にも使える。

## Python SDKでの自動テスト

Python SDKは`mcp.shared.memory`モジュールに、サーバーとクライアントをメモリ上のストリームで直結する`create_connected_server_and_client_session`というテストヘルパーを提供している[^py-testing]。これを使うと、サブプロセスを起動せずにFastMCPサーバーの挙動をpytestで検証できる。

5章の`server.py`に対するテストコード`test_server.py`を次のように書く。

```python
import pytest
from mcp.shared.memory import create_connected_server_and_client_session

from server import mcp


@pytest.mark.anyio
async def test_add_and_list_tasks():
    async with create_connected_server_and_client_session(
        mcp._mcp_server, raise_exceptions=True
    ) as client:
        add_result = await client.call_tool(
            "add_task", {"title": "牛乳を買う", "priority": "high"}
        )
        assert "牛乳を買う" in add_result.content[0].text

        list_result = await client.call_tool("list_tasks", {})
        assert "牛乳を買う" in list_result.content[0].text


@pytest.fixture
def anyio_backend():
    return "asyncio"
```

`FastMCP`インスタンス(`mcp`)が内部で保持する`Server`オブジェクトは`_mcp_server`属性からアクセスできる。テストの実行には`pytest`と`anyio`が必要になる。

```bash
uv add --dev pytest anyio
uv run pytest test_server.py -v
```

このテストは実際に実行すると次のように成功する。

```
test_server.py::test_add_and_list_tasks PASSED
```

TypeScript SDK側にも同様のテストヘルパーとして、`InMemoryTransport`を使ってクライアントとサーバーを直結する方法が用意されている。サブプロセスを起動する統合テストよりも高速に実行できるため、CIでの単体テストにはこちらを使うことを推奨する。

## npmでの公開

TypeScript SDKで実装したサーバーをCLIツールとして配布する場合、エントリファイルの先頭にshebangを追加し、`package.json`の`bin`フィールドで実行コマンド名を紐付ける。

```typescript
#!/usr/bin/env node
// src/index.ts の先頭に追加
```

```json
{
  "name": "task-memo-server",
  "version": "1.0.0",
  "bin": {
    "task-memo-server": "./build/index.js"
  },
  "files": ["build"]
}
```

スコープ付きパッケージとして公開する場合は次のコマンドを使う。

```bash
npm publish --access public
```

公開後は`npx -y task-memo-server`のように、事前インストールなしで直接実行できるようになる。公式のリファレンス実装(`@modelcontextprotocol/server-filesystem`など)も同じ方式で配布されている。

## Claude Desktop・Claude Codeへの登録

Claude Desktopに登録する場合は、設定ファイル`claude_desktop_config.json`(macOSでは`~/Library/Application Support/Claude/`、Windowsでは`%APPDATA%\Claude\`に配置)に次のように追記する[^desktop-config]。

```json
{
  "mcpServers": {
    "task-memo": {
      "command": "npx",
      "args": ["-y", "task-memo-server"]
    }
  }
}
```

ログは`~/Library/Logs/Claude/mcp*.log`(macOS)で確認できる。

Claude Codeでは`claude mcp add`コマンドで登録する[^claude-code-docs]。stdioサーバーの場合、Claude Code自体のオプションとサーバー起動コマンドを`--`で区切る。

```bash
claude mcp add --transport stdio task-memo -- npx -y task-memo-server
```

環境変数を渡す場合は`--env`を使う。

```bash
claude mcp add --env API_KEY=xxxx --transport stdio task-memo -- npx -y task-memo-server
```

リモートのStreamable HTTPサーバーとして公開している場合は`--transport http`を指定する。

```bash
claude mcp add --transport http task-memo https://example.com/mcp \
  --header "Authorization: Bearer your-token"
```

`--scope`オプションで登録範囲を指定できる。`local`(デフォルト、`~/.claude.json`に保存)、`project`(`.mcp.json`に保存しチームで共有)、`user`(全プロジェクトで共有)の3種類がある。

```bash
claude mcp add --transport http task-memo https://example.com/mcp --scope project
```

登録済みサーバーの確認・削除は次のコマンドで行う。

```bash
claude mcp list
claude mcp get task-memo
claude mcp remove task-memo
```

JSON形式で直接登録したい場合は`add-json`を使う。

```bash
claude mcp add-json task-memo '{"type":"http","url":"https://example.com/mcp","headers":{"Authorization":"Bearer token"}}'
```

## MCP Registryへの登録

Anthropicが運営する公式MCP Registry(`registry.modelcontextprotocol.io`)は、サーバー自体のコードではなくメタデータのみを保持する仕組みである。公式リポジトリは「DNSのような存在」と説明している[^registry-repo]。

2026年7月時点でこのレジストリはまだ一般提供(GA)に達していない。公式READMEの「Development Status」には次の記述がある。

> 2025-09-08 update: The registry has launched in preview... this is still a preview release... A general availability (GA) release will follow later.
> 2025-10-24 update: The Registry API has entered an API freeze (v0.1)... development continues on v0... to shape v1 for general availability.

登録には専用のCLIツール`mcp-publisher`を使う。

```bash
mcp-publisher init
mcp-publisher login github
mcp-publisher publish --dry-run
mcp-publisher publish
```

`server.json`に記載する`name`フィールドは、`package.json`の`mcpName`フィールドと一致させる必要がある。所有権の検証はGitHub OAuth/OIDC、またはDNS/HTTPでの検証によって行われる。

現時点でMCP Registryへの登録は必須の手順ではなく、npm公開と`claude mcp add`での個別登録だけでも配布・利用は成立する。ただし、他のクライアントやディレクトリサイトからの発見性を高めたい場合は、プレビュー段階であることを理解した上で登録しておく価値がある。

[^inspector]: GitHub, modelcontextprotocol/inspector, https://github.com/modelcontextprotocol/inspector
[^py-testing]: GitHub, modelcontextprotocol/python-sdk, v1.xブランチ, docs/testing.md, https://github.com/modelcontextprotocol/python-sdk/blob/v1.x/docs/testing.md
[^desktop-config]: MCP公式ドキュメント, "Connect Local Servers", https://modelcontextprotocol.io/docs/develop/connect-local-servers
[^claude-code-docs]: Claude Code公式ドキュメント, "MCP", https://code.claude.com/docs/en/mcp
[^registry-repo]: GitHub, modelcontextprotocol/registry, https://github.com/modelcontextprotocol/registry
