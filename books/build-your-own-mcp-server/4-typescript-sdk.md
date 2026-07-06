---
title: "TypeScript SDKで最小サーバーを実装する"
---

## 環境構築

TypeScript SDK(`@modelcontextprotocol/sdk`)は2026年7月時点でnpmレジストリ上の最新安定版がv1.29.0である[^npm-sdk]。SDKのGitHubリポジトリの`main`ブランチは、2026年7月28日公開予定の次期仕様(2026-07-28)に対応するv2ベータ(`@modelcontextprotocol/server`/`@modelcontextprotocol/client`への分割)向けにすでに書き換えられているため、安定版を使う場合は`v1.x`ブランチのドキュメントを参照する必要がある[^ts-sdk-v2-readme]。本書は本番利用を想定してv1系を基準にする。

Node.js 18以降を前提に、作業ディレクトリを作成する。

```bash
mkdir task-memo-server && cd task-memo-server
npm init -y
npm install @modelcontextprotocol/sdk zod
npm install -D typescript @types/node tsx
```

`zod`はMCP TypeScript SDKの必須peer dependencyであり、ツールやリソースの入力スキーマをTypeScriptの型情報付きで定義するために使う[^ts-sdk-readme]。

`tsconfig.json`を作成する。

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "outDir": "build",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "types": ["node"]
  },
  "include": ["src/**/*"]
}
```

`package.json`に実行スクリプトを追加する。

```json
{
  "type": "module",
  "scripts": {
    "build": "tsc",
    "start": "node build/index.js",
    "dev": "tsx src/index.ts"
  }
}
```

## サーバー本体の実装

タスクをメモリ上に保持する簡易的なタスク管理サーバーを実装する。`add_task`ツールでタスクを追加し、`list_tasks`ツールで一覧を取得し、`tasks://all`リソースでJSON形式の一覧を公開する。

`src/index.ts`:

```typescript
import { McpServer, ResourceTemplate } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

type Task = {
  id: number;
  title: string;
  priority: "low" | "medium" | "high";
  done: boolean;
};

const tasks: Task[] = [];
let nextId = 1;

const server = new McpServer({
  name: "task-memo-server",
  version: "1.0.0",
});

server.registerTool(
  "add_task",
  {
    title: "Add Task",
    description: "新しいタスクをメモリ上のリストに追加する",
    inputSchema: {
      title: z.string().describe("タスクのタイトル"),
      priority: z.enum(["low", "medium", "high"]).default("medium"),
    },
  },
  async ({ title, priority }) => {
    const task: Task = { id: nextId++, title, priority, done: false };
    tasks.push(task);
    return {
      content: [
        { type: "text", text: `タスクを追加しました: #${task.id} ${task.title} (${task.priority})` },
      ],
    };
  }
);

server.registerTool(
  "complete_task",
  {
    title: "Complete Task",
    description: "指定したIDのタスクを完了にする",
    inputSchema: {
      id: z.number().int().describe("完了にするタスクのID"),
    },
  },
  async ({ id }) => {
    const task = tasks.find((t) => t.id === id);
    if (!task) {
      return {
        content: [{ type: "text", text: `ID ${id} のタスクは見つかりません` }],
        isError: true,
      };
    }
    task.done = true;
    return { content: [{ type: "text", text: `タスク #${id} を完了にしました` }] };
  }
);

server.registerTool(
  "list_tasks",
  {
    title: "List Tasks",
    description: "登録済みタスクの一覧を返す",
    inputSchema: {},
  },
  async () => {
    if (tasks.length === 0) {
      return { content: [{ type: "text", text: "タスクはまだありません" }] };
    }
    const lines = tasks.map(
      (t) => `#${t.id} [${t.done ? "x" : " "}] (${t.priority}) ${t.title}`
    );
    return { content: [{ type: "text", text: lines.join("\n") }] };
  }
);

server.registerResource(
  "task-list",
  "tasks://all",
  {
    title: "All Tasks",
    description: "登録済みタスクの一覧をJSON形式で返すリソース",
    mimeType: "application/json",
  },
  async (uri) => ({
    contents: [{ uri: uri.href, text: JSON.stringify(tasks, null, 2) }],
  })
);

server.registerResource(
  "task-detail",
  new ResourceTemplate("tasks://{id}", { list: undefined }),
  { title: "Task Detail", mimeType: "application/json" },
  async (uri, { id }) => {
    const task = tasks.find((t) => t.id === Number(id));
    return {
      contents: [
        {
          uri: uri.href,
          text: task ? JSON.stringify(task, null, 2) : JSON.stringify({ error: "not found" }),
        },
      ],
    };
  }
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("task-memo-server: stdio transportで起動しました");
}

main().catch((err) => {
  console.error("サーバー起動エラー:", err);
  process.exit(1);
});
```

`registerTool`の第2引数に渡す`inputSchema`はzodのスキーマオブジェクトをプロパティごとのマップとして渡す形式であり、SDK内部でJSON Schemaに変換されてクライアントに`tools/list`のレスポンスとして提供される。`registerResource`は静的URI(`tasks://all`)と、`ResourceTemplate`によるパラメータ化されたURI(`tasks://{id}`)の両方をサポートしている。

エラーハンドリングについては、`complete_task`ツールの実装で示したように、存在しないIDを指定された場合はプロトコルエラーではなく`isError: true`を含むツール実行結果として返す。これは3章で説明した「ツール実行エラーはモデルに渡して自己修正させる」という設計方針に沿った実装である。

## 実行方法

開発中は`tsx`でTypeScriptを直接実行できる。

```bash
npm run dev
```

標準入力からJSON-RPCメッセージを1行ずつ渡すことで動作を確認できる。たとえば次のようにinitializeリクエストをパイプで渡す。

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"manual-test","version":"0.0.1"}}}' | npm run dev
```

ただし、手動でJSON-RPCメッセージを1行ずつ入力する方法は初期化のシーケンス(initialize→initialized→他のリクエスト)を守る必要があり煩雑である。7章で扱うMCP Inspectorを使うと、ブラウザUIからtools/resourcesの一覧表示・呼び出しができるため、開発時はInspectorを使う方法を推奨する。

本番用にビルドする場合は次の手順を踏む。

```bash
npm run build
npm run start
```

`package.json`の`bin`フィールドを設定し、エントリファイルの先頭に`#!/usr/bin/env node`を追加すれば、7章で説明するnpm公開・`claude mcp add`での登録にそのまま利用できる形になる。

[^npm-sdk]: npm, @modelcontextprotocol/sdk, https://www.npmjs.com/package/@modelcontextprotocol/sdk
[^ts-sdk-v2-readme]: GitHub, modelcontextprotocol/typescript-sdk, mainブランチREADME(v2ベータ), https://github.com/modelcontextprotocol/typescript-sdk/blob/main/README.md
[^ts-sdk-readme]: GitHub, modelcontextprotocol/typescript-sdk, v1.xブランチdocs/server.md, https://github.com/modelcontextprotocol/typescript-sdk/blob/v1.x/docs/server.md
