#!/usr/bin/env bash
#
# Zenn公開前の安全チェックスクリプト
# git pre-push hook または手動で実行する
#
# チェック内容:
# 1. 個人情報・非公開情報の検出（固有名詞）
# 2. 事業探索・ヒアリング関連の記述検出（スコープ外）
# 3. ローカルパス・APIキー等の技術的漏洩
#
# 使い方:
#   .github/scripts/pre-publish-check.sh [対象ディレクトリ]
#   デフォルトは books/ と articles/
#
set -euo pipefail

TARGET="${1:-books/ articles/}"
FAIL=0

echo "=== Zenn公開前 安全チェック ==="
echo ""

# --- 1. 個人情報・非公開プロジェクト名 ---
echo "[1/3] 個人情報・非公開情報チェック..."

PERSONAL_PATTERNS='(syumai|kanayanaokyou|藤井|尚興|naoki|fujii|syuumai|@gmail\.com|@icloud)'
PROJECT_PATTERNS='(codell|ロート|ラッキー|川口|齋藤|宮野|中村一彰|神山|まるごと高専|estie|Alfab|アルファブ|PHALAE|Barefort|tokoro-portfolio|portfolio-lyart)'
# Compass/Prism/Sansan等の一般英単語は技術書内で頻出するため除外
# syumai固有のプロジェクト名のみ検出
RESEARCH_TARGETS='(Torivo|Ludis|Honeybooks|NextIdea|Slend)'
INDUSTRY_SPECIFIC='(ペットグルーミング|トリミングサロン|ビデオ接客|LiveCall|NTT東日本|VIVIT|Klarna|Immerss|音楽D2C|EVEN型)'

for PAT in "$PERSONAL_PATTERNS" "$PROJECT_PATTERNS" "$RESEARCH_TARGETS" "$INDUSTRY_SPECIFIC"; do
  HITS=$(grep -rn -i -E "$PAT" $TARGET 2>/dev/null || true)
  if [ -n "$HITS" ]; then
    echo "  NG: 以下にマッチ ($PAT):"
    echo "$HITS" | sed 's/^/    /'
    FAIL=1
  fi
done

if [ "$FAIL" -eq 0 ]; then
  echo "  OK"
fi

# --- 2. スコープ外（ヒアリング・事業探索） ---
echo "[2/3] スコープ外チェック（ヒアリング・事業探索）..."

SCOPE_PATTERNS='(ヒアリング|インタビュー|コールドコンタクト|事業機会|事業探索|事業仮説|事業候補|killshot|チャネル仮説|WTP|顧客獲得|ギフト券)'

HITS=$(grep -rn -i -E "$SCOPE_PATTERNS" $TARGET 2>/dev/null || true)
if [ -n "$HITS" ]; then
  echo "  NG: スコープ外の記述:"
  echo "$HITS" | sed 's/^/    /'
  FAIL=1
else
  echo "  OK"
fi

# --- 3. 技術的漏洩 ---
echo "[3/3] 技術的漏洩チェック..."

# syumaiの実パスのみ検出。汎用パス(/home/user等)・コード例・URLは除外
TECH_PATTERNS='(Users/kanayanaokyou|irbank|eir-parts|EDINET)'

HITS=$(grep -rn -i -E "$TECH_PATTERNS" $TARGET 2>/dev/null || true)
if [ -n "$HITS" ]; then
  echo "  NG: 技術的漏洩の可能性:"
  echo "$HITS" | sed 's/^/    /'
  FAIL=1
else
  echo "  OK"
fi

echo ""
if [ "$FAIL" -eq 1 ]; then
  echo "=== FAIL: 上記を修正してから公開してください ==="
  exit 1
else
  echo "=== PASS: 公開可能です ==="
  exit 0
fi
