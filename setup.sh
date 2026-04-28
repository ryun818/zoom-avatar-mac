#!/bin/bash
set -e

echo "=== Zoom Avatar Mac セットアップ ==="

# Python バージョン確認
PYTHON=""
if command -v python3.11 &>/dev/null; then
    PYTHON=python3.11
elif command -v python3 &>/dev/null; then
    PYTHON=python3
else
    echo "Python 3.11 以上をインストールしてください"
    exit 1
fi
echo "Python: $($PYTHON --version)"

# venv 作成
if [ ! -d "venv" ]; then
    echo "venv を作成中..."
    $PYTHON -m venv venv
fi
source venv/bin/activate

# 依存パッケージ
echo "依存パッケージをインストール中..."
pip install -r requirements.txt

# OBS 確認
if [ ! -d "/Applications/OBS.app" ]; then
    echo ""
    echo "⚠ OBS Studio がインストールされていません"
    echo "仮想カメラ機能に必要です。以下でインストール:"
    echo "  brew install --cask obs"
    echo ""
    echo "インストール後:"
    echo "  1. OBS を起動"
    echo "  2. 「仮想カメラ開始」→「仮想カメラ停止」→ 閉じる"
    echo "  3. システム設定 → 一般 → ログイン項目と拡張機能 → カメラ拡張機能 → OBS を許可"
fi

echo ""
echo "=== セットアップ完了 ==="
echo ""
echo "使い方:"
echo "  source venv/bin/activate"
echo "  python live_portrait.py -i <写真ファイル>"
echo ""
echo "Zoom 連携:"
echo "  Zoom → 設定 → ビデオ → カメラ → OBS Virtual Camera"
