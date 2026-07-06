---
title: "Python SDK(FastMCP)で最小サーバーを実装する"
---

## 環境構築

公式Python SDK(`mcp`)は2026年7月時点でPyPI上の最新安定版がv1.28.1(2026年6月26日リリース)である[^pypi-mcp]。FastMCPは元々独立プロジェクトだったものが2024年にPython SDK本体に統合された経緯を持ち、`mcp.server.fastmcp`モジュールとしてSDKに同梱されている[^prefecthq-fastmcp]。TypeScript SDKと同様、`main`ブランチのREADMEはすでに次期仕様(2026-07-28)対応のv2ベータ(`mcp.server.MCPServer`、`2.0.0bN`系)向けに書き換わっているため、本書では安定版である`v1.x`ブランチの内容を基準にする[^py-sdk-v2-readme]。

Python 3.10以降と、パッケージマネージャの`uv`を前提に進める。

```bash
mkdir task-memo-server-py && cd task-memo-server-py
uv init --no-readme
uv add "mcp[cli]"
```

`pip`を使う場合は次のようにインストールする。

```bash
pip install "mcp[cli]"
```

## サーバー本体の実装

TypeScript版と同じ仕様のタスク管理サーバーを、FastMCPのデコレータベースAPIで実装する。`add_task`・`complete_task`・`list_tasks`をツールとして、タスク一覧をリソースとして公開する。

`server.py`:

```python
from dataclasses import dataclass, field, asdict
from typing import Literal

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("task-memo-server")


@dataclass
class Task:
    id: int
    title: str
    priority: Literal["low", "medium", "high"]
    done: bool = False


tasks: list[Task] = []
_next_id = 1


@mcp.tool()
def add_task(title: str, priority: Literal["low", "medium", "high"] = "medium") -> str:
    """新しいタスクをメモリ上のリストに追加する"""
    global _next_id
    task = Task(id=_next_id, title=title, priority=priority)
    tasks.append(task)
    _next_id += 1
    return f"タスクを追加しました: #{task.id} {task.title} ({task.priority})"


@mcp.tool()
def complete_task(id: int) -> str:
    """指定したIDのタスクを完了にする"""
    for task in tasks:
        if task.id == id:
            task.done = True
            return f"タスク #{id} を完了にしました"
    return f"ID {id} のタスクは見つかりません"


@mcp.tool()
def list_tasks() -> str:
    """登録済みタスクの一覧を返す"""
    if not tasks:
        return "タスクはまだありません"
    lines = [
        f"#{t.id} [{'x' if t.done else ' '}] ({t.priority}) {t.title}" for t in tasks
    ]
    return "\n".join(lines)


@mcp.resource("tasks://all")
def all_tasks() -> str:
    """登録済みタスクの一覧をJSON形式で返すリソース"""
    import json

    return json.dumps([asdict(t) for t in tasks], ensure_ascii=False, indent=2)


@mcp.resource("tasks://{id}")
def task_detail(id: str) -> str:
    """指定したIDのタスク1件をJSON形式で返すリソース"""
    import json

    for task in tasks:
        if task.id == int(id):
            return json.dumps(asdict(task), ensure_ascii=False, indent=2)
    return json.dumps({"error": "not found"})


if __name__ == "__main__":
    mcp.run()
```

`@mcp.tool()`デコレータは関数のシグネチャと型アノテーション、docstringから自動的にJSON Schemaを生成し、`tools/list`のレスポンスに反映する。TypeScript SDKで`zod`を使って明示的にスキーマを書いたのに対し、FastMCPでは型アノテーションがそのままスキーマ定義を兼ねる点が異なる。`@mcp.resource()`はデコレータの引数に渡したURIパターンを見て、`{id}`のようなプレースホルダがあれば自動的にテンプレートリソースとして扱い、なければ静的リソースとして扱う。

`mcp.run()`は引数を省略した場合stdio transportで起動する。Streamable HTTPで動かす場合は`mcp.run(transport="streamable-http")`のように明示する。この使い分けは6章で扱う。

## 実行方法

`uv run`で直接実行できる。

```bash
uv run server.py
```

開発中は`mcp dev`コマンドでMCP Inspectorと連携した起動もできる。

```bash
uv run mcp dev server.py
```

TypeScript版と同様、標準入力にJSON-RPCメッセージを渡して手動確認することもできる。

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"manual-test","version":"0.0.1"}}}' | uv run server.py
```

## TypeScript実装との比較

同じ仕様のサーバーを2つのSDKで実装すると、次の違いが明確になる。

- スキーマ定義: TypeScript SDKは`zod`スキーマを明示的に書く。Python SDK(FastMCP)は型アノテーションから自動生成する。
- リソーステンプレート: TypeScript SDKは`ResourceTemplate`クラスを明示的にインスタンス化する。FastMCPはURI文字列内の`{placeholder}`の有無で自動判定する。
- エラーの返し方: 両SDKとも、ツール実行時の例外はプロトコルエラーではなくツール実行エラー(`isError: true`)としてラップされる。FastMCPの場合は関数内で例外を送出すると自動的にエラー内容がツール実行エラーとして変換される。

どちらのSDKを選ぶかは、サーバーを組み込むアプリケーションの既存スタック(Node.js製かPython製か)に合わせるのが実務的な判断基準になる。両者ともプロトコルレベルでは同一のJSON-RPCメッセージをやり取りするため、クライアント側から見た挙動に差異はない。

[^pypi-mcp]: PyPI, mcp, https://pypi.org/project/mcp/
[^prefecthq-fastmcp]: GitHub, PrefectHQ/fastmcp, https://github.com/PrefectHQ/fastmcp
[^py-sdk-v2-readme]: GitHub, modelcontextprotocol/python-sdk, mainブランチREADME(v2ベータ), https://github.com/modelcontextprotocol/python-sdk/blob/main/README.md
