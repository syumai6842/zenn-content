---
title: "Hooks実践パターン集"
---

本章では、公式ドキュメントとコミュニティ実装(disler/claude-code-hooks-mastery、yurukusa/cc-safe-setupなど)で共有されているhooksの実践パターンを、実行可能なスクリプト付きで紹介する。

## パターン1: 危険コマンドのブロック(PreToolUse)

2025年10月にGitHub Issue #10077として、標準の権限モード下でClaude Codeがホームディレクトリに対して`rm -rf`を実行してしまった事例が報告された。2025年11月には Issue #12637 として、Claudeが文字通り`~`という名前のディレクトリを作成し、その後のglob展開でユーザーの実際のホームディレクトリ配下が削除される事例も報告されている。いずれも`--dangerously-skip-permissions`のようなバイパスモードではなく、通常の権限モードで発生した(出典: morphllm.com, Claude Code Hooks 2026)。

`PreToolUse`フックで`permissionDecision: "deny"`を返すと、`--dangerously-skip-permissions`(bypass mode)下であってもツール呼び出しをブロックできる。バイパスモードは対話的な確認プロンプトとauto分類器を無効化するが、hooks自体は無効化しない(出典: morphllm.com, Claude Code Hooks 2026)。

以下はBashコマンドの危険パターンを検知してブロックするPythonスクリプトの例である。

```python
#!/usr/bin/env python3
"""~/.claude/hooks/block_dangerous_bash.py
PreToolUse hook: Bashツールの危険なコマンドパターンをブロックする。
settings.json側で matcher: "Bash" を指定してこのスクリプトを紐付ける。
"""
import json
import re
import sys

DANGEROUS_PATTERNS = [
    r"rm\s+-rf\s+(/|~|\$HOME)(\s|$)",
    r"rm\s+-rf\s+\*",
    r":\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:",  # fork bomb
    r"chmod\s+-R\s+777\s+/",
    r"curl[^\n]*\|\s*sh",
    r"curl[^\n]*\|\s*bash",
]


def main() -> None:
    payload = json.load(sys.stdin)
    tool_input = payload.get("tool_input", {})
    command = tool_input.get("command", "")

    for pattern in DANGEROUS_PATTERNS:
        if re.search(pattern, command):
            output = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": (
                        f"Blocked by security hook: command matched "
                        f"dangerous pattern '{pattern}'"
                    ),
                }
            }
            print(json.dumps(output))
            sys.exit(0)

    # マッチしなければ何も出力せず exit 0 = 許可
    sys.exit(0)


if __name__ == "__main__":
    main()
```

対応する`settings.json`の設定は次の通り。

```json
{
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
    ]
  }
}
```

exit code 2を返す方式でも同様の制御ができる。その場合はstderrに理由を書き、exitコードを2にする。

```bash
#!/usr/bin/env bash
# .claude/hooks/block-rm.sh
# PreToolUse hook (matcher: Bash): rm -rf を含むコマンドを exit 2 でブロックする
set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input', {}).get('command', ''))")

if echo "$COMMAND" | grep -qE 'rm\s+-rf\s+(/|~|\$HOME)'; then
  echo "Destructive rm -rf command blocked by hook" >&2
  exit 2
fi

exit 0
```

exit code 2方式とJSON方式のどちらを使うかは、ブロック理由の構造化が必要かどうかで判断すればよい。単純な可否判定であればexit code、Claudeに詳細な理由を伝えたい場合や`updatedInput`でコマンドを書き換えたい場合はJSON方式が適している。

## パターン2: 編集後の自動フォーマット(PostToolUse)

ファイル編集のたびにフォーマッタを走らせるのは、CLAUDE.mdに書くよりhooksで強制する方が確実である。

```json
{
  "hooks": {
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
    ]
  }
}
```

```bash
#!/usr/bin/env bash
# .claude/hooks/format-on-save.sh
# PostToolUse hook (matcher: Edit|Write): 変更されたファイルにフォーマッタを適用する
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input', {}).get('file_path', ''))")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx)
    npx --no-install prettier --write "$FILE_PATH" 2>/dev/null || true
    ;;
  *.py)
    ruff format "$FILE_PATH" 2>/dev/null || true
    ;;
  *.go)
    gofmt -w "$FILE_PATH" 2>/dev/null || true
    ;;
esac

exit 0
```

`PostToolUse`はexit code 2でツール呼び出しを取り消すことはできないが、stderrに問題を書けばClaudeへのフィードバックとして表示される。フォーマッタが失敗を返した場合にClaudeへ知らせたいなら、exit 1でstderrにエラー内容を書く(ツール自体はすでに実行済みなのでブロックはされない)。

## パターン3: 完了通知(Notification / Stop)

長時間の自律実行中、ユーザーの入力待ちや完了時にデスクトップ通知を出すパターンは、リモートで作業を任せている場合に有効である。

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [
          { "type": "command", "command": "afplay /System/Library/Sounds/Ping.aiff" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "osascript -e 'display notification \"Claude finished\" with title \"Claude Code\"'"
          }
        ]
      }
    ]
  }
}
```

Linux環境では`notify-send`、Windowsでは`powershell -Command "New-BurntToastNotification"`のような代替コマンドに置き換える。`Notification`イベントのmatcherは通知種別を指し、`permission_prompt`、`idle_prompt`、`auth_success`、`elicitation_dialog`、`elicitation_complete`、`elicitation_response`、`agent_needs_input`、`agent_completed`が定義されている。

## パターン4: 全イベントのロギング

hooksの動作を可視化するために、全イベントをJSON Lines形式でログに残すパターンはデバッグや監査に有効である。disler/claude-code-hooks-mastery(GitHub、3,500以上のスター)は、全13イベント(執筆時点でリポジトリが対応していたイベント数)についてこの方式を採用している(出典: GitHub, disler/claude-code-hooks-mastery)。

```python
#!/usr/bin/env python3
"""~/.claude/hooks/log_event.py
任意のイベントで呼び出し、JSON Linesとしてログファイルに追記する。
"""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

LOG_DIR = Path.home() / ".claude" / "hook-logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)


def main() -> None:
    payload = json.load(sys.stdin)
    event_name = payload.get("hook_event_name", "unknown")
    log_file = LOG_DIR / f"{event_name}.jsonl"

    record = {
        "logged_at": datetime.now(timezone.utc).isoformat(),
        "session_id": payload.get("session_id"),
        "payload": payload,
    }

    with log_file.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")

    sys.exit(0)


if __name__ == "__main__":
    main()
```

これを全イベントにワイルドカードで紐付けるには、対応する各イベントキーに同じhookエントリを列挙する(`hooks`の仕様上、単一のmatcherで全イベント種別を横断的に指定することはできないため、イベントごとに登録する必要がある)。

## パターン5: Stopフックによる品質ゲート

ベストプラクティスガイドは「Claudeは作業が完了したように見えたら停止する。実行できるチェックがなければ、"完了したように見える"ことだけが唯一のシグナルになり、あなたが検証ループの役割を担うことになる」と述べている。Stopフックはこの検証ループを決定論的な仕組みに変える(出典: Claude Code Docs, Best practices for Claude Code)。

```bash
#!/usr/bin/env bash
# .claude/hooks/stop-quality-gate.sh
# Stop hook: テストが通っていなければ停止をブロックする
set -euo pipefail

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('stop_hook_active', False))")

# 無限ループ防止: このフック自身が原因で再度Stopが呼ばれた場合は素通りする
if [ "$STOP_HOOK_ACTIVE" = "True" ]; then
  exit 0
fi

if ! npm test --silent > /tmp/claude-stop-test-output.log 2>&1; then
  echo "Tests are failing. Fix the failures before finishing:" >&2
  tail -n 40 /tmp/claude-stop-test-output.log >&2
  exit 2
fi

exit 0
```

`stop_hook_active`フラグは、Stopフック自身がexit code 2で会話を継続させた結果として再度Stopイベントが発火した場合に真になる。これを見ずにexit 2を返し続けると無限ループになるため、フラグのチェックは必須である。Claude Code自体も、8回連続でStopフックがブロックした場合はhookを上書きしてターンを終了させる安全策を持っている(出典: Claude Code Docs, Best practices for Claude Code)。

同様のガードは`SubagentStop`にも適用できる。matcherにagent_typeを指定すれば、特定のsubagent(たとえば`code-reviewer`)が完了する際にだけ検証を挟める。

## パターン6: PreCompactでの重要情報の保全

コンテキスト圧縮(compaction)は会話の古い部分を要約するため、細部が失われる。`PreCompact`フックはこの圧縮前に重要な情報を保全する機会を提供する。

```json
{
  "hooks": {
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
    ]
  }
}
```

```bash
#!/usr/bin/env bash
# .claude/hooks/snapshot-before-compact.sh
# PreCompact hook (matcher: auto): 圧縮前に現在のgit状態をファイルに書き出す
set -euo pipefail

SNAPSHOT_DIR="${CLAUDE_PROJECT_DIR}/.claude/compact-snapshots"
mkdir -p "$SNAPSHOT_DIR"

{
  echo "## Snapshot at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "### git status"
  git status --short | sed 's/^/    /'
  echo
  echo "### Diff stat"
  git diff --stat | sed 's/^/    /'
} >> "$SNAPSHOT_DIR/latest.md"

exit 0
```

matcherを`auto`にすると自動圧縮の場合のみ発火し、`manual`(`/compact`コマンド実行時)とは区別できる。プロジェクトルートのCLAUDE.mdは圧縮後に自動的に再読み込みされるが、サブディレクトリのCLAUDE.mdや会話中にのみ伝えた指示は再注入されないため、恒久的に残したい情報はCLAUDE.mdに書くか、このようなフックでファイルに退避しておく必要がある(出典: Claude Code Docs, How Claude remembers your project)。

## hookタイプの使い分けの指針

| 用途 | 適したtype |
|---|---|
| 決定論的な検証(lint、テスト、正規表現マッチ) | `command` |
| チームの共通インフラ(社内API、監査ログサーバー)との連携 | `http` |
| 既存のMCPサーバーが持つツールをそのまま再利用したい | `mcp_tool` |
| 単純なyes/no判定をモデルに一回だけ聞きたい | `prompt` |
| ファイルを読んで文脈を踏まえた判定が必要 | `agent` |

`prompt`と`agent`はモデル呼び出しを伴うため、`command`より低速かつコストがかかる。ブロッキングイベント(`PreToolUse`など)に設定する場合はタイムアウトを短めに設定し、応答が返らない場合の挙動(タイムアウトは非ブロッキングエラー扱い)を把握しておく必要がある。

### 参考文献

- [Hooks reference - Claude Code Docs](https://code.claude.com/docs/en/hooks)
- [Best practices for Claude Code - Claude Code Docs](https://code.claude.com/docs/en/best-practices)
- [Claude Code Hooks (2026): Block Claude Reading .env + 30 Hook Events, JSON Input, Exit Codes - morphllm.com](https://www.morphllm.com/claude-code-hooks)
- [GitHub - disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery)
- [GitHub - yurukusa/cc-safe-setup](https://github.com/yurukusa/cc-safe-setup)
- [Claude Code hooksについて解説してみる - DevelopersIO](https://dev.classmethod.jp/articles/claude-code-hooks-basic-usage/)
- [Claude Code security hook gist - sgasser](https://gist.github.com/sgasser/efeb186bad7e68c146d6692ec05c1a57)
