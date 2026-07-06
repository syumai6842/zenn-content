---
title: "設定ファイル全文とプラグイン化"
---

本章は、これまでの章で扱った要素を1つのプロジェクトに統合した設定例を、そのままコピーして使える形でまとめる。

## 権限モードのおさらい

hooksとsubagentの設定は、権限モードと組み合わさって初めて意図通りに動く。Claude Codeの権限モードは`default`・`acceptEdits`・`plan`・`auto`・`dontAsk`・`bypassPermissions`の6種類である(出典: Claude Code Docs, Configure permissions)。

| モード | 挙動 |
|---|---|
| `default` | ファイル操作やBash実行のたびに確認を求める |
| `acceptEdits` | ファイル操作を自動承認する |
| `plan` | ファイル編集・シェル書き込み系のツールは常に確認コールバックに回り、自動承認されない |
| `auto` | 分類器モデルがコマンドを事前レビューし、スコープの逸脱や未知のインフラ操作など、リスクが高そうな場合のみブロックする |
| `dontAsk` | 個別の確認をスキップする |
| `bypassPermissions` | 到達した操作をすべて承認する。ただし`permissions.deny`に一致するルールがあれば、このモードでもブロックされる |

デフォルトモードは`settings.json`で指定できる。

```json
{
  "permissions": {
    "defaultMode": "acceptEdits"
  }
}
```

親セッションが`bypassPermissions`・`acceptEdits`・`auto`のいずれかを使っている場合、そこから起動されるsubagentはすべてそのモードを継承し、subagentごとに上書きすることはできない。個別のsubagentに`plan`のような別モードを指定したい場合は、親セッションが`default`などそれ以外のモードで動いている必要がある。

## settings.json 統合例

以下は、2章〜7章で扱った要素(危険コマンドのブロック、編集後の自動フォーマット、Stopフックによる品質ゲート、PreCompactでのスナップショット、権限モード)を1つの`.claude/settings.json`にまとめた例である。チームで共有する前提のため、gitにコミットする値のみを含めている。

```json
{
  "permissions": {
    "defaultMode": "default",
    "allow": [
      "Bash(npm run lint)",
      "Bash(npm test)",
      "Bash(git status)",
      "Bash(git diff *)",
      "Bash(git log *)"
    ],
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf ~)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PROJECT_DIR}/.claude/hooks/block_dangerous_bash.py",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/format-on-save.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/stop-quality-gate.sh",
            "timeout": 300
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "auto",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/snapshot-before-compact.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/session-start-context.sh"
          }
        ]
      }
    ]
  },
  "autoMemoryEnabled": true
}
```

`SessionStart`用のスクリプトの例を示す。ブランチ名や未コミットの変更件数のような、セッション開始時に一度だけ確認しておきたい情報をコンテキストに注入する。

```bash
#!/usr/bin/env bash
# .claude/hooks/session-start-context.sh
# SessionStart hook (matcher: startup): 起動時のgit状態をコンテキストに注入する
set -euo pipefail

BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
DIRTY_COUNT=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

python3 - "$BRANCH" "$DIRTY_COUNT" <<'PYEOF'
import json
import sys

branch, dirty_count = sys.argv[1], sys.argv[2]
output = {
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": f"Current branch: {branch}. Uncommitted files: {dirty_count}.",
    }
}
print(json.dumps(output))
PYEOF
```

## プロジェクト構成の全体像

上記の設定を含むプロジェクトの`.claude/`配下は次のような構成になる。

```text
your-project/
├── CLAUDE.md
├── .claude/
│   ├── settings.json
│   ├── settings.local.json      # 個人用、gitignore対象
│   ├── rules/
│   │   ├── testing.md
│   │   └── security.md
│   ├── agents/
│   │   ├── diff-reviewer.md
│   │   ├── safe-researcher.md
│   │   └── security-reviewer.md
│   └── hooks/
│       ├── block_dangerous_bash.py
│       ├── format-on-save.sh
│       ├── stop-quality-gate.sh
│       ├── snapshot-before-compact.sh
│       └── session-start-context.sh
└── .gitignore                    # .claude/settings.local.md, CLAUDE.local.md を含める
```

`.gitignore`には少なくとも次の2行を追加し、個人設定がチームに共有されないようにする。

```text
.claude/settings.local.json
CLAUDE.local.md
```

## プラグイン化という選択肢

上記のようなhooks・subagent・ルールの組み合わせが複数のプロジェクトで再利用したいものになった場合、プラグインとして束ねて配布できる。プラグインはskill・subagent・hooks・MCPサーバー・LSPサーバーを1つのバージョン管理された単位にまとめ、他の人がインストール・更新・信頼できる形にするものである(出典: GitHub, anthropics/claude-code, plugins/README.md)。

すでに`.claude/`配下にskillやhooksがある場合、それをプラグイン化して配布しやすくできる。プラグインは`/my-plugin:hello`のような名前空間付きのskillをサポートし、複数プラグイン間での名前の衝突を防ぐ。プラグインのsubagentは、セキュリティ上の理由から`hooks`・`mcpServers`・`permissionMode`フロントマターが無視される。これらが必要な場合は、該当のagentファイルを`.claude/agents/`や`~/.claude/agents/`にコピーする必要がある。

公式マーケットプレイスは、Anthropicが独自の裁量で採用するプラグインを掲載する形でキュレーションされている。マーケットプレイスからのインストール以外に、Git経由でプラグインリポジトリを直接参照する運用も可能である。

## 本書のまとめ

CLAUDE.md・hooks・subagents・auto memoryは、それぞれ異なる保証レベルを持つ。CLAUDE.mdとauto memoryはコンテキストとしてClaudeに渡され、遵守は保証されない。hooksはライフサイクルの固定タイミングで決定論的に実行される。subagentsはcontextを分離することで、メイン会話のコンテキスト消費を抑えつつ独立した判断を可能にする。

設計の起点は「これは必ず起きなければならないことか、それとも助言でよいことか」という問いである。必ず起きるべきことはhooksに、助言でよいことはCLAUDE.mdに、独立した判断や大量の調査が必要な作業はsubagentに、セッションをまたいで蓄積すべき知見はauto memoryに、それぞれ振り分けることで、4つの仕組みの役割分担が明確になる。

### 参考文献

- [Configure permissions - Claude Code Docs](https://code.claude.com/docs/en/agent-sdk/permissions)
- [Hooks reference - Claude Code Docs](https://code.claude.com/docs/en/hooks)
- [Create custom subagents - Claude Code Docs](https://code.claude.com/docs/en/sub-agents)
- [How Claude remembers your project - Claude Code Docs](https://code.claude.com/docs/en/memory)
- [Create plugins - Claude Code Docs](https://code.claude.com/docs/en/plugins)
- [GitHub - anthropics/claude-code, plugins/README.md](https://github.com/anthropics/claude-code/blob/main/plugins/README.md)
