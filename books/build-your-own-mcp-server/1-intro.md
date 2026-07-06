---
title: "MCPとは何か、なぜ自作するのか"
---

## MCPの発表経緯

Model Context Protocol(MCP)は、Anthropicが2024年11月25日に自社ブログ記事「Introducing the Model Context Protocol」で発表したオープンソースの規格である[^anthropic-announce]。同記事はMCPを「データが存在するシステムとAIアシスタントを接続するための新しい標準」と説明し、モデルが情報サイロに隔離されている問題を、データソースごとのカスタム実装ではなく単一のプロトコルで置き換えることを目的として掲げている。

発表と同時に、プロトコル仕様とPython/TypeScript向けSDK、Claude Desktopアプリでのローカル対応、Google Drive・Slack・GitHub・Git・Postgres・Puppeteer向けの事前構築済みMCPサーバーが公開された。BlockやApolloが発表から数週間以内に自社製品への統合を行ったことも同記事で紹介されている。

MCP自体はJSON-RPC 2.0をメッセージフォーマットとして採用した通信規格であり、クライアント(AIアシスタントを組み込んだアプリケーション)とサーバー(外部システムへの接続を提供するプロセス)の間で、Tools・Resources・Prompts・Sampling・Rootsという5つのプリミティブを介してやり取りする。これらの詳細は2章・3章で扱う。

## 主要プラットフォームでの採用状況

MCPはAnthropic単独の規格にとどまらず、発表から1年余りの間に複数の主要AI企業が採用を表明している。日付が確認できるものを時系列で示す。

| 日付 | 主体 | 内容 | 出典 |
|---|---|---|---|
| 2024-11-25 | Anthropic | MCP発表 | anthropic.com/news/model-context-protocol |
| 2025-03-19 | Microsoft | Copilot StudioでMCPサポートをパブリックプレビュー公開 | microsoft.com公式ブログ |
| 2025-03-26 | OpenAI | Sam AltmanがX上でChatGPTデスクトップアプリ等でのMCP採用を表明。TechCrunchが同日報道 | techcrunch.com/2025/03/26 |
| 2025-04-09 | Google DeepMind | Demis HassabisがGeminiモデル・SDKへのMCPサポート追加をX上で発表 | techcrunch.com/2025/04/09 |
| 2025-05-19 | Microsoft | Build 2025で「Copilot Tuning」と併せてMCPによるエージェント開発拡張を発表 | redmondmag.com |
| 2025-05-29 | Microsoft | Copilot StudioでのMCP統合が一般提供(GA)開始 | microsoft.com公式ブログ |
| 2025年5月 | Google | Google I/OでGemini APIへのネイティブMCP SDKサポートを正式発表 | cloud.google.com公式ブログ |
| 2025年12月 | Anthropic | MCPをLinux Foundation傘下の新設団体Agentic AI Foundation(AAIF)に寄贈。理事会にAnthropic、OpenAI、Google、Microsoft、AWS、Cloudflare、Bloombergが参加 | anthropic.com/news |

2025年12月のガバナンス移管は、MCPが単一ベンダーの規格から業界横断の標準へと位置づけを変えた出来事として本書では扱う。ガバナンスの詳細な議論は本書のスコープ外だが、複数企業が理事会に参加している事実は、MCPサーバーを自作する際の互換性の見通しを考える上で参考になる。

## エコシステムの規模

公開されているMCPサーバーの数は、集計を行うディレクトリサイトによって大きく異なる。本書執筆時点(2026年7月)で確認できた数字を出典とともに列挙する。

- MCP.directory: 「3,000以上のMCPサーバー」を公称[^mcp-directory]
- PulseMCP: 日次更新で約20,260件を掲載[^pulsemcp]
- mcp.so: 23,293件を収集(クロール時点により20,000〜23,000台で変動)[^mcpso]
- Glama.ai: 23,000件以上を掲載していると複数の二次情報で報じられている
- Smithery.ai: 自己申告ベースで6,000件以上を登録・ホスティング。2024年12月創業、開始当初は約10件のサーバーから成長し、1日あたり数万件のツール呼び出しが発生しているという[^smithery]
- 公式MCP Registry(Anthropicが運営するメタデータレジストリ): 2025年9月8日にプレビュー公開され、2025年11月25日の1周年時点で約2,000件のエントリに到達(プレビュー公開時から407%の成長)[^registry-anniversary]
- Nordic APIsの集計では、あるディレクトリが2025年9月時点で16,670件を掲載しており、これは2年足らずで16,000%の増加に相当すると報告している[^nordicapis]
- Bloomberryが独自に追跡した母集団では、2025年8月末時点で425件だったサーバー数が2026年2月には1,412件に達し、6か月で232%増加している[^bloomberry]

数字がディレクトリごとに1,000件台から2万件台まで大きく異なる理由は、各サイトの収集方法(手動レビューの有無、重複除去の基準、非稼働サーバーの扱い)が異なるためである。本書では特定の数字を絶対的な指標として扱うのではなく、「複数の独立した集計が軒並み急成長を示している」という傾向を事実として採用する。

また、MCP公式ブログは1周年の時点でSDKの月間ダウンロード数が9,700万件に達し、アクティブなサーバー数が10,000以上になったと報告している[^registry-anniversary]。

Bloomberryが1,400件のMCPサーバーを分析した結果では、平均ツール数は13.4個/サーバーだが中央値は5個であり、約46%のサーバーがツール数1〜4個にとどまる。分析対象4,126ツールのうち52%が読み取り操作、25%が書き込み操作だったという[^bloomberry]。この数字は、MCPサーバーの多くが小規模な単一責任のツール集合として設計されていることを示している。

## 公式リファレンス実装の変遷

Anthropicは発表当初、GitHub・Slack・Postgres・Google Drive・Brave Search・Sentry・SQLite・Puppeteer・EverArt・AWS KB・Redis・Google Maps・GitLabを含む20個のリファレンスサーバーを`modelcontextprotocol/servers`リポジトリで公開していた。しかし2025年にこのうち13個が`servers-archived`リポジトリへ移動され、各サービス提供元によるベンダーメンテナンスへの移行が進められた[^servers-archived]。2026年7月時点でAnthropicが直接保守している公式リファレンスサーバーはEverything・Fetch・Filesystem・Git・Memory・Sequential Thinking・Timeの7個にとどまる。

この転換は「多数の外部サービス統合を単一の組織が保守し続けるのは持続的でない」という判断に基づくものであり、MCPサーバーの保守責任がプロトコルの提供元ではなく各サービスの提供元に移りつつあることを示している。自作したMCPサーバーを長期的に運用する場合も、この分散型の保守モデルを前提に設計判断を行うことになる。

## 日本語圏での情報状況

Qiita・Zenn・noteで「MCPサーバー」に関する記事を横断的に確認すると、「今すぐ導入すべきMCPサーバー7選」(Qiita)[^qiita-7sen]や「エンジニアが入れるべきMCPサーバー厳選まとめ」(Zenn)[^zenn-matome]のような、既存サーバーの紹介・比較記事が上位に多く見られる。Qiitaには「MCPサーバー」専用のタグページも存在する[^qiita-tag]。

一方、「自作」「実装」を主題とする記事は存在するものの、大半が単一のAPI連携や特定のつまずきポイントを扱う単発記事にとどまる[^zenn-getting-started][^zenn-python-jisaku][^zenn-tsumazuki]。本書執筆時点で確認できた体系的な書籍としては、Zenn本「ゼロから作るMCPサーバーとMCPクライアント」が挙げられるが、これはMCP専用ライブラリを使わずゼロから実装するアプローチを取っている[^zenn-zero-kara]。本書はこれとは逆に、公式SDK(TypeScript SDK、Python SDK/FastMCP)を用いた実装を出発点とし、プロトコル仕様の読み方からテスト・公開・セキュリティまでを一冊で通しで扱う点で異なるアプローチを取る。

## 本書の構成と前提

本書は次の順序で進む。

1. プロトコルの基礎(JSON-RPC 2.0、lifecycle、transport)
2. コア概念(Tools・Resources・Prompts・Sampling・Roots)
3. TypeScript SDKでの最小サーバー実装
4. Python SDK(FastMCP)での最小サーバー実装
5. Streamable HTTPサーバーへの拡張とOAuth 2.1認証
6. MCP Inspectorによるテストと自動テストの書き方
7. npm公開・claude mcp add登録・MCP Registry申請
8. 公開サーバーのアーキテクチャ傾向分析とセキュリティ脅威

前提として、TypeScriptまたはPythonの基本文法を理解していることを想定する。MCPという概念自体の一般的な説明(「AIエージェントとツールを繋ぐ標準規格である」といった紹介)は本書では最小限にとどめ、実装可能な水準の技術的詳細に紙面を割く。

本書で扱うコードはNode.js 18以降(TypeScript SDK)、Python 3.10以降(Python SDK)を前提とする。掲載しているバージョン番号・コマンド・URLは2026年7月時点のものであり、MCP自体は2026年7月28日に予定されている次期仕様(2026-07-28)で大きな変更を予定している。この変更点については各章で該当箇所に注記する形で触れる。

[^anthropic-announce]: Anthropic, "Introducing the Model Context Protocol", 2024-11-25, https://www.anthropic.com/news/model-context-protocol
[^mcp-directory]: MCP.directory, https://mcp.directory/servers (2026年7月アクセス)
[^pulsemcp]: PulseMCP, "MCP Server Directory", https://www.pulsemcp.com/servers (2026年7月アクセス)
[^mcpso]: mcp.so, https://mcp.so/ (2026年7月アクセス)
[^smithery]: WorkOS Blog, "Smithery.ai", https://workos.com/blog/smithery-ai
[^registry-anniversary]: MCP Blog, "One Year of MCP", 2025-11-25, https://blog.modelcontextprotocol.io/posts/2025-11-25-first-mcp-anniversary/
[^nordicapis]: Nordic APIs, "10 Interesting MCP Statistics", https://nordicapis.com/10-interesting-mcp-statistics/
[^bloomberry]: Bloomberry, "We analyzed 1400 MCP servers, here's what we learned", https://bloomberry.com/blog/we-analyzed-1400-mcp-servers-heres-what-we-learned/
[^servers-archived]: GitHub, modelcontextprotocol/servers-archived, https://github.com/modelcontextprotocol/servers-archived
[^qiita-7sen]: Qiita, 「今すぐ導入すべきMCPサーバー7選【2025年最新版】」, https://qiita.com/blackflamef97/items/b411b22ddc5b4a5aa53e
[^zenn-matome]: Zenn, 「【2026年最新】エンジニアが入れるべきMCPサーバー厳選まとめ」, https://zenn.dev/imohuke/articles/mcp-servers-2026
[^qiita-tag]: Qiita, MCPサーバータグ, https://qiita.com/tags/mcp%E3%82%B5%E3%83%BC%E3%83%90%E3%83%BC
[^zenn-getting-started]: Zenn, 「MCPサーバー自作入門」, https://zenn.dev/zaki_yama/articles/mcp-server-getting-started
[^zenn-python-jisaku]: Zenn, 「自分好みのMCPサーバーをPythonで気軽に作ってみる」, https://zenn.dev/watamoo/articles/38a929be266e4a
[^zenn-tsumazuki]: Zenn, 「MCPサーバーを自作する中でつまずいたポイント」, https://zenn.dev/moneyforward/articles/6deaa22428a109
[^zenn-zero-kara]: Zenn本, 「ゼロから作るMCPサーバーとMCPクライアント」, https://zenn.dev/sogawa_yk/books/fa26457ee975f0
