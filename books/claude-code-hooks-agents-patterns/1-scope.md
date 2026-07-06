---
title: "本書の目的と対象範囲"
---

## この本が扱うこと

Claude Codeは、CLAUDE.mdによる指示、hooksによる決定論的な制御、subagentsによるcontext分離、そしてauto memoryによるセッションをまたいだ知識蓄積という、4つの拡張レイヤーを持つ。それぞれの機能単体の説明は公式ドキュメントに存在するが、「どの場面でどのレイヤーを選ぶか」「複数のレイヤーをどう組み合わせるか」を横断的に整理した資料は少ない。本書はこの4レイヤーを、公式ドキュメント(code.claude.com/docs)とコミュニティで共有されている実装事例をもとに、設定例付きで整理する。

具体的には以下を扱う。

- hooksの全イベント(SessionStart、PreToolUse、PostToolUse、Stop、SubagentStop、PreCompactなど約30種類)の入出力JSON仕様とexit codeの挙動
- 危険コマンドのブロック、自動フォーマット、通知、品質ゲートといったhooksの実践パターン
- subagentsの設計(frontmatterフィールド全項目、tools制御、model選択、permissionMode)
- Explore/Plan/general-purposeという組み込みsubagentの使い分けと、カスタムsubagentによるcontext分離パターン
- CLAUDE.mdの階層構造(managed policy / user / project / local)と`.claude/rules/`によるpath別ルール
- auto memoryの仕組みと、subagent単位でのpersistent memoryスコープ
- 上記を組み合わせた設定ファイルの全文サンプル

## この本が扱わないこと

Claude Code自体のインストール手順、基本的なCLI操作、MCPサーバーの自作方法は扱わない。これらは公式ドキュメントや他の入門書で扱われている範囲であり、本書は「すでにClaude Codeを日常的に使っていて、設定をカスタマイズしたい」読者を対象にする。

## 対象読者

以下のいずれかに該当する読者を想定する。

- CLAUDE.mdに指示を書いているが、Claude Codeが従わないことがあり、hooksとの使い分けが分からない
- subagent(Task tool)を使っているが、`tools`や`permissionMode`によるスコープ制御を活用できていない
- 毎回同じ確認作業(lint実行、危険コマンドの警告、テスト結果の確認)を手動でやっている
- 複数セッションにまたがる知識をどう永続化すればよいか分からない

## 前提とするバージョン

本書の記述は2026年7月時点のClaude Code公式ドキュメントに基づく。Claude Codeは頻繁に更新されるため、フィールド名やデフォルト値が将来変更される可能性がある。特に以下の点は執筆時点でのバージョン依存が明記されている機能なので、実際に設定する際は`claude --version`で手元のバージョンを確認し、公式ドキュメントの該当ページで最新の挙動を確認することを推奨する。

- Explore/Planサブエージェントがメイン会話のモデルを継承する挙動(v2.1.198以降)
- `/agents`コマンドの対話ウィザードの廃止(v2.1.198以降)
- subagentが`background: true`未指定時にデフォルトでバックグラウンド実行される挙動(v2.1.198以降)

## 表記について

本書ではJSON設定例、Bash/Pythonのフックスクリプト、YAML frontmatterによるsubagent定義を掲載する。コード例はそのままコピーして動作する状態を目指しているが、環境依存のパス(`${CLAUDE_PROJECT_DIR}`など)は各自の環境に合わせて調整すること。

## 出典について

各章末に参考文献としてURLを掲載する。一次情報源(code.claude.com/docs、platform.claude.com/docs)を優先し、コミュニティ記事は一次情報を補強する実例として引用する。

### 参考文献

- [Claude Code Docs - Documentation Index](https://code.claude.com/docs/en/overview)
