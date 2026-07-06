---
title: "3階層エージェント構造"
---

## なぜエージェントを分けるのか

Claude Codeの `Agent` ツールを使うと、サブエージェントを起動できます。各サブエージェントは独立したコンテキストウィンドウを持ち、特定のツールセットと指示を与えられます。

最初は1つのClaude Codeセッションで全部やっていました。リサーチも、成果物生成も、コードレビューも。何が起きたかというと、長い会話の後半でコンテキストが汚染され、前半で調べた事実を忘れたり、混同したりするようになりました。

エージェントを分けると、各エージェントのコンテキストがクリーンに保たれます。リサーチ結果はファイル経由で受け渡すので、情報の損失も制御できます。

## 2階層から3階層への進化

最初は2階層でした。

```
CEO → researcher × N
```

CEOが直接researcherを複数起動し、結果を受け取り、集約する構造です。これには2つの問題がありました。

**問題1: CEOのコンテキストが肥大化する。** 5つのresearcherの結果を全部CEOが読むと、CEO自身のコンテキストウィンドウが埋まり、批判的検証の品質が落ちます。

**問題2: カバレッジループをCEOが手動で回す必要がある。** 「この部分の情報が足りないからresearcherを追加起動」という判断をCEOが毎回やるのは、戦略層の仕事ではありません。

そこで間にresearch-loop（ループオーナー）を挟み、3階層にしました。

```
CEO（戦略層）
  └── research-loop（実行層・ループオーナー）
        └── researcher × N（収集層）
```

**CEOは「何を調べるか」を設計する。research-loopは「どう調べるか」を自律的に回す。** この分離が、2ヶ月の運用で最も効いた設計判断です。

## 各階層の責務

### CEO（戦略層）

```yaml
model: opus
tools: Read, Write, Edit, Bash, WebSearch, WebFetch, Agent
```

CEOの仕事は5つです。

1. **目標分析** — ユーザーの目標をWhat/Why/Who/Constraintsで分解する
2. **Phase -1（メタリサーチ）** — 「何を調べるべきか」自体をリサーチして、サブゴールマップを作る
3. **タスクプラン作成** — サブゴールマップをresearch-loopへの委譲メッセージにまとめる
4. **批判的検証** — research-loopから返ってきた集約レポートを検証する
5. **成果物生成指示** — design-loopを起動して最終成果物を作らせる

CEOがやらないこと: 個別の検索、情報源の特定、researcherの管理、カバレッジ判定。これらはすべてresearch-loopの仕事です。

### research-loop（実行層・ループオーナー）

```yaml
model: opus
tools: Agent, Read, Write, Edit, WebSearch, WebFetch
maxTurns: 50
```

research-loopの仕事は「ループを回す」ことです。

```
Phase 0: 情報源メタリサーチ（どんな情報源があるか）
  ↓
Phase 1: researcher分配・並列起動
  ↓
Phase 2: 結果評価（カバレッジ判定）
  ↓
Phase 3: ループ判定
  → カバレッジ不十分 → Phase 1に戻る
  → カバレッジ十分 → Phase 4（集約レポート出力）
```

停止条件は3つ同時に満たす必要があります。

1. カバレッジスコア ≥ 80%
2. 前ラウンド比改善率 < 5%（情報飽和）
3. `absent-unverified` 状態のサブゴールが0件

3番目は後から追加したルールです。「競合が存在しない」という結論が検索不足に起因していた失敗が2回続いたため、「不在結論は深掘りで検証するまでcoveredにしない」というガードレールになりました。

### researcher（収集層）

```yaml
model: sonnet
tools: WebSearch, WebFetch, Read, Glob, Grep
maxTurns: 40
```

researcherは「指示された範囲を調べて、ファイルに書き出す」だけです。判断も解釈もしません。

research-loopからの指示には以下が含まれます。

- **questions**: 回答すべき具体的な問い
- **sources**: 当たるべき情報源URLのリスト
- **search_queries**: 推奨する検索クエリ（最低8件）
- **scope**: 他のresearcherとの分担境界
- **output**: 出力先パス

「○○を調べて」のような曖昧な指示は禁止しています。曖昧な指示は曖昧な結果を返します。

## モデル配分の原則

判断・統括・ループ制御にはopus、実行・検索にはsonnetを使います。

根拠: ループオーナー（research-loop、design-loop）の評価・再計画の判断品質が最終成果物の品質を決めます。「この情報は十分か？」「何が足りないか？」という判断を安い（速い）モデルに任せると、カバレッジの甘いレポートが出てきます。

逆に、researcherに高いモデルを使う意味は薄いです。researcherの仕事は「指示通りに検索して結果を書く」ことであり、判断力よりも作業速度が重要です。

## Developer系統（ソフトウェア開発）

同じ3階層パターンをソフトウェア開発にも適用しています。

```
developer（設計・アーキテクチャ判断）
  └── code-loop（実装ループオーナー）
        ├── coder × N（ファイル変更の実行）
        └── reviewer（コードレビュー）
```

developerが実装計画を作り、code-loopがcoder分配→レビュー→テスト→修正のループを回します。パターンは同じです。「何を作るか」を設計する層と「どう作るか」を回す層を分ける。

## 直接起動系（単発タスク）

3階層を経由するほどでもない単発タスクには、エージェントを直接起動します。

- **researcher** — 「○○を調べて」系の単発リサーチ
- **reviewer** — 文章やコードの批判的レビュー
- **planner** — タスクの手順分解

これらはsonnetで動かします。CEOを起動するまでもない軽いタスクに使います。

## ユーティリティ系

- **archivist** — メモリファイルの整理・圧縮
- **obsidian-secretary** — Obsidianのナレッジ管理
- **reflection-agent** — 会話の振り返り・学び抽出

これらは自動的にまたはプロアクティブに起動されます。

## エージェント間の情報伝達

エージェント間の情報伝達はファイル経由です。サブエージェントは親の会話履歴を引き継ぎません。

```
CEO → research-loop: delegation message + タスクプランファイル
research-loop → researcher: delegation message（questions/sources等）
researcher → research-loop: .claude/outputs/research/*-raw.md
research-loop → CEO: .claude/reports/research-report.md
```

ファイル経由にすることで、情報の損失が明示的になります。「このファイルに書いてないことは伝わっていない」というルールです。口頭（delegation message）だけに頼ると、意図が正確に伝わらないことがあります。
