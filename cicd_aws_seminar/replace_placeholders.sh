#!/bin/bash

# ==============================================================================
# 1. 前提条件のチェック
# ==============================================================================
if [ -z "$USER_NAME" ] || [ -z "$DATE" ] || [ -z "$GITHUB_USER" ]; then
    echo "❌ エラー: 環境変数が不足しています。以下を実行してください。"
    echo "export USER_NAME=\"...\" DATE=\"...\" GITHUB_USER=\"...\""
    exit 1
fi

export USER_NAME_DATE="${USER_NAME}-${DATE}"
export STACK_NAME="cicd-${USER_NAME_DATE}"

echo "🔍 CloudFormation スタック [ $STACK_NAME ] から情報を一括取得します..."

# ==============================================================================
# 2. CloudFormation Outputs から一括取得
# ==============================================================================
# describe-stacks の結果を変数に格納
STDOUT=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs" --output json)

if [ $? -ne 0 ]; then
    echo "❌ エラー: スタックが見つかりません。名前を確認してください: $STACK_NAME"
    exit 1
fi

# jq を使って OutputKey から各値を取り出す
# ※テンプレート内の OutputKey 名（ConnectionArn, RdsEndpoint 等）に合わせて適宜調整してください
export CONNECTION_ARN=$(echo $STDOUT | jq -r '.[] | select(.OutputKey=="ConnectionArn") | .OutputValue')
export RDS_ENDPOINT=$(echo $STDOUT | jq -r '.[] | select(.OutputKey=="RdsEndpoint") | .OutputValue')
export ALB_HTTP_LISTENER_ARN=$(echo $STDOUT | jq -r '.[] | select(.OutputKey=="AlbHttpListenerArn") | .OutputValue')
export ALB_TEST_LISTENER_ARN=$(echo $STDOUT | jq -r '.[] | select(.OutputKey=="AlbTestListenerArn") | .OutputValue')

# アカウントIDだけは共通情報なので別途取得
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# ==============================================================================
# 3. 置換処理
# ==============================================================================
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