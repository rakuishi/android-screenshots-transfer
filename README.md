# Android Screenshots Transfer

Android 端末のスクリーンショットと画面録画をサムネイル一覧で確認し、Finder へドラッグ＆ドロップで取り出す macOS アプリ。内部では `adb` を呼んでいるだけで、端末に専用アプリは不要。

## 動作条件

- macOS 15.7 以降 / Xcode 26 以降
- Android SDK Platform Tools（`adb`）と、端末側の USB デバッグ有効化

`adb` のパスは [ADB.swift](AndroidScreenshotsTransfer/ADB.swift) で `~/Library/Android/sdk/platform-tools/adb` に決め打ちしている。別の場所に入れている場合は書き換える。

## scripts

### `build-app.sh`

Release ビルドして `.app` を取り出し、Finder で開く。

```bash
./scripts/build-app.sh                # デスクトップに保存
./scripts/build-app.sh /Applications  # 保存先を指定
```

### `lint.sh`

Xcode 同梱の swift-format で整形とチェックを行う。

```bash
./scripts/lint.sh          # チェックのみ
./scripts/lint.sh --fix    # 整形してからチェック
```
