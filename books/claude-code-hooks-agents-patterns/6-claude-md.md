---
title: "CLAUDE.md設計"
---

## CLAUDE.mdの役割

CLAUDE.mdは、Claudeがセッション開始時に読み込む特殊なMarkdownファイルである。コードを読むだけでは分からない情報、たとえばビルドコマンドやコードスタイル、ワークフロー上の約束事をClaudeに持続的に伝える。公式ガイドは「CLAUDE.mdに追加すべきタイミング」を次のように定義している(出典: Claude Code Docs, How Claude remembers your project)。

- Claudeが同じ間違いを2回目もした時
- コードレビューでClaudeが知っておくべきだったことが指摘された時
- 前回のセッションでも入力した同じ訂正や補足を、今回も入力しようとしている時
- 新しいチームメンバーが生産的に働くために同じ文脈を必要とする時

## 何を書き、何を書かないか

公式ベストプラクティスガイドは、CLAUDE.mdに含めるべき内容と除外すべき内容を対比している。

| 含めるべき | 除外すべき |
|---|---|
| Claudeが推測できないBashコマンド | コードを読めば分かること |
| デフォルトと異なるコードスタイルのルール | Claudeがすでに知っている標準的な言語の慣習 |
| テスト手順と推奨テストランナー | 詳細なAPIドキュメント(代わりにリンクする) |
| リポジトリの慣習(ブランチ命名、PRの作法) | 頻繁に変わる情報 |
| プロジェクト固有のアーキテクチャ上の決定 | 長い説明やチュートリアル |
| 開発環境の癖(必須の環境変数) | ファイルごとの説明 |
| 非自明な挙動やハマりどころ | 「きれいなコードを書く」のような自明な心得 |

(出典: Claude Code Docs, Best practices for Claude Code)

各行について「これを削除したらClaudeがミスをするようになるか」を自問し、そうでなければ削る、というのがガイドの基準である。CLAUDE.mdが肥大化すると、Claudeが半分を無視するようになり、本当に重要な指示が埋もれてしまう。

具体例として、ガイドが示すCLAUDE.mdの断片は以下のようなものである。

```markdown
# Code style
- Use ES modules (import/export) syntax, not CommonJS (require)
- Destructure imports when possible (eg. import { foo } from 'bar')

# Workflow
- Be sure to typecheck when you're done making a series of code changes
- Prefer running single tests, and not the whole test suite, for performance
```

`/init`コマンドを実行すると、コードベースを解析してビルドシステムやテストフレームワーク、コードパターンを検出し、たたき台となるCLAUDE.mdを生成する。既存のCLAUDE.mdがある場合、`/init`は上書きせず改善案を提示する。

サイズの目安は1ファイルあたり200行未満である。これを超えると、コンテキスト消費が増えるだけでなく、指示への遵守率が下がる。指示が長くなりすぎた場合は、後述する`.claude/rules/`のpath指定ルールに分割するか、頻繁には使わない手順はskillに移す方が適切である。

## 階層構造とロード順序

CLAUDE.mdは複数の場所に置くことができ、スコープが広い順から狭い順にロードされる。

| スコープ | 場所 | 用途 | 共有範囲 |
|---|---|---|---|
| Managed policy | macOS: `/Library/Application Support/ClaudeCode/CLAUDE.md`、Linux/WSL: `/etc/claude-code/CLAUDE.md`、Windows: `C:\Program Files\ClaudeCode\CLAUDE.md` | 組織全体のコーディング標準、セキュリティポリシー | 組織の全ユーザー |
| User instructions | `~/.claude/CLAUDE.md` | 全プロジェクトに共通する個人の好み | 自分のみ |
| Project instructions | `./CLAUDE.md`または`./.claude/CLAUDE.md` | チーム共有のプロジェクト指示 | バージョン管理経由でチーム |
| Local instructions | `./CLAUDE.local.md` | 個人のプロジェクト固有の好み | 自分のみ(gitignore対象) |

(出典: Claude Code Docs, How Claude remembers your project)

すべてのファイルは互いを上書きするのではなく連結される。ディレクトリツリー全体では、ファイルシステムのルートから作業ディレクトリに向かって順に並び、起動したディレクトリに近い指示ほど後に読まれる。各ディレクトリ内では`CLAUDE.local.md`が`CLAUDE.md`の後に追加されるため、個人のメモがそのレベルで最後に読まれる指示になる。

作業ディレクトリより上の階層にあるCLAUDE.mdとCLAUDE.local.mdは起動時にすべて読み込まれる。作業ディレクトリの配下(サブディレクトリ)にあるCLAUDE.mdは起動時には読み込まれず、Claudeがそのサブディレクトリ内のファイルを読んだタイミングでオンデマンドに読み込まれる。これはモノレポで各チームのCLAUDE.mdを必要な時だけロードする設計に対応する。

## import構文

CLAUDE.mdファイルは`@path/to/file`構文で他のファイルをインポートできる。

```markdown
See @README.md for project overview and @package.json for available npm commands.

# Additional Instructions
- Git workflow: @docs/git-instructions.md
- Personal overrides: @~/.claude/my-project-instructions.md
```

相対パスはインポート元ファイルからの相対パスとして解決される(作業ディレクトリからではない)。再帰的なインポートは最大4ホップまで可能である。コードスパンやフェンス付きコードブロック内の`@`はインポートとして解釈されないため、パスをテキストとして言及したいだけの場合はバッククォートで囲む。

インポートによる分割はファイルの整理には役立つが、コンテキスト消費量は変わらない。インポートされたファイルも起動時に全文がロードされるためである。

初めて外部インポートを含むプロジェクトを開いた際、Claude Codeは読み込むファイルの一覧を示す承認ダイアログを表示する。拒否した場合、そのインポートは無効化されたままになり、ダイアログは再表示されない。

## AGENTS.mdとの共存

Claude Codeは`CLAUDE.md`を読み、`AGENTS.md`は読まない。他のAIコーディングツールと`AGENTS.md`を共用しているリポジトリでは、`AGENTS.md`をインポートする`CLAUDE.md`を作成することで、両方のツールが重複なく同じ指示を読める。

```markdown
@AGENTS.md

## Claude Code

Use plan mode for changes under `src/billing/`.
```

シンボリックリンクでも同様のことができる(Claude固有の追記が不要な場合)。

```bash
ln -s AGENTS.md CLAUDE.md
```

Windowsではシンボリックリンクの作成に管理者権限またはDeveloper Modeが必要なため、`@AGENTS.md`によるインポートの方が扱いやすい。

## .claude/rules/によるルールの分割

大規模プロジェクトでは、指示を`.claude/rules/`ディレクトリ配下の複数ファイルに分割できる。

```text
your-project/
├── .claude/
│   ├── CLAUDE.md           # メインの指示
│   └── rules/
│       ├── code-style.md   # コードスタイル
│       ├── testing.md      # テストの慣習
│       └── security.md     # セキュリティ要件
```

`.md`ファイルは再帰的に検出されるため、`frontend/`や`backend/`のようなサブディレクトリに整理できる。`paths`フロントマターを持たないルールは`.claude/CLAUDE.md`と同じ優先度で起動時にロードされる。

`paths`フロントマターを指定すると、そのパターンにマッチするファイルをClaudeが扱う時にだけルールが適用される。

```markdown
---
paths:
  - "src/api/**/*.ts"
---

# API Development Rules

- All API endpoints must include input validation
- Use the standard error response format
- Include OpenAPI documentation comments
```

パターンにはブレース展開も使え、複数の拡張子を1つのパターンでまとめて指定できる。

```markdown
---
paths:
  - "src/**/*.{ts,tsx}"
  - "lib/**/*.ts"
  - "tests/**/*.test.ts"
---
```

path指定ルールが発火するのは、Claudeがマッチするファイルを読んだ時であり、すべてのツール呼び出し時ではない。これにより、無関係な作業をしている間はコンテキストに余計な指示を含めずに済む。

`.claude/rules/`はシンボリックリンクにも対応しているため、複数プロジェクトで共有したいルール集を1箇所で管理し、各プロジェクトにリンクすることができる。

```bash
ln -s ~/shared-claude-rules .claude/rules/shared
ln -s ~/company-standards/security.md .claude/rules/security.md
```

個人用のルールは`~/.claude/rules/`に置くと、自分の全プロジェクトに適用される。ユーザーレベルのルールはプロジェクトレベルのルールより先に読み込まれるため、プロジェクトのルールの方が優先度が高くなる。

## 組織全体への配布

組織はmanaged policyの場所に配置したCLAUDE.mdを、MDMやGroup Policy、Ansibleなどの構成管理ツールで全開発者のマシンに配布できる。個々のユーザー設定では除外できない点が特徴である。`managed-settings.json`内の`claudeMd`キーを使えば、別ファイルを配布せずに直接テキストを埋め込むこともできる。

```json
{
  "claudeMd": "Always run `make lint` before committing.\nNever push directly to main."
}
```

Managed CLAUDE.mdとmanaged settingsの使い分けは、技術的な強制が必要か、振る舞いの指針でよいかで判断する。

| 関心事 | 設定先 |
|---|---|
| 特定のツール・コマンド・パスをブロックする | Managed settings: `permissions.deny` |
| サンドボックス分離を強制する | Managed settings: `sandbox.enabled` |
| 環境変数やAPIプロバイダのルーティング | Managed settings: `env` |
| コードスタイルや品質のガイドライン | Managed CLAUDE.md |
| データ取り扱いやコンプライアンスの注意 | Managed CLAUDE.md |
| Claudeへの振る舞いの指示 | Managed CLAUDE.md |

設定ルールはClaudeの判断に関わらずクライアント側で強制されるが、CLAUDE.mdの指示はClaudeの振る舞いを形作るものであって、強制の仕組みではない。

モノレポで他チームのCLAUDE.mdが不要にロードされる場合は、`claudeMdExcludes`でパスまたはglobパターンを指定して除外できる。

```json
{
  "claudeMdExcludes": [
    "**/monorepo/CLAUDE.md",
    "/home/user/monorepo/other-team/.claude/rules/**"
  ]
}
```

managed policyのCLAUDE.mdだけは除外できない。組織全体の指示が常に適用されることを保証するためである。

### 参考文献

- [How Claude remembers your project - Claude Code Docs](https://code.claude.com/docs/en/memory)
- [Best practices for Claude Code - Claude Code Docs](https://code.claude.com/docs/en/best-practices)
