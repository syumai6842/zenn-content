---
title: "Subagentsの基本設計"
---

## subagentが解決する問題

Claude Codeのメイン会話は単一のコンテキストウィンドウを共有する。調査のために大量のファイルを読んだりログを検索したりすると、その結果がすべてメインの会話履歴に残り、後で参照しない情報までコンテキストを圧迫する。公式ドキュメントは「サブタスクの実行がメイン会話を検索結果やログ、二度と参照しないファイル内容で溢れさせてしまう場合にsubagentを使う。subagentはその作業を自分のコンテキストで行い、要約だけを返す」と説明している(出典: Claude Code Docs, Create custom subagents)。

subagentは独立したコンテキストウィンドウ、独自のシステムプロンプト、限定されたツールアクセス、独立した権限を持つ。呼び出し元からsubagentに渡せる情報は、Agentツールに渡すプロンプト文字列だけである。会話履歴そのものは引き継がれないため、ファイルパスやエラーメッセージ、それまでの決定事項など、subagentが必要とする情報はすべてプロンプトに明示的に含める必要がある。

## 組み込みsubagent

Claude Codeにはあらかじめ以下のsubagentが組み込まれている。

| Agent | モデル | ツール | 用途 |
|---|---|---|---|
| Explore | メイン会話から継承(Claude API利用時はOpusを上限にキャップ) | 読み取り専用(Write/Editは拒否) | コードベースの検索・理解のみ |
| Plan | メイン会話から継承 | 読み取り専用 | plan mode中の調査 |
| general-purpose | メイン会話から継承 | 全ツール | 調査と変更の両方が必要な複雑なタスク |
| statusline-setup | Sonnet | - | `/statusline`実行時の設定生成 |
| claude-code-guide | Haiku | - | Claude Code自体についての質問への回答 |

(出典: Claude Code Docs, Create custom subagents)

ExploreとPlanは、CLAUDE.mdファイルとメインセッションのgitステータスの読み込みをスキップし、調査を高速かつ低コストに保つ設計になっている。他の組み込み・カスタムsubagentは両方とも読み込む。Exploreを呼び出す際、Claudeは`quick`(絞り込んだ検索)・`medium`(中程度の探索)・`very thorough`(複数の場所や命名規則を横断する徹底的な検索)という3段階の徹底度を指定する。

組み込みsubagentを制限するには、`permissions.deny`に特定のタイプを追加する、Agentツール自体を拒否してsubagentへの委譲を全面的に禁止する、あるいは`CLAUDE_CODE_DISABLE_EXPLORE_PLAN_AGENTS=1`でExplore/Planのみを無効化する、といった方法がある。

## subagentファイルの構造

subagentはYAML frontmatterを持つMarkdownファイルとして定義する。

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices. Use proactively after writing or modifying code.
tools: Read, Glob, Grep
model: sonnet
---

You are a code reviewer. When invoked, analyze the code and provide
specific, actionable feedback on quality, security, and best practices.
```

frontmatterがsubagentのメタデータと能力を定義し、本文(Markdown本体)がそのままシステムプロンプトになる。Claudeは各subagentの`description`を読んで、どのタスクをどのsubagentに委譲するかを判断するため、`description`は「いつ使うべきか」が明確に分かる文で書く必要がある。

## frontmatterフィールド一覧

`name`と`description`のみが必須で、それ以外は省略可能である。

| フィールド | 必須 | 説明 |
|---|---|---|
| `name` | Yes | 小文字とハイフンで構成される一意な識別子。hooksでは`agent_type`として渡される |
| `description` | Yes | Claudeがいつこのsubagentに委譲すべきかの判断材料 |
| `tools` | No | 使用可能なツール。省略時は全ツールを継承 |
| `disallowedTools` | No | 継承したツールから除外するツール |
| `model` | No | `sonnet`/`opus`/`haiku`/`fable`、フルモデルID、または`inherit`。省略時は`inherit` |
| `permissionMode` | No | `default`/`acceptEdits`/`auto`/`dontAsk`/`bypassPermissions`/`plan` |
| `maxTurns` | No | subagentが停止するまでの最大ターン数 |
| `skills` | No | 起動時にコンテキストへプリロードするskill(説明だけでなく本文全体が注入される) |
| `mcpServers` | No | このsubagentが使えるMCPサーバー |
| `hooks` | No | このsubagentにスコープされたライフサイクルフック |
| `memory` | No | 永続メモリのスコープ: `user`/`project`/`local` |
| `background` | No | `true`にすると常にバックグラウンドタスクとして実行 |
| `effort` | No | このsubagent実行時のeffortレベル(`low`/`medium`/`high`/`xhigh`/`max`) |
| `isolation` | No | `worktree`にすると一時的なgit worktreeで実行し、リポジトリの独立コピーを持たせる |
| `color` | No | タスクリストやトランスクリプトでの表示色 |
| `initialPrompt` | No | このagentがメインセッションのagentとして起動された場合の最初のユーザーターン |

(出典: Claude Code Docs, Create custom subagents)

## subagentファイルの置き場所とスコープ

同名のsubagentが複数の場所に存在する場合、優先度が高い場所のものが使われる。

| 場所 | スコープ | 優先度 |
|---|---|---|
| managed settings | 組織全体 | 1(最高) |
| `--agents` CLIフラグ | 現在のセッションのみ | 2 |
| `.claude/agents/` | 現在のプロジェクト | 3 |
| `~/.claude/agents/` | 自分の全プロジェクト | 4 |
| プラグインの`agents/`ディレクトリ | プラグインが有効な場所 | 5(最低) |

(出典: Claude Code Docs, Create custom subagents)

プロジェクトのsubagentはバージョン管理にコミットしてチームで共有するのに向く。ユーザーレベルのsubagentは個人の全プロジェクトで再利用したいものに向く。プラグイン由来のsubagentは、セキュリティ上の理由から`hooks`、`mcpServers`、`permissionMode`フロントマターが無視される制約がある点に注意が必要である。

`--agents`フラグでCLI起動時に一時的なsubagentをJSONとして定義することもできる。

```bash
claude --agents '{
  "code-reviewer": {
    "description": "Expert code reviewer. Use proactively after code changes.",
    "prompt": "You are a senior code reviewer. Focus on code quality, security, and best practices.",
    "tools": ["Read", "Grep", "Glob", "Bash"],
    "model": "sonnet"
  },
  "debugger": {
    "description": "Debugging specialist for errors and test failures.",
    "prompt": "You are an expert debugger. Analyze errors, identify root causes, and provide fixes."
  }
}'
```

このセッション限りのsubagentはディスクに保存されないため、自動化スクリプトでの一時利用やテストに向いている。

## ツールアクセスの制御

`tools`をホワイトリストとして使う場合、以下のようにファイル編集権限を持たない調査専用subagentを作れる。

```yaml
---
name: safe-researcher
description: Research agent with restricted capabilities
tools: Read, Grep, Glob, Bash
---
```

このsubagentはファイルの編集・書き込みができず、MCPツールも使えない。

逆に`disallowedTools`をブラックリストとして使うと、メイン会話が持つツールをほぼそのまま継承しつつ一部だけ除外できる。

```yaml
---
name: no-writes
description: Inherits every tool except file writes
disallowedTools: Write, Edit
---
```

両方を指定した場合は`disallowedTools`が先に適用され、その後`tools`が残ったプールに対して解決される。両方に含まれるツールは除外される。

MCPサーバー単位のパターンも使え、`mcp__<server>`または`mcp__<server>__*`で特定サーバーの全ツールを対象にできる。`disallowedTools`では`mcp__*`が任意のサーバーの全MCPツールを除外する。

```yaml
---
name: local-only
description: Inherits every tool except those from the github MCP server
disallowedTools: mcp__github
---
```

`--agent`でメインスレッドとして起動されたエージェントが、自分の判断で他のsubagentを起動できる範囲も制御できる。`Agent(agent_type)`構文を使うと、起動可能なsubagentタイプをホワイトリスト化できる。

```yaml
---
name: coordinator
description: Coordinates work across specialized agents
tools: Agent(worker, researcher), Read, Bash
---
```

この設定では`worker`と`researcher`以外のsubagentタイプは起動できず、制限に反する要求は失敗する。`Agent`を括弧なしで指定すれば任意のsubagentを制限なく起動でき、`tools`リストから`Agent`自体を省略すると、そのエージェントは一切subagentを起動できない。

## モデル選択の解決順序

`model`フィールドの値は次の優先順位で解決される。

1. `CLAUDE_CODE_SUBAGENT_MODEL`環境変数(モデルエイリアスまたはモデルIDに設定されている場合)
2. Claudeがsubagentを呼び出す際に渡す呼び出しごとの`model`パラメータ
3. subagent定義の`model`フロントマター
4. メイン会話のモデル

組織の`availableModels`許可リストと照合し、除外対象のモデルに解決された場合は継承モデルにフォールバックする。

## MCPサーバーのスコープ

`mcpServers`フィールドで、メイン会話には存在しないMCPサーバーをsubagent専用に追加できる。

```yaml
---
name: browser-tester
description: Tests features in a real browser using Playwright
mcpServers:
  playwright:
    command: npx
    args: ["-y", "@modelcontextprotocol/server-playwright"]
---
```

インラインで定義したサーバーはsubagent起動時に接続され、終了時に切断される。文字列で既存のサーバー名を参照した場合は、親セッションの接続をそのまま共有する。

### 参考文献

- [Create custom subagents - Claude Code Docs](https://code.claude.com/docs/en/sub-agents)
- [Subagents in the SDK - Claude API Docs](https://platform.claude.com/docs/en/agent-sdk/subagents)
