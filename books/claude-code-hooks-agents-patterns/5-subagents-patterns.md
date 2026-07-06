---
title: "Subagent分離設計パターン"
---

前章でsubagentの基本設定を扱った。本章はそれらの部品を組み合わせて、実際の開発フローにどう組み込むかという設計パターンを扱う。

## 計画・生成・評価の3分離パターン

Qiitaの記事「Claude Codeのサブエージェントを使い倒す」は、Anthropic公式が推奨する分離パターンとして、「Whatを決めるPlanner」「Howを決めて書くGenerator」「動いているかを見るEvaluator」という3つの役割分離を紹介している(出典: Qiita, nogataka, Claude Codeのサブエージェントを使い倒す)。この分離の要点は、Evaluatorが自分の実装したコードを評価しないことにある。同じsubagentが「書く」と「評価する」の両方を担うと、自分の実装への確証バイアスがかかりやすい。

この考え方は公式ベストプラクティスガイドの「Writer/Reviewerパターン」とも一致する。ガイドは次のような2セッション構成を例示している(出典: Claude Code Docs, Best practices for Claude Code)。

| セッションA(Writer) | セッションB(Reviewer) |
|---|---|
| `Implement a rate limiter for our API endpoints` | |
| | `Review the rate limiter implementation in @src/middleware/rateLimiter.ts. Look for edge cases, race conditions, and consistency with our existing middleware patterns.` |
| `Here's the review feedback: [Session B output]. Address these issues.` | |

同じパターンをテストにも適用できる。一方のセッションがテストを書き、別のセッションがそのテストを通すコードを書く。

## アドバーサリアルレビューのsubagent化

公式ガイドは「Claudeが長く自律的に動くほど、完了と判断する前に独立したチェックが重要になる」と述べ、実装した本人ではなく、diffと基準だけを見る「新鮮なコンテキスト」のsubagentにレビューさせることを推奨している(出典: Claude Code Docs, Best practices for Claude Code)。

```text
Use a subagent to review the rate limiter diff against PLAN.md. Check that
every requirement is implemented, the listed edge cases have tests, and
nothing outside the task's scope changed. Report gaps, not style preferences.
```

このパターンをsubagent定義として固定化すると、次のようになる。

```yaml
---
name: diff-reviewer
description: Reviews the current git diff against a plan document for correctness gaps. Use before considering a task complete.
tools: Read, Grep, Glob, Bash(git diff *), Bash(git log *)
model: opus
---

You review a git diff against a plan document. You did not write this code.

Report only gaps that affect correctness or the stated requirements:
- Requirements in the plan that are not implemented
- Edge cases listed in the plan without corresponding tests
- Changes outside the task's stated scope

Do not report style preferences, hypothetical future issues, or
suggestions that aren't tied to a concrete requirement. If nothing is
wrong, say so directly instead of inventing minor points.
```

公式ガイドは同時に注意点も述べている。「ギャップを見つけるよう指示されたレビュアーは、作業が健全であっても大抵何かを報告する。それを追いかけると過剰設計(余計な抽象化層、防御的コード、起こり得ないケースへのテスト)につながる」。レビュアーには「正しさや要件に影響するギャップだけを報告し、それ以外は任意」と明示的に伝えることが対策になる。

## 並列調査と逐次実行の使い分け

サーバーワークスのブログは、subagentの並列実行と逐次実行を次のように使い分けると整理している(出典: サーバーワークスエンジニアブログ, Claude Codeに"チーム作業"をさせる)。

- 並列実行: 互いに依存関係のない調査タスクや、複数ファイルの独立したレビュー
- 逐次実行: 前のsubagentの出力が次のsubagentの入力になる場合

Claude Code自体もこの区別に基づき、独立した複数の調査を一度のメッセージで並列にAgentツールとして呼び出すことができる。たとえば「認証まわりのファイルを調べるsubagent」と「環境変数の扱いを調べるsubagent」は独立しているため並列化でき、「調査結果を踏まえて実装するsubagent」は前者の結果に依存するため逐次実行になる。

## activeContextの分離という設計原理

Zennの記事は、subagentがメインの会話コンテキストを見ることができず、受け取るのは自身のシステムプロンプトと呼び出し時に渡されるタスク記述のみである点を「共有しないことで独立した判断を担保している」設計として説明している(出典: Zenn, take4, Claude Code公式から学ぶ、コンテキスト分離のSubAgent設計)。この「共有しない」設計には2つの利点がある。第一に、subagentが増えるたびにメインコンテキストが雪だるま式に膨らむことを防ぐ。第二に、各subagentの入力プロンプトが独立しているためキャッシュが効きやすくなり、レイテンシとコストが改善する。

裏を返せば、subagentに渡すプロンプトには「なぜこの作業が必要か」「前提として何が分かっているか」を過不足なく書く必要がある。メイン会話で交わした議論を前提にした曖昧な指示(「さっき話した件、よろしく」)はsubagentには通じない。

## isolationフィールドによるworktree分離

複数のsubagentが同じリポジトリに同時に書き込むと、ファイルの競合が起きる。`isolation: worktree`を指定すると、そのsubagentは一時的なgit worktree、つまりリポジトリの独立したコピー上で作業する。

```yaml
---
name: feature-implementer
description: Implements a single feature in an isolated worktree, branched from the default branch
tools: Read, Write, Edit, Bash, Grep, Glob
isolation: worktree
---

You implement features in an isolated worktree branched from the
repository's default branch, not from the parent session's current HEAD.
Commit your changes with a descriptive message when done.
```

worktreeはデフォルトブランチから分岐する(呼び出し元セッションの`HEAD`からではない)。subagentが何も変更しなかった場合、worktreeは自動的に削除される。複数のsubagentが同時並行で別々の機能を実装する場合、この分離によってお互いの作業ディレクトリを汚さずに済む。

## Agent Teams: セッション間通信が必要な場合

subagentは単一セッション内で完結する仕組みである。複数の独立したセッションを並行して動かし、それらが互いに通信する必要がある場合はAgent Teamsという別の仕組みが用意されている。Agent Teamsでは1つのセッションが「チームリード」として共有タスクリストを介して作業を調整し、「チームメイト」はそれぞれ自分のコンテキストウィンドウで独立に動作しながら直接通信する(出典: Claude Code Docs, Orchestrate teams of Claude Code sessions)。

Agent Teamsは執筆時点で実験的機能であり、デフォルトでは無効化されている。`settings.json`または環境変数で`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`を設定することで有効化する。

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

公式ドキュメントが挙げる有効な用途は次の4つである。

- 研究・レビュー: 複数のチームメイトが問題の異なる側面を同時に調査し、互いの発見を共有・検証し合う
- 新規モジュール・機能: チームメイトがそれぞれ独立した部分を担当し、互いに干渉しない
- 競合仮説によるデバッグ: チームメイトが異なる仮説を並行してテストし、答えに早く収束する
- レイヤー横断の調整: フロントエンド・バックエンド・テストにまたがる変更を、それぞれ別のチームメイトが担当する

全チームメイトはチームリードの権限モードを起点として開始し、起動後に個別のモードへ変更することはできるが、起動時にチームメイトごとに異なるモードを指定することはできない。

## claude -pによるファンアウト

大規模な機械的変換(大量ファイルのマイグレーションなど)には、subagentではなく非対話モード(`claude -p`)を使ったファンアウトが向いている。公式ガイドは次の3段階の手順を示している(出典: Claude Code Docs, Best practices for Claude Code)。

```bash
# 1. 対象ファイル一覧を作らせる
claude -p "list all files under src/legacy/ that use the old API and write their paths to files.txt"

# 2. 一覧をループしてclaude -pを呼び出すスクリプトを書く
for file in $(cat files.txt); do
  claude -p "Migrate $file from React to Vue. Return OK or FAIL." \
    --allowedTools "Edit,Bash(git commit *)"
done

# 3. 最初の数件で挙動を確認してから全件実行する
```

`--allowedTools`で許可するツールを絞り込むことは、無人実行時に特に重要である。ループの各呼び出しは独立したセッションであり、subagentのようにメイン会話のコンテキストを共有しないため、各呼び出しのプロンプトに必要な情報をすべて含める必要がある。

### 参考文献

- [Claude Codeのサブエージェントを使い倒す ── Anthropic公式「計画・生成・評価」3分離パターンの実践 - Qiita](https://qiita.com/nogataka/items/efe8eb9df612d2211221)
- [Claude Code公式から学ぶ、コンテキスト分離のSubAgent設計 - Zenn](https://zenn.dev/take4/articles/8b54f8cd4710bc)
- [Claude Code に"チーム作業"をさせる ー サブエージェントで大規模タスクを分割処理する - サーバーワークスエンジニアブログ](https://blog.serverworks.co.jp/claude-code-subagents-guide)
- [Create custom subagents - Claude Code Docs](https://code.claude.com/docs/en/sub-agents)
- [Orchestrate teams of Claude Code sessions - Claude Code Docs](https://code.claude.com/docs/en/agent-teams)
- [Best practices for Claude Code - Claude Code Docs](https://code.claude.com/docs/en/best-practices)
