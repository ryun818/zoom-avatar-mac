---
title: Mac M2で写真1枚からZoomアバターを動かしたい — 無料ツール比較と構築記録
tags:
  - Mac
  - Zoom
  - LivePortrait
  - ailia
  - pyvirtualcam
private: false
updated_at: '2026-04-29T08:35:01+09:00'
id: 6dd10f7039a8684e5018
organization_url_name: null
slide: false
ignorePublish: false
---

## はじめに

Zoomのビデオ通話で、自分の顔の代わりに**写真1枚から生成したアバター**をリアルタイムに動かして映したい。

2020年頃に話題になった [Avatarify](https://github.com/alievk/avatarify-python) と同じことを、2026年のMac (Apple Silicon) でやりたいというのが今回の出発点です。

### やりたいこと

- 写真1枚を元にアバターを生成
- Webカメラで自分の顔の動きをトラッキング
- アバターがリアルタイムに連動して動く
- Zoomの仮想カメラとして出力

### 環境

- MacBook Pro (Apple M2 Max, 32GB RAM)
- macOS Sequoia
- Python 3.11

### ソースコード

> **GitHub: [ryun818/zoom-avatar-mac](https://github.com/ryun818/zoom-avatar-mac)**
> 本記事で紹介する ailia LivePortrait + pyvirtualcam の改造済みスクリプト、セットアップスクリプト、設計ドキュメントを公開しています。`git clone` して `bash setup.sh` を実行すれば、すぐに試せます。

> **注意:** Apple Silicon Mac (M1/M2/M3) では、体感 5-8 FPS 程度でビデオ通話として滑らかとは言えません。ジッター（止まっていてもアバターが動く）もあります。本記事は「どこまでできるか」の検証記録です。実用レベルの滑らかさを求める場合は [Xpression Camera](https://xpressioncamera.com/)（7日間無料）などの有料ツールを検討してください。

### 結論を先に

| 方法 | 動く？ | 滑らか？ | 品質 | 無料？ |
|------|:--:|:--:|:--:|:--:|
| avatars4all (Colab) | ○ | △ | ○ | ○ |
| ailia LivePortrait | ○ | △ | △ | ○ |
| Xpression Camera | ○ | ◎ | ◎ | 7日間 |

**完全無料でMac上で滑らかに動くツールは現時点では存在しません。** ただし、それぞれ「動く」ところまでは行けたので、その過程を共有します。

---

## 方法1: avatars4all (Google Colab + FOMM) — 動いた！でもカクカク

最初に試したのが [avatars4all](https://github.com/eyaler/avatars4all)。2020年の Avatarify と同じ First Order Motion Model (FOMM) をブラウザだけで使えるようにした Google Colab ノートブックです。

### セットアップ

1. [fomm_live.ipynb](https://colab.research.google.com/github/eyaler/avatars4all/blob/master/fomm_live.ipynb) を開く
2. ランタイムのタイプを **T4 GPU** に設定
3. 「すべてのセルを実行」
4. カメラアクセスを許可

### 写真のアップロード

「Optionally upload local Avatar images」セクションで `manually_upload_images` にチェックしてセルを実行するとファイル選択UIが出ます。

**注意: 透過PNG は使えません**（顔検出に失敗する）。JPG に変換して白背景にする必要があります:

```python
from PIL import Image
img = Image.open('photo.png')
if img.mode == 'RGBA':
    bg = Image.new('RGB', img.size, (255, 255, 255))
    bg.paste(img, mask=img.split()[3])
    bg.save('photo.jpg', 'JPEG', quality=95)
```

### Zoom との連携

avatars4all はブラウザ上で動くため、Zoom に映すには OBS 経由のスクリーンキャプチャが必要です。

1. OBS Studio を開く
2. ソース → macOS スクリーンキャプチャ → Colab のアバター映像を選択
3. 「仮想カメラ開始」をクリック
4. Zoom → 設定 → ビデオ → カメラ → OBS Virtual Camera

### 結果

写真が自分の顔の動きに合わせてアニメーションしました。品質もそこそこ良い。

ただし、**ネットワーク遅延がひどい**。Mac → Google Colab (GPU) → Mac の往復で常にカクカクでした。OBS スクリーンキャプチャを経由することでさらに遅延が重なります。

---

## 方法2: ailia SDK + LivePortrait — ローカルで動かす

ネットワーク遅延をなくすため、ローカルで動かすアプローチを試しました。

[ailia SDK](https://ailia.ai/) は ONNX 推論エンジンで、Apple Silicon の MPS (Metal Performance Shaders) に対応しています。[ailia-models リポジトリ](https://github.com/axinc-ai/ailia-models) に LivePortrait の実装が含まれています。

参考: [ailia SDK で LivePortrait を動かす](https://blog.ailia.ai/tips/portrait-video-conversion-liveportrait/)

### セットアップ

```bash
git clone https://github.com/ryun818/zoom-avatar-mac.git
cd zoom-avatar-mac
bash setup.sh
```

OBS 仮想カメラの準備（初回のみ）:

```bash
brew install --cask obs
```

1. OBS を起動 →「仮想カメラ開始」→「仮想カメラ停止」→ 閉じる

![OBS 仮想カメラ開始ボタン](https://raw.githubusercontent.com/ryun818/zoom-avatar-mac/main/images/obs_virtual_camera.png)
*OBS 右下の「仮想カメラ開始」ボタンをクリック（初回のみ。以降は OBS の起動不要）*
2. システム設定 → 一般 → ログイン項目と拡張機能 → カメラ拡張機能 → OBS を許可

![macOS カメラ拡張機能の設定](https://raw.githubusercontent.com/ryun818/zoom-avatar-mac/main/images/macos_camera_extension.png)
*システム設定 → 一般 → ログイン項目と拡張機能で「カメラ機能拡張」の OBS が有効になっていることを確認*

### 実行

```bash
source venv/bin/activate
python live_portrait.py -i <写真ファイル>
```

初回実行時はモデルファイル（約680MB）が自動ダウンロードされます。

### アーキテクチャ

```
Webカメラ
  ↓
live_portrait.py (ailia SDK / M2 MPS GPU)
  ├─→ pyvirtualcam → OBS Virtual Camera ドライバ → Zoom
  └─→ cv2.imshow でプレビュー表示
```

OBS のスクリーンキャプチャを経由せず、[pyvirtualcam](https://github.com/letmaik/pyvirtualcam) で Python から直接仮想カメラに映像を送っています。OBS アプリの起動は不要で、ドライバだけ使います。

### 操作方法

1. プレビューウィンドウが開く（左: Webカメラ、右: 元画像）
2. 黄色マーカーで顔のトラッキング位置をリアルタイム確認
3. **スペースキー** で開始 → 右がアバター出力に切り替わる
4. Zoom → 設定 → ビデオ → カメラ → **OBS Virtual Camera**

![Zoom設定画面](https://raw.githubusercontent.com/ryun818/zoom-avatar-mac/main/images/zoom_settings.png)
*Zoom の設定 → ビデオ → カメラで「OBS Virtual Camera」を選択*

5. **Q キー** で終了

### live_portrait.py の改造ポイント

オリジナルの ailia-models のスクリプトにいくつか改造を加えました。

#### 顔未検出時のクラッシュ防止

Webカメラの最初のフレームで顔が検出できないとクラッシュするため、スキップするように変更。

```python
# before: クラッシュする
if len(src_face) == 0:
    raise Exception(f"No face detected in the frame")

# after: スキップして次のフレームへ
if len(src_face) == 0:
    return None
```

#### pyvirtualcam で仮想カメラに直接出力

処理済みフレームを 1280x720（アスペクト比維持、黒帯で埋め）で OBS Virtual Camera に送信。

```python
import pyvirtualcam

vcam = pyvirtualcam.Camera(width=1280, height=720, fps=20,
                            fmt=pyvirtualcam.PixelFormat.BGR)

# メインループ内
scale = min(1280 / w_img, 720 / h_img)
new_w, new_h = int(w_img * scale), int(h_img * scale)
scaled = cv2.resize(driving_img, (new_w, new_h))
canvas = np.zeros((720, 1280, 3), dtype=np.uint8)
canvas[y_off:y_off+new_h, x_off:x_off+new_w] = scaled
vcam.send(canvas)
```

#### ガイドプレビュー

元画像の顔ランドマークから目・鼻・口の位置を取得し、赤マーカーで表示。Webカメラ側にはリアルタイム検出の黄色マーカーを表示。スペースキーで開始する前に顔の位置を確認できます。

### 結果

M2 Max の MPS GPU が認識され、ローカルで動きました。

```
INFO arg_utils.py (169) : MPSDNN-Apple M2 Max
```

![ガイドプレビュー](https://raw.githubusercontent.com/ryun818/zoom-avatar-mac/main/images/guide_preview_mosaic.png)
*開始前のガイドプレビュー。左: Webカメラ（黄色マーカーで顔トラッキング）、右: 元画像（赤マーカーで顔位置表示）*

ネットワーク遅延はなくなりましたが:

- **FPS は低い**（体感5-8FPS程度）
- **ジッター**がある — 止まっていてもアバターが微妙に動き続ける
- 顔の角度が元画像と大きく異なると表情が崩れる

テンポラルスムージング（指数移動平均）を入れてジッター改善を試みましたが、効果は限定的でした。

---

## 試したけど使えなかったもの

| ツール | 理由 |
|---|---|
| Avatarify | 開発停止。Apple Silicon 非対応。CamTwist が ARM64 で動かない |
| Camify | Mac 版が存在しない（Windows のみ） |
| Deep-Live-Cam | 顔の入れ替え（Face Swap）であり、写真を動かすのとは目的が異なる |
| LivePortrait (PyTorch MPS) | Mac MPS で約1FPS。リアルタイム不可 |

## 有料だが品質が良いもの

| ツール | 料金 | 特徴 |
|---|---|---|
| [Xpression Camera](https://xpressioncamera.com/) | $8/月（7日間無料） | ローカル実行、遅延ゼロ、Mac 対応 |
| [Akool Live Camera](https://akool.com/live-camera) | 100クレジット無料 | Mac M/Intel 対応、リアルタイムリップシンク |
| [Viggle LIVE](https://viggle.ai/viggle-live) | 毎日5-10分無料 | ブラウザベース、1-2秒遅延 |

---

## まとめ

2020年の Avatarify は NVIDIA GPU + CamTwist という組み合わせで成立していましたが、2026年の Mac (Apple Silicon) ではそのまま使えません。

代替として:

1. **avatars4all (Google Colab)** — 無料で動くが、ネットワーク遅延でカクカク
2. **ailia SDK + LivePortrait** — ローカルで動くが、M2 の推論速度では滑らかさに限界あり
3. **有料ツール (Xpression Camera 等)** — 品質・滑らかさは最高

「写真1枚 → リアルタイムアバター → Zoom」を Mac で完全無料・滑らかに実現するのは、2026年4月時点ではまだ難しいのが現実です。Apple Silicon の推論性能がもう少し上がるか、モデルの軽量化が進めば状況は変わるかもしれません。

### 今後試したいこと

- LivePortrait のテンポラルスムージングによるジッター改善
- CoreML 形式への変換による推論高速化
- より軽量なモデル（Thin-Plate Spline Motion Model 等）の検証

---

## 参考

- [ソースコード (GitHub)](https://github.com/ryun818/zoom-avatar-mac)
- [Avatarify (元祖)](https://github.com/alievk/avatarify-python)
- [avatars4all](https://github.com/eyaler/avatars4all)
- [ailia SDK](https://ailia.ai/)
- [ailia-models (LivePortrait)](https://github.com/axinc-ai/ailia-models)
- [ailia SDK で LivePortrait を使う](https://blog.ailia.ai/tips/portrait-video-conversion-liveportrait/)
- [pyvirtualcam](https://github.com/letmaik/pyvirtualcam)
