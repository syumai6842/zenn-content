---
title: "Memory運用パターン"
---

## CLAUDE.mdとauto memoryの違い

各セッションは新しいコンテキストウィンドウから始まるが、2つの仕組みがセッションをまたいだ知識を持ち越す。公式ドキュメントは両者を次のように対比している(出典: Claude Code Docs, How Claude remembers your project)。

| | CLAUDE.mdファイル | Auto memory |
|---|---|---|
| 誰が書くか | ユーザー | Claude |
| 内容 | 指示とルール | 学習事項とパターン |
| スコープ | プロジェクト・ユーザー・組織 | リポジトリ単位、全worktreeで共有 |
| ロードされるタイミング | 毎セッション | 毎セッション(先頭200行または25KBまで) |
| 用途 | コーディング標準、ワークフロー、プロジェクトのアーキテクチャ | ビルドコマンド、デバッグ時の知見、Claudeが発見した好み |

両方とも「強制される設定」ではなく「コンテキスト」としてClaudeに渡される。特定のアクションを状況に関わらずブロックしたい場合は、2章・3章で扱ったPreToolUseフックを使う。

## auto memoryの仕組み

auto memoryは、ユーザーが何も書かなくてもClaudeがセッションをまたいで知識を蓄積する仕組みである。ビルドコマンド、デバッグの知見、アーキテクチャに関するメモ、コードスタイルの好み、ワークフロー上の習慣などをClaudeが自ら記録する。毎セッションで何かを保存するわけではなく、将来の会話で有用かどうかをClaudeが判断する(出典: Claude Code Docs, How Claude remembers your project)。

執筆時点でauto memoryはClaude Code v2.1.59以降で利用可能で、デフォルトで有効になっている。セッション内で`/memory`を開き、auto memoryのトグルを切り替えるか、プロジェクト設定で`autoMemoryEnabled`を指定することで切り替えられる。

```json
{
  "autoMemoryEnabled": false
}
```

環境変数`CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`でも無効化できる。

### 保存場所

各プロジェクトは`~/.claude/projects/<project>/memory/`という専用のメモリディレクトリを持つ。`<project>`パスはgitリポジトリから導出されるため、同じリポジトリの全worktreeとサブディレクトリは1つのauto memoryディレクトリを共有する。gitリポジトリの外ではプロジェクトルートが代わりに使われる。

保存先を変更したい場合は`settings.json`で`autoMemoryDirectory`を指定する。

```json
{
  "autoMemoryDirectory": "~/my-custom-memory-dir"
}
```

値は絶対パスまたは`~/`から始まるパスでなければならない。プロジェクトの`.claude/settings.json`や`.claude/settings.local.json`で設定した場合、そのフォルダに対するワークスペース信頼ダイアログを承認した後にのみ有効になる(hooksを許可する際のゲートと同じ)。

メモリディレクトリの構造は以下のようになる。

```text
~/.claude/projects/<project>/memory/
├── MEMORY.md          # 簡潔なインデックス。毎セッションでロードされる
├── debugging.md       # デバッグパターンの詳細メモ
├── api-conventions.md # API設計上の決定事項
└── ...                # その他Claudeが作成した任意のトピックファイル
```

`MEMORY.md`はメモリディレクトリのインデックスとして機能する。Claudeはセッション全体を通してこのディレクトリのファイルを読み書きし、`MEMORY.md`を使って何がどこに保存されているかを把握する。

auto memoryはマシンローカルである。同一gitリポジトリの全worktreeとサブディレクトリは1つのauto memoryディレクトリを共有するが、複数マシンやクラウド環境の間では共有されない。

### ロードの挙動

`MEMORY.md`の先頭200行、または25KBのいずれか早い方に達するまでの内容が、毎セッション開始時にロードされる。それを超える内容は起動時にはロードされない。Claudeは詳細なメモを別のトピックファイルに移すことで`MEMORY.md`を簡潔に保つ。

この200行/25KBという上限は`MEMORY.md`にのみ適用される。CLAUDE.mdファイルは長さに関わらず全文がロードされるが、短いファイルの方が指示への遵守率は高くなる。

`debugging.md`や`patterns.md`のようなトピックファイルは起動時にはロードされない。Claudeが必要とする時に、通常のファイル読み込みツールでオンデマンドに読む。

### 監査と編集

auto memoryのファイルはただのMarkdownであり、いつでも編集・削除できる。`/memory`を実行するとメモリファイルを閲覧し、エディタで開くことができる。

「常にnpmではなくpnpmを使う」「APIテストにはローカルのRedisインスタンスが必要なことを覚えておいて」のように頼むと、Claudeはそれをauto memoryに保存する。CLAUDE.mdに追加したい場合は「これをCLAUDE.mdに追加して」と直接頼むか、`/memory`経由で自分で編集する。

## subagentの永続メモリ

subagent自身も、`memory`フロントマターフィールドを設定することで独自のauto memoryを持てる。値は`user`・`project`・`local`のいずれかのスコープを指定する。

```yaml
---
name: security-reviewer
description: Reviews code for security vulnerabilities. Learns project-specific security conventions over sessions.
tools: Read, Grep, Glob
model: opus
memory: project
---

You are a senior security engineer. Review code for injection
vulnerabilities, authentication and authorization flaws, secrets in
code, and insecure data handling. Record project-specific conventions
you discover (e.g. the standard sanitization helper, the auth
middleware location) so future reviews start from that context.
```

`memory: project`を指定したsubagentは、プロジェクト単位でメモリを蓄積し、同じsubagentを呼び出すたびに過去の学習を踏まえた判断ができるようになる。これは、繰り返し使う専門subagent(セキュリティレビュー、パフォーマンス分析など)が、プロジェクト固有の慣習を毎回説明されなくても認識できるようにする効果がある。

## トラブルシューティング

### CLAUDE.mdの指示に従わない

CLAUDE.mdの内容はシステムプロンプトの一部としてではなく、システムプロンプトの後に続くユーザーメッセージとして配信される。Claudeはそれを読んで従おうとするが、厳密な遵守は保証されない。デバッグの手順は次の通り。

- `/memory`を実行し、対象のCLAUDE.mdやCLAUDE.local.mdが実際にロードされているか確認する。一覧に出てこなければClaudeはそのファイルを見ていない
- 該当のCLAUDE.mdが、セッションでロードされる場所(6章の階層表)に置かれているか確認する
- 「コードをきちんとフォーマットして」ではなく「2スペースインデントを使う」のように、具体的で検証可能な指示に書き換える
- 複数のCLAUDE.mdや`.claude/rules/`の間で矛盾する指示がないか確認する。矛盾がある場合、Claudeはどちらかを恣意的に選ぶことがある

特定のタイミングで必ず実行されるべき指示(コミット前に必ず、ファイル編集後に必ず)は、CLAUDE.mdではなくhooksとして書く。hooksはライフサイクルイベントの固定タイミングでシェルコマンドとして実行され、Claudeの判断に関わらず適用される。

システムプロンプトレベルでの指示が必要な場合は、`--append-system-prompt`フラグを使う。これは呼び出しのたびに渡す必要があるため、対話的な利用よりもスクリプトや自動化に向いている。

`InstructionsLoaded`フックを使うと、どの指示ファイルがいつ、なぜロードされたかをログに残せる。path指定ルールやサブディレクトリの遅延ロードをデバッグする際に有用である。

### auto memoryが何を保存したか分からない

`/memory`を実行してauto memoryフォルダを選択すれば、Claudeが保存した内容を読める。すべてプレーンなMarkdownであり、読み書きも削除も自由にできる。

### CLAUDE.mdが大きすぎる

200行を超えるファイルはコンテキスト消費が増え、遵守率が下がる可能性がある。マッチするファイルを扱う時だけロードされる`.claude/rules/`のpath指定ルールを使うか、毎セッションで不要な内容を削る。`@path`インポートへの分割は整理には役立つが、インポートされたファイルも起動時にロードされるため、コンテキスト消費量そのものは削減されない。

### /compact後に指示が消えたように見える

プロジェクトルートのCLAUDE.mdは圧縮を生き延びる。`/compact`後、Claudeはディスクから再読み込みしてセッションに再注入する。サブディレクトリのCLAUDE.mdは自動的には再注入されず、そのサブディレクトリ内のファイルを次に読んだタイミングで再ロードされる。

圧縮後に指示が消えたように見えた場合、原因は次のいずれかである。会話中でのみ伝えた指示だった(CLAUDE.mdに書いていなかった)、あるいはまだ再ロードされていないサブディレクトリのCLAUDE.mdに書かれていた。会話でのみ伝えた指示を永続化したい場合はCLAUDE.mdに追記する。

### 参考文献

- [How Claude remembers your project - Claude Code Docs](https://code.claude.com/docs/en/memory)
- [Create custom subagents - Claude Code Docs](https://code.claude.com/docs/en/sub-agents)
