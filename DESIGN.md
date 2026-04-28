# LivePortrait Zoom アバター — 設計ドキュメント

## 概要

写真1枚からリアルタイムにアバターを動かし、Zoom のビデオ通話で使用するシステム。

## やりたいこと

- 写真1枚 → Webカメラの顔の動きに合わせてアバターがリアルタイムに動く
- Zoom の仮想カメラとしてアバター映像を出力
- Mac M2 でローカル実行（無料）

## アーキテクチャ

```
Webカメラ → live_portrait.py (ailia SDK / M2 MPS GPU)
                ↓
         LivePortrait (FOMM) 推論
                ↓
         pyvirtualcam → OBS Virtual Camera ドライバ → Zoom
                ↓
         cv2.imshow でプレビュー表示
```

### コンポーネント

| コンポーネント | 役割 | 備考 |
|---|---|---|
| Webカメラ | 顔の動きをキャプチャ | `--driving 0` (デフォルト) |
| ailia SDK | ONNX 推論エンジン | MPS (Metal Performance Shaders) で GPU 推論 |
| LivePortrait | 写真アニメーションモデル (FOMM) | ONNX 形式、モデル自動ダウンロード |
| pyvirtualcam | フレームを仮想カメラに送信 | OBS Virtual Camera ドライバを利用 |
| OBS Virtual Camera | macOS のカメラデバイスとして登録 | OBS アプリの起動は不要、ドライバのみ使用 |
| cv2 (OpenCV) | プレビューウィンドウ表示 | Webカメラ + アバターを並べて表示 |

## ファイル構成

```
~/ailia-models/generative_adversarial_networks/live_portrait/
├── live_portrait.py          # メインスクリプト（改造済み）
├── utils_crop.py             # クロップユーティリティ
├── mask_template.png         # マスクテンプレート
├── avatar.jpg                    # サンプル画像
├── d0.mp4                    # サンプル動画
├── o.jpg                     # ユーザー画像
├── morshas.jpg               # ユーザー画像
├── DESIGN.md                 # 本ドキュメント
├── *.onnx                    # モデルファイル（自動ダウンロード）
└── *.onnx.prototxt           # モデル定義ファイル（自動ダウンロード）
```

## セットアップ手順

### 前提条件

- macOS (Apple Silicon M1/M2/M3/M4)
- Python 3.11
- OBS Studio インストール済み（仮想カメラドライバとして使用）
- OBS の仮想カメラを1回起動→停止して有効化済み

### 1. 環境構築

```bash
# venv 作成
cd ~
python3.11 -m venv ailia-env
source ailia-env/bin/activate

# ailia SDK インストール
pip install ailia

# リポジトリ取得
git clone --depth 1 https://github.com/axinc-ai/ailia-models.git

# 依存パッケージ
cd ailia-models/generative_adversarial_networks/live_portrait
pip install opencv-python numpy pillow scikit-image scipy pyvirtualcam
```

### 2. OBS 仮想カメラドライバ

```bash
# OBS インストール（未インストールの場合）
brew install --cask obs

# OBS を起動 → 「仮想カメラ開始」→「仮想カメラ停止」→ OBS を閉じる
# （ドライバの初回有効化のため1回だけ必要）
```

### 3. macOS カメラ拡張機能の許可

- システム設定 → 一般 → ログイン項目と拡張機能 → カメラ拡張機能
- OBS を許可

### 4. 実行

```bash
cd ~/ailia-models/generative_adversarial_networks/live_portrait
source ~/ailia-env/bin/activate
python live_portrait.py -i <写真ファイル>
```

### 5. Zoom 連携

- Zoom → 設定 → ビデオ → カメラ → 「OBS Virtual Camera」を選択

## 使い方

1. コマンドを実行するとプレビューウィンドウが開く
2. 左: Webカメラ映像（黄色マーカーで目・鼻・口をトラッキング表示）
3. 右: 元画像（赤マーカーで目・鼻・口の位置を表示）
4. **スペースキー** で LivePortrait 開始
5. 左: Webカメラ映像、右: アバター出力
6. 仮想カメラに 1280x720 で出力（アスペクト比維持、黒帯付き）
7. **Q キー** で終了

## コマンドオプション

```
python live_portrait.py -i <画像> [--driving <カメラID or 動画>]
```

| オプション | デフォルト | 説明 |
|---|---|---|
| `-i`, `--input` | `avatar.jpg` | 元画像（アバターの顔） |
| `--driving` | `0` | Webカメラ番号 (0=内蔵) or 動画ファイル |
| `--composite` | off | 駆動フレーム/元画像/生成フレームを並べて表示 |
| `-e`, `--env_id` | `2` | GPU 環境 ID |

## live_portrait.py への改造内容

オリジナルからの変更点：

### 1. 顔未検出時のスキップ（クラッシュ防止）
- `predict()` 内で顔が見つからない場合 `None` を返す
- メインループで `None` の場合は `continue`

### 2. pyvirtualcam 仮想カメラ出力
- 処理済みフレームを OBS Virtual Camera に直接送信
- 1280x720 にリサイズ（アスペクト比維持、黒帯で埋め）
- OBS アプリのスクリーンキャプチャ不要

### 3. プレビュー表示
- Webカメラ映像とアバター出力を横並びで表示
- Webカメラ映像を元画像のアスペクト比に合わせてクロップ

### 4. ガイドプレビュー（開始前）
- 元画像の顔ランドマークから目・鼻・口の位置を取得
- 元画像に赤マーカー表示
- Webカメラにリアルタイム顔検出の黄色マーカー表示
- スペースキーで開始、Q で終了

### 5. リアルタイム顔トラッキングマーカー（開始後）
- Webカメラ映像に黄色マーカーで目・鼻・口をリアルタイム表示

### 6. デフォルト driving を Webカメラに変更
- `DRIVING_VIDEO_PATH = "0"` （元は `"d0.mp4"`）

## 既知の問題

### カクカク（低FPS）
- M2 MPS での推論速度の限界
- リアルタイム（15FPS以上）には届かない

### ジッター（止まっていても動く）
- 顔ランドマーク検出が毎フレーム微妙にブレる
- モデルが微小な差を増幅してアバターが揺れる
- **TODO: テンポラルスムージングで改善予定**

### 写真の要件
- 正面を向いた顔写真が最適
- 透過 PNG は使用不可（JPG に変換必要）
- 暗い写真や横顔は精度低下

## 比較検討した他の方法

| 方法 | 結果 | 備考 |
|---|---|---|
| Deep-Live-Cam | 動作するが顔入替（face swap）であり目的と異なる | |
| avatars4all (Colab + FOMM) | 動作するがネットワーク遅延でカクカク | 品質は良い |
| Xpression Camera | 滑らか・高品質だが有料（$8/月、7日間無料） | |
| Camify | Windows のみ | |
| Avatarify | 2020年のツール、Apple Silicon 非対応 | |
| Akool Live Camera | Mac 対応、無料枠あり（100クレジット） | |
| Viggle LIVE | ブラウザベース、毎日5-10分無料 | |
| LivePortrait (PyTorch MPS) | Mac MPS で ~1FPS、リアルタイム不可 | |
| **ailia SDK LivePortrait** | **採用。ローカル実行、無料、仮想カメラ直結** | |

## 技術メモ

- ailia SDK は ONNX 推論エンジン。MPS (Metal) で GPU 推論する
- pyvirtualcam は macOS では OBS Virtual Camera ドライバのみサポート
- LivePortrait の 203 点ランドマーク: 33-42=左目、87-96=右目、52-71=口、47=鼻先、72=鼻
- 106 点ランドマーク (insightface): 33-42=左目、87-96=右目、52-71=口、72=鼻
- 元画像は `src_preprocess` で前処理され、`crop_src_image` で顔クロップされる
- Webカメラフレームは `predict()` に直接渡され、内部で顔検出→ランドマーク追跡される
- 初回フレームで完全な顔検出、2フレーム目以降は前フレームのランドマークベースで追跡
