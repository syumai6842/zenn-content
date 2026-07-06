---
title: "Hooksの全体像 ── ライフサイクルとJSON入出力仕様"
---

## hooksとは何か

CLAUDE.mdに書いた指示は「advisory」、つまりClaudeが読んで従おうとするものであって、強制力を持たない。公式ドキュメントは「CLAUDE.mdの内容はシステムプロンプトの一部としてではなく、システムプロンプトの後に続くユーザーメッセージとして配信される。Claudeはそれを読んで従おうとするが、厳密な遵守は保証されない」と説明している(出典: Claude Code Docs, How Claude remembers your project)。

これに対してhooksは、Claude Codeのライフサイクルの特定のタイミングで必ずシェルコマンドを実行する仕組みである。Claudeがそのタイミングで何を「決定」しても、hooksに登録されたコマンドは実行される。ベストプラクティスガイドは「must happen every time with zero exceptions(例外なく毎回起きなければならない処理)にはhooksを使う」と明記している(出典: Claude Code Docs, Best practices for Claude Code)。

CLAUDE.mdとhooksの使い分けの基準は次の通りである。

| 目的 | 適した仕組み |
|---|---|
| コードスタイルやワークフローの助言 | CLAUDE.md |
| 「必ず」lintを実行する、危険なコマンドを「必ず」ブロックする | hooks(PreToolUse / PostToolUse) |
| ドメイン知識やチェックリストをオンデマンドで参照する | skills |
| 特定パスのファイルを触るときだけ適用するルール | `.claude/rules/`(paths frontmatter) |

## 設定ファイルの階層

hooksは複数の場所で定義でき、優先順位と共有範囲が異なる。

| 場所 | スコープ | 共有 |
|---|---|---|
| `~/.claude/settings.json` | 自分の全プロジェクト | 個人のみ |
| `.claude/settings.json` | 単一プロジェクト | チーム共有(gitにコミット) |
| `.claude/settings.local.json` | 単一プロジェクト | 個人のみ(gitignore対象) |
| managed policy settings | 組織全体 | 管理者が配布 |
| `[Plugin]/hooks/hooks.json` | プラグイン有効時 | プラグインに同梱 |
| skill/agentのfrontmatter | そのコンポーネントが動作中のみ | コンポーネントファイル内 |

(出典: Claude Code Docs, Hooks reference)

チームで統一したいルール(危険コマンドのブロックなど)は`.claude/settings.json`にコミットし、APIキーなど共有したくない設定は`.claude/settings.local.json`に置く、という区分がコミュニティでも一般的な運用として紹介されている(出典: dev.classmethod.jp, Claude Code hooksについて解説してみる)。

## フックイベントの全体像

公式ドキュメント時点で定義されているフックイベントは以下の通りである。「ブロック可能」列は、そのイベントでexit code 2またはJSON `decision`によって処理を止められるかを示す。

| イベント | 発火タイミング | ブロック可能 |
|---|---|---|
| `SessionStart` | セッション開始・再開時 | No |
| `Setup` | `--init-only`または`-p --init`/`--maintenance`起動時 | No |
| `UserPromptSubmit` | プロンプト送信時、Claudeが処理する前 | Yes |
| `UserPromptExpansion` | ユーザーが入力したコマンドがプロンプトに展開される時 | Yes |
| `PreToolUse` | ツール呼び出しの実行前 | Yes |
| `PermissionRequest` | 権限ダイアログの表示時 | Yes |
| `PermissionDenied` | autoモードの分類器がツール呼び出しを拒否した時 | No |
| `PostToolUse` | ツール呼び出しの成功後 | No |
| `PostToolUseFailure` | ツール呼び出しの失敗後 | No |
| `PostToolBatch` | 並列ツール呼び出しのバッチが完了した後 | Yes |
| `Notification` | Claude Codeが通知を送る時 | No |
| `MessageDisplay` | アシスタントのメッセージテキスト表示中 | No |
| `SubagentStart` | subagentが起動した時 | No |
| `SubagentStop` | subagentが終了した時 | Yes |
| `TaskCreated` | `TaskCreate`でタスクが作成される時 | Yes |
| `TaskCompleted` | タスクが完了としてマークされる時 | Yes |
| `Stop` | Claudeが応答を終了する時 | Yes |
| `StopFailure` | APIエラーでターンが終了した時 | No |
| `TeammateIdle` | agent teamのチームメイトがアイドルになる直前 | Yes |
| `InstructionsLoaded` | CLAUDE.mdや`.claude/rules/*.md`が読み込まれた時 | No |
| `ConfigChange` | セッション中に設定ファイルが変更された時 | Yes |
| `CwdChanged` | 作業ディレクトリが変更された時 | No |
| `FileChanged` | 監視対象ファイルがディスク上で変更された時 | No |
| `WorktreeCreate` | worktreeが作成される時 | Yes |
| `WorktreeRemove` | worktreeが削除される時 | No |
| `PreCompact` | コンテキスト圧縮の前 | Yes |
| `PostCompact` | コンテキスト圧縮の完了後 | No |
| `Elicitation` | MCPサーバーがツール呼び出し中にユーザー入力を要求する時 | Yes |
| `ElicitationResult` | ユーザーがelicitationに応答した後 | Yes |
| `SessionEnd` | セッションが終了する時 | No |

(出典: Claude Code Docs, Hooks reference)

コミュニティのブログでは「30種類のイベント」あるいは「12〜14種類の主要イベント」という表現が見られるが(出典: morphllm.com, Claude Code Hooks 2026; claudefa.st, Claude Code Hooks: Complete Guide to All 12 Lifecycle Events)、これは記事執筆時点のバージョンによってイベント数が異なるためであり、正確な最新リストは上表のように公式リファレンスで随時更新される。

## hook設定の構造

hooksは`settings.json`内の`hooks`キーに、イベント名をキーとした配列として定義する。

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/check-command.sh",
            "timeout": 600
          }
        ]
      }
    ]
  }
}
```

`matcher`はイベントごとに異なる対象をフィルタする。マッチャーの評価規則は次の通り。

| matcherの値 | 評価方法 | 例 |
|---|---|---|
| `"*"`、`""`、省略 | 全てにマッチ | 毎回発火 |
| `[a-zA-Z0-9_\- ,\|]`のみで構成 | 完全一致または`\|`区切りのリスト | `Bash`、`Edit\|Write` |
| 上記以外の文字を含む | JavaScript正規表現(部分一致) | `^Notebook`、`mcp__memory__.*` |

(出典: Claude Code Docs, Hooks reference)

イベントごとに`matcher`が何を指すかは異なる。`PreToolUse`/`PostToolUse`はツール名、`SessionStart`は`startup`/`resume`/`clear`/`compact`、`Notification`は`permission_prompt`などの通知種別、`SubagentStart`/`SubagentStop`はsubagentのagent_type、`PreCompact`/`PostCompact`は`manual`/`auto`をそれぞれ指す。`Stop`はmatcherを持たない。

MCPツールは`mcp__<server>__<tool>`という命名規則に従うため、`mcp__memory__.*`のようなmatcherで特定MCPサーバーの全ツールを対象にできる。

## hookハンドラの種類

`type`フィールドで5種類のハンドラ形式を選べる。

### command(シェルコマンド)

```json
{
  "type": "command",
  "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/format.sh",
  "timeout": 600
}
```

`args`を指定しない「シェル形式」ではパイプや`&&`、変数展開が使えるが、`args`を指定する「exec形式」では引数がそのままプロセスに渡され、シェル特殊文字は解釈されない。パスのプレースホルダは`${CLAUDE_PROJECT_DIR}`(プロジェクトルート)、`${CLAUDE_PLUGIN_ROOT}`(プラグインのインストール先)、`${CLAUDE_PLUGIN_DATA}`(プラグインの永続データ領域)が使える。

### http

```json
{
  "type": "http",
  "url": "http://localhost:8080/hooks/pre-tool-use",
  "headers": { "Authorization": "Bearer $MY_TOKEN" },
  "allowedEnvVars": ["MY_TOKEN"],
  "timeout": 600
}
```

JSONをPOSTのボディとして送信し、レスポンスのJSONをcommandフックのstdoutと同じ形式で扱う。2xx以外のレスポンスは非ブロッキングエラーになる。

### mcp_tool

```json
{
  "type": "mcp_tool",
  "server": "my_server",
  "tool": "security_scan",
  "input": { "file_path": "${tool_input.file_path}" },
  "timeout": 600
}
```

すでに接続済みのMCPサーバー上のツールを呼び出す。`${path}`形式でJSON入力からの値を埋め込める。

### prompt

```json
{
  "type": "prompt",
  "prompt": "Is this file valid JSON? $ARGUMENTS",
  "model": "claude-opus-4-1-20250805",
  "timeout": 30
}
```

単発の判定をモデルに投げ、yes/noの判断をJSONで返させる。

### agent

```json
{
  "type": "agent",
  "prompt": "Verify the code quality of this file: $ARGUMENTS",
  "timeout": 60
}
```

subagentを起動してRead/Grep/Globなどのツールを使わせ、判定の根拠を得てから結果を返す。

(以上、出典: Claude Code Docs, Hooks reference)

## exit codeの意味

| exit code | 意味 | stdoutの扱い |
|---|---|---|
| 0 | 成功 | JSON出力フィールドとしてパースされる |
| 2 | ブロッキングエラー | stdout/JSONは無視され、stderrがClaudeまたはユーザーにフィードバックされる |
| その他 | 非ブロッキングエラー | `<hook name> hook error`という通知とstderrの最初の行が表示され、実行は継続する |

exit code 2の効果はイベントによって異なる。`PreToolUse`はツール呼び出しをブロックし、`UserPromptSubmit`はプロンプトを拒否し、`Stop`/`SubagentStop`は停止を妨げて会話を継続させる。`PostToolUse`など「ブロック不可」のイベントではexit codeは無視され、stderrの表示のみが行われる。

exit codeだけでは「ブロックする/しない」の二値しか表現できないため、より細かい制御にはexit 0でJSONを標準出力に書く方式を使う。片方の方式のみを使うべきで、両方を混在させるべきではない、と公式ドキュメントは明記している。

## JSON出力の共通フィールド

```json
{
  "continue": true,
  "stopReason": "Build failed, fix errors before continuing",
  "suppressOutput": false,
  "systemMessage": "Warning message shown to user",
  "terminalSequence": "\u001B]777;notify;Title;Body\u0007"
}
```

`continue`を`false`にするとClaudeを完全に停止させ、`stopReason`がユーザーに表示される。`terminalSequence`はOSC 0/1/2/9/99/777とBELのみが許可されている。

## イベント固有のJSON出力パターン

代表的なパターンを挙げる。

`PreToolUse`でツール呼び出しの許可/拒否/入力の書き換えを行う場合。

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Database writes are not allowed",
    "updatedInput": { "command": "npm run lint" }
  }
}
```

`SessionStart`でコンテキストを追加する場合。

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Current branch: main",
    "sessionTitle": "my-session",
    "watchPaths": ["/absolute/path/to/watch"],
    "reloadSkills": true
  }
}
```

`additionalContext`はほとんどのイベントで使え、フックが発火した時点でシステムリマインダーとしてClaudeのコンテキストに注入される。

## PreToolUseの`if`条件によるBash判定

`PreToolUse`など一部のツールイベントでは、hookエントリ自体に`if`フィールドを指定し、そのBashコマンドが特定パターンにマッチする場合のみhookを実行できる。

```json
{
  "type": "command",
  "if": "Bash(rm *)",
  "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/confirm-rm.sh"
}
```

マッチングの挙動は以下の通り。

| パターン | 実行されるBashコマンド | マッチするか | 理由 |
|---|---|---|---|
| `Bash(git *)` | `FOO=bar git push` | する | 先頭の変数代入は無視される |
| `Bash(git *)` | `npm test && git push` | する | サブコマンドごとに判定される |
| `Bash(rm *)` | `echo $(rm -rf /)` | する | `$()`やバッククォート内のコマンドも判定対象 |
| `Bash(rm *)` | `echo $(date)` | しない | マッチするサブコマンドがない |

(出典: Claude Code Docs, Hooks reference)

## 全hookの一時無効化

```json
{
  "disableAllHooks": true
}
```

デバッグ時など、削除せずにhooksを一時停止したい場合に使う。managed settingsの階層は尊重される。

### 参考文献

- [Hooks reference - Claude Code Docs](https://code.claude.com/docs/en/hooks)
- [Best practices for Claude Code - Claude Code Docs](https://code.claude.com/docs/en/best-practices)
- [How Claude remembers your project - Claude Code Docs](https://code.claude.com/docs/en/memory)
- [Claude Code hooksについて解説してみる - DevelopersIO](https://dev.classmethod.jp/articles/claude-code-hooks-basic-usage/)
- [Claude Code Hooks (2026): Block Claude Reading .env + 30 Hook Events, JSON Input, Exit Codes - morphllm.com](https://www.morphllm.com/claude-code-hooks)
- [Claude Code Hooks: Complete Guide to All 12 Lifecycle Events - claudefa.st](https://claudefa.st/blog/tools/hooks/hooks-guide)
