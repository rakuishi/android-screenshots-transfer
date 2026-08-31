#!/usr/bin/env bash
#
# swift-format による整形とチェック。
# Xcode に同梱の swift-format を xcrun 経由で使うため、別途インストールは不要。
# ルールはリポジトリ直下の .swift-format で設定する。
#
# 使い方:
#   ./scripts/lint.sh          # チェックのみ（ファイルは書き換えない）
#   ./scripts/lint.sh --fix    # 整形して書き換えてからチェック
#
set -euo pipefail

# プロジェクトルート（このスクリプトの 1 つ上）へ移動
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

TARGET="AndroidScreenshotsTransfer"   # Swift ソースを置いているディレクトリ

if ! xcrun --find swift-format >/dev/null 2>&1; then
  echo "✗ swift-format not found. Install Xcode and its command line tools" >&2
  exit 1
fi

if [[ "${1:-}" == "--fix" ]]; then
  echo "▶ Formatting…"
  xcrun swift-format format --in-place --parallel --recursive "$TARGET"
  echo "✓ Formatted"
fi

echo "▶ Linting…"
# --strict: 整形の差分も含めてすべて指摘し、1 件でもあれば終了コード 1 を返す
if xcrun swift-format lint --strict --parallel --recursive "$TARGET"; then
  echo "✓ No issues"
else
  echo "" >&2
  echo "✗ Issues found. Run ./scripts/lint.sh --fix to fix them automatically" >&2
  exit 1
fi
