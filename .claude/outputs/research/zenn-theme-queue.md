# Zenn有料本テーマ候補一覧（50本）

リサーチ日: 2026-07-06
リサーチソース: Zennブックストア、Zenn/Qiitaトレンド、技術書市場調査、検索需要分析

---

## AI・LLM・エージェント（11本）

### 1. Claude Code hooks & agents 実践パターン集 [済]
- ジャンル: AI
- ニッチ度: 高（hooks/agents/subagentの設計パターンを体系化した本は皆無）
- 需要根拠: Zennブックストアで「Claude Agent SDK でつくる！対話型AIエージェント開発」が¥500で注目本入り。Qiitaで「ClaudeCode」タグが月間トレンド常連。技評・SBクリエイティブから入門書が出版済みだが、hooks/agents設計パターンに特化した本はない
- 差別化ポイント: CLAUDE.md設計、hooks（SessionStart/Stop/PreToolUse等）の実用パターン、subagent分離設計、memory運用パターンを実コード付きで集成
- 想定章数: 8

### 2. MCP（Model Context Protocol）サーバー自作入門
- ジャンル: AI
- ニッチ度: 高（概念解説記事は大量にあるが「自作」にフォーカスした体系的な本がない）
- 需要根拠: Qiitaで「MCPサーバーおすすめ」「MCP総まとめ」が2026年トレンド上位。公開MCPサーバーは3,000以上だが、日本語での自作ガイドは断片的なブログ記事のみ
- 差別化ポイント: JSON-RPC仕様の解説→TypeScript/Pythonでのサーバー実装→テスト→公開までを一気通貫。既存3000+サーバーのアーキテクチャ比較分析を含む
- 想定章数: 8

### 3. RAGシステム設計パターン集 ── 検索精度を上げる15の実装テクニック
- ジャンル: AI
- ニッチ度: 中（LangChain/LangGraph本は技評から出版済みだが、RAGの精度改善に特化した本はない）
- 需要根拠: 「LangChainとLangGraphによるRAG・AIエージェント実践入門」が技評のエンジニア選書で好評。企業のRAG導入が本格化し「精度が出ない」という運用課題が増加中
- 差別化ポイント: チャンキング戦略比較、ハイブリッド検索（密+疎）、リランキング、クエリ変換、評価メトリクス（RAGAS等）を実装コード付きで比較。英語圏の最新論文テクニックを日本語で解説
- 想定章数: 8

### 4. AIコードエディタ完全比較 ── Cursor / Windsurf / Claude Code の使い分け実践ガイド
- ジャンル: AI
- ニッチ度: 中（比較ブログ記事は大量だが、実際のワークフロー設計まで踏み込んだ本がない）
- 需要根拠: 「Cursor vs Windsurf」がQiita/Zennで継続的にトレンド入り。エンジニアの日常ツールとして定着しつつあるが、使い分け指針が確立していない
- 差別化ポイント: 3ツールの実操作比較（同一タスクを各ツールで実行→所要時間・品質・コスト比較）、ハイブリッド運用戦略、チーム導入時の設定ガイドを含む
- 想定章数: 7

### 5. プロンプトエンジニアリング実践 ── コード生成の精度を2倍にするテクニック
- ジャンル: AI
- ニッチ度: 中（入門記事は大量だが、コード生成に特化した体系的なプロンプト設計本がない）
- 需要根拠: 2026年のエンジニアはAIを使いこなすことが前提。生成AI利用率54.7%超。しかし「プロンプトの書き方」が属人化しておりベストプラクティスが未整理
- 差別化ポイント: Claude/GPT/Gemini各モデルの特性別プロンプト設計、System Prompt設計パターン、Few-shot/Chain-of-Thought/ReActの使い分け、実測ベンチマーク付き
- 想定章数: 8

### 6. ローカルLLM実践ガイド ── Ollama + Open WebUI で社内AIを構築する
- ジャンル: AI
- ニッチ度: 高（クラウドLLM本は多いがローカルLLMの構築・運用に特化した日本語本がない）
- 需要根拠: セキュリティ要件から社内LLMへの需要が急増。Ollama、llama.cpp、vLLMの利用が拡大中だが日本語での体系的ガイドがない
- 差別化ポイント: GPU選定→Ollama導入→モデル選定（Llama 3/Gemma 2/Phi-3比較）→Open WebUI構築→RAG統合→運用監視まで一貫
- 想定章数: 8

### 7. LLMアプリのコスト最適化 ── トークン設計・キャッシュ・モデル選定の実践
- ジャンル: AI
- ニッチ度: 高（LLMの使い方本は多いが、コスト管理に特化した本が皆無）
- 需要根拠: LLM API料金の仕組みに関するZenn記事が人気。企業のLLM利用でコスト爆発が頻発し、最適化ノウハウの需要が高い
- 差別化ポイント: 各社API料金構造の比較、プロンプトキャッシュ設計、バッチAPI活用、モデルルーティング（高コストモデル→低コストモデルのフォールバック）、トークン削減テクニック
- 想定章数: 7

### 8. AI駆動テスト自動化 ── LLMでE2Eテスト・ユニットテストを自動生成する
- ジャンル: AI
- ニッチ度: 高（テスト生成にLLMを使う実践ガイドが皆無）
- 需要根拠: Claude Code/Cursorでのコード生成が普及する一方、テストの自動生成は品質担保が難しく実践ノウハウが不足。「AI時代のテスト戦略」への関心が高まっている
- 差別化ポイント: LLMによるテストコード生成のプロンプト設計、カバレッジ向上戦略、変異テスト連携、CI/CDパイプラインへの組み込み方を実例付きで解説
- 想定章数: 7

### 9. Dify/Flowise実践入門 ── ノーコードでAIワークフローを構築する
- ジャンル: AI
- ニッチ度: 中（ブログ記事は増えているが体系的な日本語本がない）
- 需要根拠: ノーコード/ローコードAI構築ツールへの需要が急増。非エンジニアのAI活用拡大に伴い、DifyやFlowiseのような視覚的AIワークフロー構築ツールが注目
- 差別化ポイント: Dify vs Flowise vs LangFlow比較、実業務シナリオ（問い合わせ対応bot、社内文書検索、データ抽出）の実装例、自社LLMとの接続方法
- 想定章数: 8

### 10. LLM Ops入門 ── 本番環境でLLMアプリを安定運用するための実践ガイド
- ジャンル: AI
- ニッチ度: 高（MLOpsの延長線上だがLLM特有の運用課題に特化した本がない）
- 需要根拠: LLMアプリの本番投入が増えるにつれ、ハルシネーション監視、レイテンシ管理、コスト管理、プロンプトバージョニングの課題が顕在化
- 差別化ポイント: LangSmith/Langfuse/Phoenix等の評価ツール比較、プロンプトのバージョン管理、A/Bテスト設計、ガードレール実装、インシデント対応パターン
- 想定章数: 8

### 11. 構造化出力（Structured Outputs）実践ガイド ── LLMの出力を確実にパースする技術
- ジャンル: AI
- ニッチ度: 高（Structured Outputs自体は各社APIで提供されているが、設計パターンを体系化した本がない）
- 需要根拠: OpenAI/Anthropic/Gemini各社がStructured Outputsを提供。実業務でJSON出力を確実に取得するニーズが高いが、スキーマ設計やエラーハンドリングの知見が散在
- 差別化ポイント: 各社API比較、JSON Schema/Pydantic/Zodでのスキーマ設計、ネスト構造の扱い、リトライ戦略、実業務での型安全パイプライン構築
- 想定章数: 7

---

## Web・フロントエンド（9本）

### 12. Hono実践入門 ── エッジで動く軽量TypeScriptフレームワーク
- ジャンル: Web
- ニッチ度: 中（Cloudflare Workers本は技評から2冊出版済みだが、Honoフレームワーク単体に特化した体系的な本がない）
- 需要根拠: Honoは日本発のフレームワークで国内コミュニティが活発。Cloudflare Workers/Deno/Bun/Node.js全環境で動くマルチランタイム対応が注目を集めている
- 差別化ポイント: Honoの設計思想→基本API→ミドルウェア→D1/KV/R2連携→認証→デプロイ（Workers/Deno Deploy/Vercel）までを一冊で網羅。Next.jsとの使い分け指針を含む
- 想定章数: 8

### 13. htmx実践入門 ── JavaScriptを書かずにモダンWebアプリを作る
- ジャンル: Web
- ニッチ度: 高（日本語の入門記事は増えているが体系的な本がない。gihyo.jpに2026年2月の入門記事あり）
- 需要根拠: SPA疲れの揺り戻しとして、サーバーサイドHTMLレンダリングの再評価が進行中。htmxはその象徴的ライブラリ。Qiita/Zennで入門記事が継続的に投稿されている
- 差別化ポイント: htmxの設計思想（Hypermedia as the Engine of Application State）→基本属性→サーバーサイドフレームワーク（Go/Python/Ruby）との連携パターン→SPA代替としてのユースケース比較
- 想定章数: 7

### 14. Astro 5 実践ガイド ── コンテンツサイトを高速に構築する
- ジャンル: Web
- ニッチ度: 高（Next.js/Nuxt本は大量にあるがAstro単体の日本語本がない）
- 需要根拠: Astro 5.0リリースで「Next.js以外の選択肢」としての注目度が上昇。コンテンツサイト・ブログ・ドキュメントサイトでの採用が増加
- 差別化ポイント: Astroのアイランドアーキテクチャ→Content Collections→React/Svelte/Vue統合→SSG/SSRモード→Cloudflare/Vercelデプロイ→パフォーマンス最適化
- 想定章数: 8

### 15. SvelteKit実践入門 ── Reactに依存しないモダンWeb開発
- ジャンル: Web
- ニッチ度: 高（Svelte 5でRunes記法が導入され注目度上昇。日本語の体系的な本がほぼない）
- 需要根拠: Svelte 5のRunes記法刷新で学び直し需要が発生。State of JS調査でSvelteの満足度は常にトップクラスだが日本語リソースが不足
- 差別化ポイント: Svelte 5のRunes記法→SvelteKitのルーティング→SSR/SSG→form actions→load関数→デプロイまで。Reactとの設計思想比較を含む
- 想定章数: 8

### 16. tRPCで実現する型安全なフルスタック開発
- ジャンル: Web
- ニッチ度: 高（日本語の比較記事はあるが、tRPC単体の実践入門本がない）
- 需要根拠: TypeScript monorepoでのAPI開発でtRPCの採用が増加。v11でReact Server Components対応。しかし日本語での体系的な学習リソースがない
- 差別化ポイント: tRPCの型推論の仕組み→Router/Procedure設計→React Query統合→認証/認可→エラーハンドリング→Next.js App Router統合→REST/GraphQLとの使い分け判断フロー
- 想定章数: 7

### 17. WebSocket実践入門 ── リアルタイム通信アプリの設計と実装
- ジャンル: Web
- ニッチ度: 中（Zennブックストアに無料の「WebSocket入門からリアルタイムオンラインゲームまで」があるが有料で深い本がない）
- 需要根拠: チャットアプリ、リアルタイムコラボ、ゲーム等でWebSocketの需要が継続的。Server-Sent Events、WebTransportとの比較需要も増加
- 差別化ポイント: WebSocket/SSE/WebTransport比較→認証設計→再接続戦略→スケーリング（Redis Pub/Sub）→Cloudflare Durable Objects活用→負荷テスト
- 想定章数: 8

### 18. Web Componentsで作るフレームワーク非依存のUIライブラリ
- ジャンル: Web
- ニッチ度: 高（React/Vue/Svelteのコンポーネントライブラリ作成本はあるが、Web Components標準に特化した日本語本がない）
- 需要根拠: デザインシステムの文脈でフレームワーク非依存のコンポーネントへの需要が増加。Lit/Stencilの実務採用も進んでいる
- 差別化ポイント: Custom Elements/Shadow DOM/HTML Templates→Lit活用→Storybook統合→npm公開→React/Vue/Svelteとの相互運用→アクセシビリティ
- 想定章数: 8

### 19. ブラウザ拡張機能開発実践 ── Chrome Extension Manifest V3 完全ガイド
- ジャンル: Web
- ニッチ度: 高（Manifest V3への移行で需要があるが体系的な日本語本がない）
- 需要根拠: Manifest V2の廃止に伴い、V3への移行需要が発生。AI連携拡張機能の開発需要も増加中
- 差別化ポイント: V3のService Worker設計→Content Script→Message Passing→Storage API→OAuth連携→AI API統合→Chrome Web Store公開→Firefox対応
- 想定章数: 8

### 20. Server Componentsの設計原則 ── RSCで変わるReactアプリ設計
- ジャンル: Web
- ニッチ度: 中（React/Next.js本でRSCに触れるものはあるが、RSCの設計原則に特化した本がない）
- 需要根拠: React 19でRSCが標準に。2026年のフロントエンドではRSC前提のアーキテクチャ設計が必須スキルに。「クライアント/サーバー境界をどこに引くか」という設計判断に悩むエンジニアが多い
- 差別化ポイント: RSCのメンタルモデル→Client/Server境界の設計判断→データフェッチパターン→Server Actions→キャッシュ戦略→パフォーマンス計測→移行ガイド
- 想定章数: 7

---

## インフラ・DevOps（10本）

### 21. Pulumi実践入門 ── TypeScriptでインフラを書く
- ジャンル: インフラ
- ニッチ度: 高（Terraform/CDK本は技評から出版済みだが、Pulumi単体の日本語本がない）
- 需要根拠: Pulumiは80+プロバイダ対応でTerraform代替として注目度上昇中。「PulumiはIaCの革命児になれるか」がZennで話題に。インフラ構築初期工数70%削減の事例あり
- 差別化ポイント: Pulumi CLI→TypeScriptでAWS/GCP構築→State管理→テスト（pulumi.testing）→CI/CD統合→Terraformからの移行ガイド→AIとの統合（Pulumi AI）
- 想定章数: 8

### 22. Nix/devenv実践入門 ── 再現可能な開発環境を宣言的に管理する
- ジャンル: DevOps
- ニッチ度: 高（Zennで「ちいさくはじめる Nix」が無料で注目本入り。有料で深い実践本がない）
- 需要根拠: 開発環境の再現性問題は全エンジニア共通。Nixpkgs 100,000+パッケージ、日経・OPTiM等の国内企業が採用開始。Docker Composeとの使い分け需要
- 差別化ポイント: Nix言語基礎→Flakes→devenvでのプロジェクト設定→Docker Compose/Dev Containersとの比較→CI/CDでの活用→NixOS（発展編）
- 想定章数: 8

### 23. Dev Containers完全ガイド ── チーム開発環境の標準化
- ジャンル: DevOps
- ニッチ度: 中（Qiita/Zennに入門記事は多いが体系的な本がない）
- 需要根拠: リモートワーク定着で「開発環境の統一」需要が継続的。VS Code + Docker前提のDev Containersは最も実践的な解。GitHub Codespacesとの連携も注目
- 差別化ポイント: devcontainer.json設計→Features活用→docker-compose統合→マルチサービス構成→GitHub Codespaces→チームテンプレート管理→パフォーマンスチューニング
- 想定章数: 7

### 24. GitHub Actions実践レシピ集 ── CI/CDの「あの作業」を自動化する50パターン
- ジャンル: DevOps
- ニッチ度: 中（「GitHub CI/CD実践ガイド」が技評から出版済みだが、レシピ集形式の実用パターン本がない）
- 需要根拠: GitHub Actionsは事実上のCI/CD標準。体系的な入門書はあるが「こういう時どう書く？」というレシピへの需要が高い
- 差別化ポイント: セキュリティスキャン/依存関係更新/リリース自動化/モノレポ対応/マトリクスビルド/Self-hosted runner/Composite Actions/Reusable Workflows等の具体パターンを逆引き形式で
- 想定章数: 8

### 25. Cloudflare全サービスガイド ── Workers / D1 / R2 / KV / Pages を使いこなす
- ジャンル: インフラ
- ニッチ度: 中（Workers単体本は出版済みだが、Cloudflareのサービス群を横断的に解説した本がない）
- 需要根拠: Cloudflareのサービス拡大が急速。Workers+D1+R2+KV+Pagesの組み合わせで「AWSなしのフルスタック」が実現可能に。しかしサービス間の連携ノウハウが散在
- 差別化ポイント: 各サービスの特性と制限→サービス間連携パターン→認証（Cloudflare Access）→料金最適化→AWS/Vercelとのコスト比較→実アプリ構築チュートリアル
- 想定章数: 9

### 26. Raspberry Pi自宅サーバー構築 ── Docker + Tailscale でセキュアなホームラボ
- ジャンル: インフラ
- ニッチ度: 中（Zennで「Raspberry Pi自宅サーバー入門」が¥1,200のベストセラー。異なる切り口で差別化可能）
- 需要根拠: 既存のRaspberry Pi自宅サーバー本がZennベストセラーに入っている実績あり。Docker+VPN（Tailscale/WireGuard）でのセキュアな構築という切り口が未開拓
- 差別化ポイント: Raspberry Pi OS設定→Docker Compose→TailscaleメッシュVPN→Nextcloud/Gitea/Immich等のセルフホスト→監視（Uptime Kuma）→バックアップ自動化→セキュリティ硬化
- 想定章数: 8

### 27. Terraform State管理とチーム運用の実践
- ジャンル: インフラ
- ニッチ度: 高（Terraform入門本は多いが、State管理・チーム運用・リファクタリングに特化した本がない）
- 需要根拠: Terraformの導入企業は多いが、State分割・Lock管理・Import・Moved Block・モジュール分割等のチーム運用知見が不足
- 差別化ポイント: State Backend選定→State分割戦略→Import/Moved Block→モジュール設計→Workspaces運用→tfmigrate活用→レビュー体制→Terraformリファクタリングパターン
- 想定章数: 7

### 28. OpenTelemetry × Grafana 実践オブザーバビリティ
- ジャンル: インフラ
- ニッチ度: 中（「入門OpenTelemetry」がO'Reilly Japanから出版済みだが概念中心。Grafanaとの統合実践本がない）
- 需要根拠: OpenTelemetryがCNCFで卒業プロジェクトに。Grafana Stack（Grafana/Loki/Tempo/Mimir）との統合需要が高いが、実装ガイドが不足
- 差別化ポイント: OTel SDK計装→Collector設定→Grafana Stack構築→ダッシュボード設計→アラートルール→SLO定義→コスト管理→Prometheus/Datadogとの比較
- 想定章数: 8

### 29. Kubernetes運用のアンチパターン ── 本番障害から学ぶ設計・運用ミス集
- ジャンル: インフラ
- ニッチ度: 高（Kubernetes入門本は多数あるが、障害パターンと回避策に特化した本がない）
- 需要根拠: Kubernetes導入後の運用課題（OOM Kill、Pod Eviction、DNS解決遅延、Ingress設定ミス等）に悩むチームが多い。障害事例の体系的な集成需要
- 差別化ポイント: Resource Limits/Requests設計ミス→HPA暴走→PDB未設定→NetworkPolicy漏れ→Secret管理→Node Drain時の事故等を障害シナリオ形式で解説
- 想定章数: 8

### 30. セキュリティヘッダー完全ガイド ── CSP / CORS / HSTS を正しく設定する
- ジャンル: セキュリティ
- ニッチ度: 高（Zennで「OAuthとOIDC入門」が¥1,500でベストセラー入り。HTTPセキュリティヘッダーに特化した本がない）
- 需要根拠: Content-Security-Policy、CORS、HSTS等のセキュリティヘッダー設定は全Web開発者に必要だが、公式ドキュメントが難解で実践ガイドが不足
- 差別化ポイント: 各ヘッダーの目的と攻撃ベクトル→CSP段階的導入→CORS実装パターン→SameSite Cookie→Permissions Policy→CDN/リバースプロキシとの相互作用→テストツール
- 想定章数: 7

---

## データ・バックエンド（8本）

### 31. DuckDB実践活用 ── ローカルで高速データ分析を始める
- ジャンル: データベース
- ニッチ度: 中（impress top gearから「DuckDB実践入門」が出版済みだが、ユースケース特化・日本のデータ分析者向けの実践本としての余地あり）
- 需要根拠: DuckDBは「まずDuckDBで試す」が定番になりつつある。Pandas代替としての注目度も上昇。dbt-duckdbの組み合わせも話題
- 差別化ポイント: DuckDB CLIの使い方→Python/R統合→Parquet/CSV/JSON読み込み→dbt-duckdb連携→Jupyter活用→MotherDuck（クラウド版）→Pandasからの移行ガイド
- 想定章数: 7

### 32. SQLiteローカルファースト開発 ── Turso / libSQL でオフライン対応アプリを作る
- ジャンル: データベース
- ニッチ度: 高（ローカルファーストの概念記事は増えているが体系的な実装ガイドがない）
- 需要根拠: AIエージェント時代のDB設計でTurso/libSQLベースのLocal-Firstが注目。ブラウザSQLite+OPFSの組み合わせも話題。PostgreSQL一択からの揺らぎが起きている
- 差別化ポイント: ローカルファーストの設計原則→SQLite WALモード→Turso/libSQL→ブラウザSQLite（OPFS）→同期戦略（CRDT vs Last-Write-Wins）→オフライン対応→React/Svelteとの統合
- 想定章数: 8

### 33. Supabase実践入門 ── オープンソースBaaSでフルスタックアプリを作る
- ジャンル: バックエンド
- ニッチ度: 高（Firebase本は多数あるがSupabase単体の日本語本がほぼない）
- 需要根拠: Supabaseは2024年にGA。Firebase代替として急成長中。PostgreSQL+Row Level Security+リアルタイム購読+Auth+Storageの統合は魅力だが、日本語書籍が不足
- 差別化ポイント: Supabase設計思想→Auth設定→Database設計（RLS）→リアルタイム→Storage→Edge Functions→Firebaseからの移行ガイド→料金比較
- 想定章数: 8

### 34. dbt入門 ── データ変換パイプラインを「ソフトウェアエンジニアリング」する
- ジャンル: データ
- ニッチ度: 中（Zennに「dbt入門」の無料本があるが浅い。日本語の実践書籍がない）
- 需要根拠: NTTデータが「dbtで実現するAI時代のデータ基盤」を発信するなど大企業での採用が進行。データエンジニアリングのT（Transform）を担う標準ツールとして定着しつつある
- 差別化ポイント: dbtの設計思想→モデル設計パターン→テスト/ドキュメント→Jinja活用→BigQuery/Snowflake接続→dbt Cloud vs dbt Core→DuckDBローカル開発→CI/CD統合
- 想定章数: 8

### 35. Stripe決済実装パターン集 ── SaaS課金・サブスクリプション・マーケットプレイスの実装
- ジャンル: バックエンド
- ニッチ度: 高（Stripe公式ドキュメントは充実だが日本語書籍が皆無。ブログ記事は断片的）
- 需要根拠: SaaS開発でStripe決済実装は必須だが「APIドキュメントが読みにくい」との声が多い。Webhook設計、サブスクリプション管理、Connect（マーケットプレイス決済）の実装知見が不足
- 差別化ポイント: Checkout Session→Payment Intent→Subscription→Customer Portal→Webhook設計→Connect（Express/Custom）→請求書→税金処理→テスト環境→本番運用
- 想定章数: 9

### 36. PostgreSQL運用アンチパターン ── スロークエリからデッドロックまで
- ジャンル: データベース
- ニッチ度: 高（PostgreSQL入門本はあるが運用トラブルシュートに特化した本がない）
- 需要根拠: PostgreSQLはWebアプリのデフォルトDBだが、インデックス設計ミス、N+1、VACUUM設定、接続プール枯渇等の運用課題は入門書では扱わない
- 差別化ポイント: EXPLAIN ANALYZE読み方→インデックス設計→VACUUM/ANALYZE→接続プール（PgBouncer）→パーティショニング→レプリケーション→監視（pg_stat_statements）→マイグレーション戦略
- 想定章数: 8

### 37. GraphQL設計ベストプラクティス ── スキーマ設計からN+1対策まで
- ジャンル: バックエンド
- ニッチ度: 中（GraphQL入門本は数冊あるが、設計のベストプラクティスに特化した本がない）
- 需要根拠: GraphQLの採用企業は増えているが「スキーマが肥大化した」「N+1で遅い」「認可が複雑」等の運用課題が顕在化
- 差別化ポイント: Relay仕様準拠のスキーマ設計→DataLoaderパターン→Persisted Queries→Federation→認可設計→エラーハンドリング→コスト分析→REST→GraphQL移行判断フロー
- 想定章数: 8

### 38. Drizzle ORM実践入門 ── TypeScriptネイティブなDB操作の新標準
- ジャンル: バックエンド
- ニッチ度: 高（Prisma本は数冊あるがDrizzle ORMの日本語本が皆無）
- 需要根拠: Drizzle ORMはPrismaの代替として急成長中。TypeScriptの型推論を最大限活用し、SQLに近い記法で直感的。Next.js/Honoプロジェクトでの採用が増加
- 差別化ポイント: Drizzle ORMの設計思想→スキーマ定義→クエリビルダー→マイグレーション（drizzle-kit）→リレーション→トランザクション→Prismaとの比較→Next.js/Hono統合
- 想定章数: 7

---

## 言語・ランタイム（6本）

### 39. Gleam入門 ── 型安全な関数型言語でWebバックエンドを作る
- ジャンル: 言語
- ニッチ度: 高（日本語のGleam本が皆無。2025-2026年で最も注目度が上昇している新言語の一つ）
- 需要根拠: GleamはBEAM（Erlang VM）上で動く型安全な関数型言語。Rustに似た記法で人気が急上昇中。大規模システム・スタートアップで採用開始。日本語リソースがほぼゼロ
- 差別化ポイント: Gleamの型システム→パターンマッチ→OTPとの連携→Phoenixとの比較→Webアプリ構築→JavaScript連携（gleam_javascript）→デプロイ
- 想定章数: 8

### 40. Zig言語入門 ── Cの代替となる次世代システムプログラミング
- ジャンル: 言語
- ニッチ度: 高（Amazon Kindleに「Zigプログラミング入門」があるが薄い。体系的な日本語本がない）
- 需要根拠: ZigはCの代替としてシステムプログラミング分野で注目度上昇中。コンパイル速度がLLVM比約5倍。Bunのランタイムに採用されたことで知名度が急上昇
- 差別化ポイント: Zigの設計思想（安全性とパフォーマンスの両立）→メモリ管理→C相互運用→ビルドシステム→クロスコンパイル→Bun/TigerBeetleでの採用事例分析
- 想定章数: 8

### 41. Mojo実践入門 ── Pythonの100倍速いAI開発言語
- ジャンル: 言語
- ニッチ度: 高（2026年5月にMojo 1.0.0 beta 1リリース。日本語本が皆無）
- 需要根拠: MojoはPythonの後継としてAI開発分野で注目。Python互換の構文+静的型推論+高速実行。TIOBE 51位で急上昇中
- 差別化ポイント: Mojo設計思想→Python構文との互換性→型システム→SIMD/Vectorization→Pythonモジュール連携→AIモデル推論の高速化事例→Rustとの比較
- 想定章数: 7

### 42. Tauri 2実践入門 ── Rustバックエンド×Web UIでデスクトップ&モバイルアプリ開発
- ジャンル: モバイル/デスクトップ
- ニッチ度: 高（ブログ記事・連載はあるが日本語書籍がない。Tauri 2.0でモバイル対応が追加された）
- 需要根拠: Electronの代替として注目度上昇。バンドルサイズ10MB以下、メモリ30-50MB。2024年にTauri 2.0正式版到達でデスクトップ+モバイル両対応に
- 差別化ポイント: Tauri 2.0アーキテクチャ→Rustバックエンド→React/Svelte/Vue統合→IPC設計→プラグインシステム→iOS/Android対応→自動更新→配布→Electronからの移行
- 想定章数: 8

### 43. Bun実践ガイド ── Node.js互換の高速JavaScriptランタイム
- ジャンル: 言語/ランタイム
- ニッチ度: 高（日本語のBun単体の体系的な本がない）
- 需要根拠: BunはNode.js互換でありながらテスト・バンドラー・パッケージマネージャーを内蔵した高速ランタイム。npm installの代替としての利用が拡大中
- 差別化ポイント: Bunのアーキテクチャ（Zig + JavaScriptCore）→Node.js互換性→Bun.serve→テストランナー→バンドラー→npm互換→Dockerデプロイ→パフォーマンスベンチマーク
- 想定章数: 7

### 44. Rust × WebAssembly実践入門 ── ブラウザで動くネイティブ性能アプリ開発
- ジャンル: 言語/Web
- ニッチ度: 中（Wasm入門記事は多いがRust×Wasmの実践的な日本語本がない）
- 需要根拠: 2025年はGCとコンポーネントモデルが整い、ブラウザ外活用も現実的に。画像処理/暗号化/PDF生成等のCPU集約処理をブラウザで実行するニーズ増加
- 差別化ポイント: wasm-pack/wasm-bindgen→Rust→Wasm→JS連携→メモリ管理→パフォーマンス測定→実用例（画像処理/Markdownパーサー/SQLiteブラウザ版）→Wasmtime（ブラウザ外）
- 想定章数: 8

---

## 設計・開発手法（4本）

### 45. モノレポ設計と運用 ── pnpm + Turborepo で始めるモダンなリポジトリ管理
- ジャンル: 設計・開発手法
- ニッチ度: 高（ブログ記事は増えているが体系的な日本語本がない）
- 需要根拠: pnpm + Turborepoの組み合わせが2026年のモノレポ標準に。破綻したサブモジュール構成からの移行事例が複数報告されている。しかし設計判断の指針がブログ記事に散在
- 差別化ポイント: モノレポのメリット/デメリット判断→pnpm workspaces→Turborepo設定→パッケージ分割戦略→共有パッケージ設計→Changesets→CI/CD→Nx比較→移行ガイド
- 想定章数: 8

### 46. API設計の原則 ── REST / GraphQL / gRPC / tRPC の選定と設計パターン
- ジャンル: 設計・開発手法
- ニッチ度: 中（各API形式の入門本はあるが横断的な選定ガイドがない）
- 需要根拠: API形式の選択肢が増え「どれを使うべきか」の判断が複雑化。特にtRPC/gRPCの台頭でRESTやGraphQLとの使い分けが問題に
- 差別化ポイント: 4形式の技術比較→チーム/プロジェクト規模別の選定マトリクス→バージョニング→エラーハンドリング→認証→レート制限→ドキュメント→OpenAPI/gRPC-Web/Relay仕様
- 想定章数: 8

### 47. テスト戦略の教科書 ── ユニット/統合/E2Eテストの設計と実装
- ジャンル: 設計・開発手法
- ニッチ度: 中（テスト本は存在するがPlaywright/Vitest等の最新ツール前提の戦略本がない）
- 需要根拠: Playwrightが2026年のE2Eテスト第一候補に。VitestがJest代替に。しかし「テストピラミッドの各層をどう設計するか」の戦略本が最新ツール前提で不在
- 差別化ポイント: テスト戦略の設計→Vitest（ユニット/統合）→Playwright（E2E）→MSW（APIモック）→Visual Regression→CI/CD統合→カバレッジ目標設定→テストピラミッド vs テストトロフィー
- 想定章数: 8

### 48. ドメイン駆動設計（DDD）実装入門 ── TypeScriptで学ぶ戦術的パターン
- ジャンル: 設計・開発手法
- ニッチ度: 中（Zennで「ようこそ、ドメイン駆動設計へ」が¥500で注目本入り。TypeScript実装に特化した本として差別化可能）
- 需要根拠: DDDへの関心は継続的に高い。しかしDDD本はJava/C#中心で、TypeScript/Node.jsプロジェクトでの実装パターンが不足
- 差別化ポイント: Value Object/Entity/Aggregate→Repository→Domain Event→Application Service→Prisma/Drizzle統合→Next.js App Router→テスト設計→Clean Architecture比較
- 想定章数: 8

---

## ツール・自動化・その他（2本）

### 49. 個人開発の技術選定 2026 ── 最速でプロダクトを出すためのスタック選び
- ジャンル: キャリア・チーム
- ニッチ度: 中（技術選定の話題はSNSで常に盛り上がるが体系的な本がない）
- 需要根拠: 個人開発・副業開発でのスタック選定は永遠の話題。2026年はフレームワーク・BaaS・AIツールの選択肢が爆発的に増え、選定の難易度が上昇
- 差別化ポイント: 要件別の技術選定マトリクス（SaaS/EC/コミュニティ/メディア等）→フレームワーク→DB→認証→決済→ホスティング→AIツール→コスト試算→実際のスタック構成例10選
- 想定章数: 8

### 50. 正規表現実践パターン集 ── コピペで使えるバリデーション・抽出・変換レシピ
- ジャンル: ツール・自動化
- ニッチ度: 中（正規表現入門本はあるが、実務で使えるパターン集形式の本がない）
- 需要根拠: 正規表現は全エンジニアが使うが「毎回ググる」人が大多数。メール/URL/電話番号/日付/日本語特有パターン等の実務レシピ需要は普遍的
- 差別化ポイント: 日本語対応（全角/半角/住所/電話番号/郵便番号）→バリデーション→ログ解析→LLM出力パース→言語別の正規表現エンジン差異→パフォーマンス→ReDoS対策
- 想定章数: 7

---

## テーマ選定の根拠サマリー

### Zennブックストアの現状（2026年7月時点）
- **ベストセラーの傾向**: Unreal Engine（¥2,600-3,600）、Raspberry Pi（¥1,200）、OAuth/OIDC（¥1,500）、AI×Unity（¥1,500）、Claude Agent SDK（¥500）
- **カテゴリ**: フロントエンド、バックエンド、モバイル、インフラ・DevOps、AI・機械学習、データベース、言語・基礎、設計・開発手法、セキュリティ、CS・低レイヤ、ツール・自動化等
- **価格帯**: 無料〜¥3,600。有料本は¥500〜¥1,500が中心

### 需要が高いジャンル（2026年トレンド）
1. **AI/LLM/エージェント**: Qiita月間トレンドで「AI」「ClaudeCode」「AIエージェント」が常連
2. **エッジコンピューティング**: Cloudflare Workers/Hono関連で技評から複数冊出版
3. **ローカルファースト**: SQLite/DuckDB/Tursoの文脈で注目度上昇
4. **新世代言語**: Gleam/Zig/Mojoの注目度が急上昇だが日本語リソース皆無
5. **開発環境**: Nix/Dev Containers/モノレポの需要が継続

### ニッチ度「高」のテーマ（既存本がほぼない = 競合空白）
1, 2, 6, 7, 8, 10, 11, 13, 14, 15, 16, 18, 19, 21, 22, 27, 29, 30, 32, 33, 35, 36, 38, 39, 40, 41, 42, 43, 45
（50本中29本がニッチ度「高」）
