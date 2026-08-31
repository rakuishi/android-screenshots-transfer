#!/usr/bin/env bash
#
# Release ビルドして .app を取り出すスクリプト。
#
# 使い方:
#   ./scripts/build-app.sh                # デスクトップに取り出す
#   ./scripts/build-app.sh /Applications  # 保存先を指定
#
set -euo pipefail

# プロジェクトルート（このスクリプトの 1 つ上）へ移動
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

PROJECT="AndroidScreenshotsTransfer.xcodeproj"
SCHEME="AndroidScreenshotsTransfer"
CONFIG="Release"
DERIVED="build"                 # .gitignore で除外済み
DEST="${1:-$HOME/Desktop}"      # 第 1 引数で保存先を指定（省略時はデスクトップ）

echo "▶ Building ($CONFIG)…"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" build >/dev/null

# 成果物の実パス・名前をビルド設定から取得（PRODUCT_NAME の変更に自動追従）
SETTINGS="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" -showBuildSettings 2>/dev/null)"
BUILT_DIR="$(echo "$SETTINGS" | awk -F' = ' '/ TARGET_BUILD_DIR = /{print $2; exit}')"
APP_NAME="$(echo "$SETTINGS" | awk -F' = ' '/ FULL_PRODUCT_NAME = /{print $2; exit}')"

# 空のまま進むと後段の rm -rf が "$DEST/" を消しにいくため、ここで必ず止める
if [[ -z "$BUILT_DIR" || -z "$APP_NAME" ]]; then
  echo "✗ Could not resolve the product path from the build settings" >&2
  exit 1
fi

SRC="$BUILT_DIR/$APP_NAME"
if [[ ! -d "$SRC" ]]; then
  echo "✗ Product not found: $SRC" >&2
  exit 1
fi

mkdir -p "$DEST"
rm -rf "${DEST:?}/${APP_NAME:?}"
cp -R "$SRC" "$DEST/$APP_NAME"

echo "✓ Done: $DEST/$APP_NAME"
open -R "$DEST/$APP_NAME"
