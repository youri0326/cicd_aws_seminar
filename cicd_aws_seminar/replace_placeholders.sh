#!/bin/bash

# === 設定値（自分の環境に合わせて編集）===
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export CONNECTION_ARN="CodeStar Connections作成時に生成のARN"
export RDS_ENDPOINT="RDSのエンドポイント名"
export USER_NAME="氏名(苗字)"
export DATE="本日の日付(例：1008)"
export ALB_HTTP_LISTENER_ARN="生成時のHTTP用のLisnerのARN：(例) arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:listener/app/my-alb/abc123/def456"
export ALB_TEST_LISTENER_ARN="生成時のTEST用のLisnerのARN：(例) arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:listener/app/my-alb/abc123/ghi789"
export GITHUB_USER="githubのアカウント名"

# === 対象ディレクトリ（現在の実行場所）===
export TARGET_DIR=$(pwd)

echo "🔍 対象ディレクトリ: $TARGET_DIR"
echo "🛠 置換を開始します..."

# === findで再帰的に全ファイルを対象（このスクリプト自身を除外）===
find "$TARGET_DIR" -type f ! -name "replace_placeholders.sh" | while read -r file; do
  # バイナリファイルを除外（テキストファイルのみ対象）
  if file "$file" | grep -q "text"; then
    echo "📝 処理中: $file"

    sed -i \
      -e "s|<ACCOUNT_ID>|$ACCOUNT_ID|g" \
      -e "s|<CONNECTION_ARN>|$CONNECTION_ARN|g" \
      -e "s|<rdsのエンドポイント>|$RDS_ENDPOINT|g" \
      -e "s|<氏名>|$USER_NAME|g" \
      -e "s|<日付>|$DATE|g" \
      -e "s|<ALB_HTTP_LISTENER_ARN>|$ALB_HTTP_LISTENER_ARN|g" \
      -e "s|<ALB_TEST_LISTENER_ARN>|$ALB_TEST_LISTENER_ARN|g" \
      -e "s|<GITHUB_USER>|$GITHUB_USER|g" \
      "$file"
  fi
done

echo "✅ すべてのファイルで置換が完了しました（replace_placeholders.sh は除外）。"
