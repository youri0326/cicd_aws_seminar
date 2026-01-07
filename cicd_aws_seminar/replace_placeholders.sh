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
# export STACK_NAME="cicd-${USER_NAME_DATE}"

# echo "🔍 CloudFormation スタック [ $STACK_NAME ] から情報を一括取得します..."

# ==============================================================================
# 2. LisnerのARNの取得
# ==============================================================================
ALB_NAME="alb-${USER_NAME_DATE}"

ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text)

export ALB_HTTP_LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn "$ALB_ARN" \
  --query "Listeners[?Port==\`80\`].ListenerArn" \
  --output text)

export ALB_TEST_LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn "$ALB_ARN" \
  --query "Listeners[?Port==\`9000\`].ListenerArn" \
  --output text)

# ==============================================================================
# 3. RDSのエンドポイントの取得
# ==============================================================================

export RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier "db-${USER_NAME_DATE}" \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)  

# ==============================================================================
# 4. CodeStar Connections から CONNECTION_ARN 取得
# ==============================================================================
echo "🔗 CodeStar Connection ARN を取得"

export CONNECTION_ARN=$(aws codestar-connections list-connections \
  --query "Connections[?ConnectionName=='cs-conn-${USER_NAME_DATE}'].ConnectionArn" \
  --output text \
  --region "${REGION}")

if [ -z "$CONNECTION_ARN" ] || [ "$CONNECTION_ARN" = "None" ]; then
  echo "❌ CodeStar Connection が見つかりません: cs-conn-${USER_NAME_DATE}"
  exit 1
fi

# ==============================================================================
# 5. 共通情報
# ==============================================================================
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)


# ==============================================================================
# 6. 置換処理
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
