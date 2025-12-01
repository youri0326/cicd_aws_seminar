#!/bin/bash
# ------------------------------
# PHP セットアップ
# ------------------------------
echo "=== PHP セットアップ開始 ==="
export REGION=ap-northeast-1
# 氏名（例: TaroYamada ※半角英字）
export USER_NAME="<氏名>" 
# 日付（例: 1019）
export DATE="<日付>" 

# CloudFormationのUserNameDateパラメータ（ECR名に使用）
# ハイフンを自動で結合します
export USER_NAME_DATE="${USER_NAME}-${DATE}" 

#アカウントID （例：963220189927）
export ACCOUNT_ID="<ACCOUNT_ID>"

export GITHUB_USER="<GITHUB_USER>"


# ディレクトリ作成
mkdir -p /mnt/c/ci_cd_aws_seminar_php
cd /mnt/c/ci_cd_aws_seminar_php

# GitHub 初期化
echo "# ci_cd_aws_seminar_php" >> README.md
git init
git add README.md
git commit -m "first commit"
git branch -M main
git remote add origin git@github.com:${GITHUB_USER}/ci_cd_aws_seminar_php.git
git push -u origin main

# ------------------------------
# 改行コードのLFに固定
# ------------------------------
sudo apt update
sudo apt install dos2unix

dos2unix /mnt/c/cicd_aws_seminar/php-cicd/CodeDeploy/appspec.yml

# ------------------------------
# 既存ファイルをコピー
# ------------------------------
cp -r /mnt/c/cicd_aws_seminar/php-cicd/* /mnt/c/ci_cd_aws_seminar_php

# ------------------------------
# ファイルをGitにコミット・プッシュ
# ------------------------------
git add .
git commit -m "Add initial project files for CI/CD setup"
git push origin main


# 氏名（例: TaroYamada ※半角英字）
export USER_NAME="<氏名>" 
# 日付（例: 20251019）
export DATE="<日付>" 

# CloudFormationのUserNameDateパラメータ（ECR名に使用）
# ハイフンを自動で結合します
export USER_NAME_DATE="${USER_NAME}-${DATE}" 

# CodeBuild プロジェクト作成
aws codebuild create-project \
  --name php-build-${USER_NAME_DATE} \
  --source type=CODEPIPELINE,buildspec=CodeBuild/buildspec-php.yml \
  --artifacts type=CODEPIPELINE \
  --environment type=LINUX_CONTAINER,computeType=BUILD_GENERAL1_SMALL,image=aws/codebuild/standard:5.0 \
  --service-role arn:aws:iam::${ACCOUNT_ID}:role/CodeBuildServiceRole-${USER_NAME_DATE} \
  --region ${REGION}

# CodeDeploy アプリ作成
aws deploy create-application \
  --application-name cicd-aws-codedeploy-php-${USER_NAME_DATE} \
  --compute-platform ECS \
  --region ${REGION}

aws deploy create-deployment-group \
  --cli-input-json file://CodeDeploy/tg-pair.json \
  --region ${REGION}

# CodePipeline 作成（Blue/Green）
aws codepipeline create-pipeline \
  --cli-input-json file://CodePipeline/pipeline-php-bluegreen.json \
  --region ${REGION}

echo "=== すべてのセットアップが完了しました ==="

# ------------------------------
# 動作確認①パイプラインの成否の確認
# ------------------------------

# パイプライン名を指定
PIPELINE_NAME="php-pipeline-bluegreen-${USER_NAME_DATE}"

# 最新の実行状況を確認
aws codepipeline list-pipeline-executions \
  --pipeline-name ${PIPELINE_NAME} \
  --max-items 1 \
  --query 'pipelineExecutionSummaries[0].[status, startTime, lastUpdateTime]' \
  --output table

# ------------------------------
# 動作確認①デプロイ情報の成否の確認
# ------------------------------
#
# 最新デプロイ情報を取得
DEPLOY_ID=$(aws deploy list-deployments \
    --application-name cicd-aws-codedeploy-php-${USER_NAME_DATE} \
    --deployment-group-name cicd-aws-codedeploy-php-group \
    --query 'deployments[0]' \
    --output text)
echo "上で取得したデプロイID:"${DEPLOY_ID}

aws deploy get-deployment \
    --deployment-id ${DEPLOY_ID} \
    --query '{Status:deploymentInfo.status,TrafficShiftCompleted:deploymentInfo.completeTime}' \
    --output table

# ------------------------------
# 動作確認②ECSのrunningの確認
# ------------------------------
# サービスに紐付くタスク一覧
TASK_ARN=$(aws ecs list-tasks \
    --cluster ecs-cluster-${USER_NAME_DATE} \
    --service-name php-service-${USER_NAME_DATE} \
    --region ap-northeast-1 \
    --query 'taskArns' \
    --output text)
# タスク詳細を取得
echo "上で取得したタスク定義ARN:"${TASK_ARN}

aws ecs describe-tasks \
    --cluster ecs-cluster-${USER_NAME_DATE} \
    --tasks $TASK_ARN \
    --region ap-northeast-1 \
    --query 'tasks[0].containers[0].[name, lastStatus, taskDefinitionArn]' \
    --output table

# ------------------------------
# 動作確認③ターゲットグループのヘルスチェック
# ------------------------------
# ターゲットグループのヘルスチェック状況
# リージョンを指定
REGION="ap-northeast-1"

# BlueターゲットグループARNを取得
BLUE_TG_ARN=$(aws elbv2 describe-target-groups \
  --names php-blue-tg-${USER_NAME_DATE} \
  --region $REGION \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "BlueターゲットグループARN:"${BLUE_TG_ARN}


# GreenターゲットグループARNを取得
GRENN_TG_ARN=$(aws elbv2 describe-target-groups \
  --names php-green-tg-${USER_NAME_DATE} \
  --region $REGION \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "GreenターゲットグループARN:"${GREEN_TG_ARN}


aws elbv2 describe-target-health \
    --target-group-arn ${BLUE_TG_ARN} \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
    --output table

aws elbv2 describe-target-health \
    --target-group-arn ${GRENN_TG_ARN} \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
    --output table

# ------------------------------
# 動作確認④ブラウザで動作確認
# ------------------------------
php_alb_dns=$(aws elbv2 describe-load-balancers \
    --names alb-${USER_NAME_DATE} \
    --query 'LoadBalancers[0].DNSName' \
    --output text)
URL="http://"${php_alb_dns}
echo "URLにアクセス:"${URL}


# ------------------------------
# 動作確認⑤継続的デプロイの確認
# -----------------------------
#①index.phpの修正 12行目に「echo "継続的デプロイの成功！<br>";」を追記-

#GITHUBへのプッシュ
cp -r /mnt/c/cicd_aws_seminar/php-cicd/* /mnt/c/ci_cd_aws_seminar_php
git add .
git commit -m "Add initial project files for CI/CD setup"
git push origin main

# パイプライン名を指定
PIPELINE_NAME="php-pipeline-bluegreen-${USER_NAME_DATE}"

# 最新の実行状況を確認
aws codepipeline list-pipeline-executions \
  --pipeline-name $PIPELINE_NAME \
  --max-items 1 \
  --query 'pipelineExecutionSummaries[0].[status, startTime, lastUpdateTime]' \
  --output table


# ------------------------------
# 最終章：削除
# -----------------------------

# aws codebuild delete-project \
#   --name php-build-${USER_NAME_DATE} \
#   --region ${REGION}

# aws deploy delete-application \
#   --application-name cicd-aws-codedeploy-php-${USER_NAME_DATE} \
#   --region ${REGION}

# #!/bin/bash
# set -e

# ==============================
# 基本変数設定
# ==============================
export USER_NAME="<氏名>"
export DATE="<日付>"
export USER_NAME_DATE="${USER_NAME}-${DATE}"
export REGION="ap-northeast-1"
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=== ${USER_NAME_DATE} のリソース削除を開始します ==="

# ==============================
# 1️⃣ CodePipeline 削除
# ==============================
echo "[1/9] CodePipeline 削除..."

aws codepipeline delete-pipeline \
  --name phpmyadmin-pipeline-rolling-${USER_NAME_DATE} \
  --region ${REGION} || echo "phpMyAdmin pipeline not found"

aws codepipeline delete-pipeline \
  --name php-pipeline-bluegreen-${USER_NAME_DATE} \
  --region ${REGION} || echo "CodePipeline not found"

# ==============================
# 2️⃣ CodeBuild 削除
# ==============================
echo "[2/9] CodeBuild プロジェクト削除..."
aws codebuild delete-project \
  --name php-build-${USER_NAME_DATE} \
  --region ${REGION} || echo "php build project not found"

aws codebuild delete-project \
  --name phpmyadmin-build-${USER_NAME_DATE} \
  --region ${REGION} || echo "phpMyAdmin build project not found"

# ==============================
# 3️⃣ CodeDeploy 削除
# ==============================
echo "[3/9] CodeDeploy アプリとグループ削除..."
# グループ名を取得して削除
DG_NAME="cicd-aws-codedeploy-php-group"
APP_NAME="cicd-aws-codedeploy-php-${USER_NAME_DATE}"

aws deploy delete-deployment-group \
  --application-name ${APP_NAME} \
  --deployment-group-name ${DG_NAME} \
  --region ${REGION} || echo "Deployment group not found"

aws deploy delete-application \
  --application-name ${APP_NAME} \
  --region ${REGION} || echo "CodeDeploy application not found"

# # ==============================
# # 4️⃣ ECS サービス & クラスター削除 ←不要
# # ==============================
echo "[4/9] ECS サービスとクラスター削除..."
# SERVICES=("php-service-${USER_NAME_DATE}" "phpmyadmin-service-${USER_NAME_DATE}")
# CLUSTER="ecs-cluster-${USER_NAME_DATE}"

  # aws ecs update-service \
  #   --cluster ${CLUSTER} \
  #   --service ${SERVICE} \
  #   --desired-count 0 \
  #   --region ${REGION} || true

aws ecs delete-service \
  --cluster ecs-cluster-${USER_NAME_DATE} \
  --service phpmyadmin-service-${USER_NAME_DATE} \
  --force \
  --region ${REGION}

aws ecs delete-service \
  --cluster ecs-cluster-${USER_NAME_DATE} \
  --service php-service-${USER_NAME_DATE} \
  --force \
  --region ${REGION}

aws ecs delete-cluster \
  --cluster ecs-cluster-${USER_NAME_DATE} \
  --region ${REGION} 

# ==============================
# 5️⃣ ALB / Target Group 削除
# ==============================
echo "[5/9] ALB と TargetGroup 削除..."

# TG_NAMES_PHP="php-blue-tg-${USER_NAME_DATE}"
# TG_NAMES_PMA="php-green-tg-${USER_NAME_DATE}"

TG_ARN_BLUE=$(aws elbv2 describe-target-groups \
  --names "php-blue-tg-${USER_NAME_DATE}" \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text 2>/dev/null || true)

TG_ARN_GREEN=$(aws elbv2 describe-target-groups \
  --names "php-green-tg-${USER_NAME_DATE}" \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text 2>/dev/null || true)

aws elbv2 delete-target-group --target-group-arn "${TG_ARN_BLUE}" --region ${REGION}
aws elbv2 delete-target-group --target-group-arn "${TG_ARN_GREEN}" --region ${REGION}

# TG_NAMES=("php-blue-tg-${USER_NAME_DATE}" "php-green-tg-${USER_NAME_DATE}")
# for TG in "${TG_NAMES[@]}"; do
#   TG_ARN=$(aws elbv2 describe-target-groups \
#     --names ${TG} \
#     --query "TargetGroups[0].TargetGroupArn" \
#     --output text 2>/dev/null || true)
#   if [ -n "$TG_ARN" ]; then
#     aws elbv2 delete-target-group --target-group-arn "$TG_ARN" --region ${REGION}
#     echo "Target Group ${TG} deleted."
#   fi
# done

ALB_NAME="alb-${USER_NAME_DATE}"
aws elbv2 delete-load-balancer \
  --name ${ALB_NAME} \
  --region ${REGION} || echo "ALB not found"

# ==============================
# 6️⃣ ECR リポジトリ削除
# ==============================
echo "[6/9] ECR リポジトリ削除..."
ECR_NAMES=(
  "ecr-php-${USER_NAME_DATE}"
  "ecr-phpmyadmin-${USER_NAME_DATE}"
  "ecr-php-apache-${USER_NAME_DATE}"
)

aws ecr delete-repository \
  --repository-name ecr-phpmyadmin-${USER_NAME_DATE} \
  --force \
  --region ${REGION} || echo "ECR ecr-phpmyadmin-${USER_NAME_DATE} not found"

aws ecr delete-repository \
  --repository-name ecr-php-${USER_NAME_DATE} \
  --force \
  --region ${REGION} || echo "ECR ecr-php-${USER_NAME_DATE} not found"

aws ecr delete-repository \
  --repository-name ecr-php-apache-${USER_NAME_DATE} \
  --force \
  --region ${REGION} || echo "ECR ecr-php-apache-${USER_NAME_DATE} not found"


# ECR_NAMES=(
#   "ecr-php-${USER_NAME_DATE}"
#   "ecr-phpmyadmin-${USER_NAME_DATE}"
#   "ecr-php-apache-${USER_NAME_DATE}"
# )

# for REPO in "${ECR_NAMES[@]}"; do
#   aws ecr delete-repository \
#     --repository-name ${REPO} \
#     --force \
#     --region ${REGION} || echo "ECR ${REPO} not found"
# done

# ==============================
# 7️⃣ CodeStar Connection 削除
# ==============================
echo "[7/9] CodeStar Connections 削除..."
#※神田itスクールアカウントは一旦保持
CONN_ARN=$(aws codestar-connections list-connections \
  --query "Connections[?ConnectionName=='cs-conn-${USER_NAME_DATE}'].ConnectionArn" \
  --output text --region ${REGION})

aws codestar-connections delete-connection \
  --connection-arn "$CONN_ARN" \
  --region ${REGION}

# ==============================
# 8️⃣ バケットを空にする削除
# ==============================
##最初からバケットを削除できるようにcloudformationで制御する

aws s3 rm s3://cicd-${USER_NAME_DATE}/ --recursive
# aws s3 rm s3://codepipeline-artifact-${USER_NAME_DATE}/ --recursive

aws s3api delete-bucket --bucket cicd-${USER_NAME_DATE}
aws s3api delete-bucket --bucket codepipeline-artifact-${USER_NAME_DATE}

S3_BUCKET_NAME=codepipeline-artifact-${USER_NAME_DATE}
aws s3api delete-objects \
--bucket ${S3_BUCKET_NAME} \
--delete "$(aws s3api list-object-versions \
--bucket ${S3_BUCKET_NAME} \
--query '{Objects: DeleteMarkers[*].{Key:Key,VersionId:VersionId}}' \
--output json)"



# ==============================
# 8️⃣ CloudFormation スタック削除
# ==============================
echo "[8/9] CloudFormation スタック削除..."
aws cloudformation delete-stack \
  --stack-name cicd-${USER_NAME_DATE} \
  --region ${REGION}

# aws cloudformation wait stack-delete-complete \
#   --stack-name cicd-${USER_NAME_DATE} \
#   --region ${REGION} || echo "Stack not found or already deleted"

# ==============================
# 9️⃣ ローカルディレクトリ削除（オプション）
# ==============================
echo "[9/9] ローカル作業ディレクトリ削除（任意）..."
# rm -rf /mnt/c/ci_cd_aws_seminar_php
# rm -rf /mnt/c/ci_cd_aws_seminar_phpmyadmin

echo "=== すべてのリソース削除が完了しました ✅ ==="


