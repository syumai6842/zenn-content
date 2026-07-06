---
title: "公開サーバーのアーキテクチャ傾向とセキュリティ"
---

## 公式リファレンス実装のアーキテクチャ

`modelcontextprotocol/servers`は、MCPのコア機能とSDKの使い方を示すためにAnthropicが公開しているリファレンス実装群である。TypeScript製サーバーは`npx`で、Python製サーバーは`uvx`または`pip`で直接実行できるように作られており、単体で意味を持つアプリケーションではなく、MCPクライアント側の設定に組み込んで使うことを前提とした設計になっている[^servers-repo]。

1章で触れた通り、発表当初の20個のリファレンスサーバーのうち13個(GitHub、Slack、Postgres、Google Drive、Brave Search、Sentry、SQLite、Puppeteer、EverArt、AWS KB、Redis、Google Maps、GitLab)は`servers-archived`リポジトリに移動され、各サービス提供元によるベンダーメンテナンスに移行した[^servers-archived]。2026年7月時点でAnthropicが直接保守しているのはEverything・Fetch・Filesystem・Git・Memory・Sequential Thinking・Timeの7個である。

公式ドキュメントに記載されているアーキテクチャ上の共通パターンは次の通りである[^architecture-docs]。

- transport層はJSON-RPC 2.0メッセージ形式を全transport方式で共通利用する抽象化になっており、stdioがローカルプロセス通信のデフォルトかつ最も一般的な方式である
- 接続lifecycleは初期化時にcapabilityをネゴシエートするハンドシェイクパターンに従い、以降のアクティブセッションでクライアントがサーバーのcapabilityを呼び出す
- 各リファレンスサーバーは「1サーバー=1ドメイン」という単一責任の設計を取っている(Filesystemはファイル操作のみ、FetchはHTTP取得のみ、Gitはgit操作のみを扱う)

## サーバー数とツール数の実態

公開されているMCPサーバーの数はディレクトリサイトごとに大きく異なる。1章で示した通り、MCP.directoryが「3,000以上」を公称する一方、PulseMCPは約20,260件、mcp.soは23,293件、Glama.aiは23,000件以上を掲載していると報告されている[^mcp-directory][^pulsemcp][^mcpso]。

Bloomberryが独自に1,400件のMCPサーバーを分析した調査は、公式ディレクトリの掲載数とは別に、実装の内容そのものに踏み込んだ数少ない定量分析である[^bloomberry]。この調査によれば、平均ツール数は13.4個/サーバーだが中央値は5個であり、ツール数の分布は次のようになっている。

- ツール数1〜4個: 約46%
- ツール数5〜9個: 19%
- ツール数10〜19個: 15%

分析対象4,126ツールの操作種別は、読み取り操作が52%、書き込み操作が25%、分類不能が23%であった。Bloomberryはこの傾向について、「ツール数の少なさは、多くの企業がまだ『とりあえずMCPサーバーを持っておくべき』という段階にあり、『プラットフォームを公開する上で不可欠な手段』という段階には至っていないことを示唆する」と考察している[^bloomberry]。

自作するMCPサーバーの設計においても、この分布は参考になる。ツール数を無理に増やすのではなく、1つのサーバーが扱うドメインを絞り込み、5個前後の明確な責務を持つツールに整理する設計が、公開されている実装の主流と一致する。

## Tool Poisoning Attack

セキュリティ企業Invariant Labsは2025年4月6日、「MCP Security Notification: Tool Poisoning Attacks」でこの攻撃手法を命名・公開した[^tool-poisoning]。ツールのdescriptionフィールドはLLMのコンテキストにそのまま読み込まれるため、ユーザーには見えない敵対的な指示をdescriptionに埋め込むことで、モデルに意図しない挙動を取らせることができる。同社はCursorエディタ上で、電卓ツールのdescriptionに隠した指示によりSSH秘密鍵を読み取らせ外部送信させる実演と、WhatsApp MCPサーバーを標的にした実証(「fact of the day」という無害に見えるツールが後からツール定義を書き換え、メッセージの送信先を攻撃者の電話番号にリルーティングする)を公開している。

この攻撃はOWASP MCP Top 10で「MCP03:2025 – Tool Poisoning」として正式に分類されている[^owasp]。関連するCVEとしてMCPoison(CVE-2025-54136)、CurXecute(CVE-2025-54135)が報告されている。

2025年8月に公開されたベンチマーク論文「MCPTox」(arXiv:2508.14925)は、45個の実際のMCPサーバーと20の主要AIモデルに対して毒入りツール説明文を試行し、成功率が最大72.8%に達し、モデルがほとんど拒否しなかったと報告している[^mcptox]。Microsoftも2026年6月、The Hacker Newsを通じて「Poisoned MCP Tool Descriptions Can Make AI Agents Leak Data」として同種の脅威に注意を呼びかけている[^ms-warning]。

## Rug Pull Attack

Rug Pull攻撃は、一度ユーザーの信頼を得たMCPサーバーやツールが、承認後に静かに悪意ある指示を含むよう改変される攻撃を指す。ツール名やスキーマは変わらないまま挙動だけが変わるため検知が難しい。この攻撃の中核にあるのは「サーバー側ロジックの可変性」という構造的な問題であり、ツールの識別子が同じままでも、裏側のコードや挙動をMCPクライアント・ユーザーへの通知や再検証なしに変更できてしまう点にある[^rug-pull]。

学術研究としては、OAuth拡張ツール定義とポリシーベースアクセス制御によってTool SquattingとRug Pull攻撃を緩和する手法を提案する「ETDI」(arXiv:2506.01333)がある[^etdi]。CVE-2025-54136がRug Pull攻撃の具体例として言及されることもある。

## 報告されている脆弱性事例

本書執筆時点で確認できた、MCP関連の具体的なCVEを次に示す。

| CVE | 対象 | 概要 |
|---|---|---|
| CVE-2025-49596 | MCP Inspector 0.14.1未満 | InspectorクライアントとProxy間の認証欠如によるリモートコード実行。CVSS 4.0で9.4(CRITICAL)。Oligo Securityが報告、2025-06-13公開 |
| CVE-2025-6514 | mcp-remote 0.0.5〜0.1.15 | `authorization_endpoint`の不正値経由のOSコマンドインジェクション。CVSS 9.6。JFrog Security Researchが発見、2025-07-09開示、0.1.16で修正 |
| CVE-2025-6515 | oatpp-mcp | メモリポインタ由来の予測可能なセッションID生成によるセッションハイジャック(「Prompt Hijacking」)。JFrogが2025-10-21開示 |
| CVE-2025-68143/68144/68145 | Anthropic公式`mcp-server-git` | パス検証バイパス、無制限`git_init`、`git_diff`/`git_checkout`の引数インジェクション。プロンプトインジェクション経由で悪用可能。Cyataが2025年6月報告、Anthropicが2025年12月に修正 |

CVE-2025-49596は、MCP Inspectorという「開発者がローカルで動かすツール」自体が、認証なしにリモートコード実行を許してしまうという事例であり、7章で紹介したInspectorを使う際にも該当バージョン以降を使うべき理由になる。CVE-2025-68143/68144/68145は、Anthropic自身が保守する公式リファレンス実装であっても脆弱性が報告される、という事実を示している。

## 体系的な脅威分類の研究

2025年には、MCP特有の脅威を体系的に分類する学術研究が複数発表されている。

- 「Model Context Protocol (MCP): Landscape, Security Threats, and Future Research Directions」(arXiv:2503.23278)は、MCPサーバーのライフサイクルを作成・デプロイ・運用・保守の4フェーズ・16の主要活動に分解し、攻撃者を悪意ある開発者・外部攻撃者・悪意あるユーザー・セキュリティ欠陥の4類型に分類した上で、16の脅威シナリオを整理している[^landscape]
- 「When MCP Servers Attack: Taxonomy, Feasibility, and Mitigation」(arXiv:2509.24272)は、直接的ツールインジェクション・間接的ツールインジェクション・悪意あるユーザー攻撃・LLM固有の攻撃という4ファミリーにわたる31種類の攻撃をカタログ化している[^when-mcp-attack]
- 「MCPSecBench」(arXiv:2508.13220)は、4つの攻撃対象領域にまたがる17種類の攻撃タイプを分類し、プロンプトデータセット・MCPサーバー・クライアント・攻撃スクリプト・GUIテストハーネス・防御機構を統合したベンチマークとして提供している[^mcpsecbench]

## 自作サーバーへの実践的な示唆

これらの事例と研究から、MCPサーバーを自作する際に検討すべき点を整理する。

第一に、ツールのdescriptionフィールドは信頼できない入力として扱う必要がある。外部から取得した文字列(ファイル内容、APIレスポンスなど)をそのままdescriptionに埋め込むと、Tool Poisoning Attackの経路になり得る。

第二に、6章で述べた通り、Streamable HTTPサーバーではOriginヘッダーの検証とlocalhostへのバインドを仕様通りに実装し、認可が必要な公開サーバーではOAuth 2.1のResource Server要件を満たす。

第三に、破壊的な操作(ファイル削除、外部への送信を伴う操作など)を行うツールについては、3章で説明した「human in the loopでツール呼び出しを拒否できる」という設計原則を、クライアント側の実装だけに委ねず、サーバー側でも確認ステップ(elicitationの活用など)を設けることが望ましい。

第四に、公式リファレンス実装ですら脆弱性が報告され、ベンダーメンテナンスへの移行が進んでいるという1章・本章の事実を踏まえると、自作したサーバーを継続的に運用する場合は、依存しているSDKのバージョンアップとセキュリティアドバイザリの追跡を運用プロセスに組み込む必要がある。

[^servers-repo]: GitHub, modelcontextprotocol/servers, https://github.com/modelcontextprotocol/servers
[^servers-archived]: GitHub, modelcontextprotocol/servers-archived, https://github.com/modelcontextprotocol/servers-archived
[^architecture-docs]: MCP公式ドキュメント, "Architecture", https://modelcontextprotocol.io/docs/learn/architecture
[^mcp-directory]: MCP.directory, https://mcp.directory/servers
[^pulsemcp]: PulseMCP, https://www.pulsemcp.com/servers
[^mcpso]: mcp.so, https://mcp.so/
[^bloomberry]: Bloomberry, "We analyzed 1400 MCP servers, here's what we learned", https://bloomberry.com/blog/we-analyzed-1400-mcp-servers-heres-what-we-learned/
[^tool-poisoning]: Invariant Labs, "MCP Security Notification: Tool Poisoning Attacks", 2025-04-06, https://invariantlabs.ai/blog/mcp-security-notification-tool-poisoning-attacks
[^owasp]: OWASP, "MCP03:2025 – Tool Poisoning", https://owasp.org/www-project-mcp-top-10/2025/MCP03-2025%E2%80%93Tool-Poisoning
[^mcptox]: arXiv:2508.14925, "MCPTox", https://arxiv.org/pdf/2508.14925
[^ms-warning]: The Hacker News, "Poisoned MCP Tool Descriptions Can Make AI Agents Leak Data", 2026年6月, https://thehackernews.com/2026/06/microsoft-warns-poisoned-mcp-tool.html
[^rug-pull]: Practical DevSecOps, "Rug Pull Attack in MCP", https://www.practical-devsecops.com/glossary/rug-pull-attack-in-mcp/
[^etdi]: arXiv:2506.01333, "ETDI", https://arxiv.org/html/2506.01333v1
[^landscape]: arXiv:2503.23278, "Model Context Protocol (MCP): Landscape, Security Threats, and Future Research Directions", https://arxiv.org/abs/2503.23278
[^when-mcp-attack]: arXiv:2509.24272, "When MCP Servers Attack: Taxonomy, Feasibility, and Mitigation", https://arxiv.org/html/2509.24272v1
[^mcpsecbench]: arXiv:2508.13220, "MCPSecBench", https://arxiv.org/abs/2508.13220
