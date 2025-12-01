#!/bin/bash
# ====================================
# AWS CI/CD 環境構築スクリプト
# PHP / phpMyAdmin Blue-Green構成
# ====================================

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
# ------------------------------
# phpMyAdmin セットアップ
# ------------------------------
echo "=== phpMyAdmin セットアップ開始 ==="

# ディレクトリ作成
mkdir -p /mnt/c/ci_cd_aws_seminar_phpmyadmin
cd /mnt/c/ci_cd_aws_seminar_phpmyadmin

# GitHub 初期化
echo "# ci_cd_aws_seminar_phpmyadmin" >> README.md
git init
git add README.md
git commit -m "first commit"
git branch -M main
git remote add origin git@github.com:${GITHUB_USER}/ci_cd_aws_seminar_phpmyadmin.git
git push -u origin main

# ------------------------------
# 既存ファイルをコピー
# ------------------------------
cp -r /mnt/c/cicd_aws_seminar/phpmyadmin-cicd/* /mnt/c/ci_cd_aws_seminar_phpmyadmin

# ------------------------------
# ファイルをGitにコミット・プッシュ
# ------------------------------
git add .
git commit -m "Add initial project files for CI/CD setup"
git push origin main

# CodeBuild プロジェクト作成
aws codebuild create-project \
  --name phpmyadmin-build-${USER_NAME_DATE} \
  --source type=CODEPIPELINE,buildspec=CodeBuild/buildspec-phpmyadmin.yml \
  --artifacts type=CODEPIPELINE \
  --environment type=LINUX_CONTAINER,computeType=BUILD_GENERAL1_SMALL,image=aws/codebuild/standard:5.0 \
  --service-role arn:aws:iam::${ACCOUNT_ID}:role/CodeBuildServiceRole-${USER_NAME_DATE} \
  --region ${REGION}

# CodePipeline 作成
aws codepipeline create-pipeline \
  --cli-input-json file://CodePipeline/pipeline-phpmyadmin-rolling.json \
  --region ${REGION}

# ------------------------------
# 動作確認①パイプラインの成否の確認
# ------------------------------
# 必要な情報を変数に格納
CLUSTER_NAME="ecs-cluster-${USER_NAME_DATE}"
SERVICE_NAME="phpmyadmin-service-${USER_NAME_DATE}"
REGION="ap-northeast-1" # 例: 東京リージョン
PIPELINE_NAME="phpmyadmin-pipeline-rolling-${USER_NAME_DATE}"

# 最新の実行状況を確認
aws codepipeline list-pipeline-executions \
  --pipeline-name ${PIPELINE_NAME} \
  --max-items 1 \
  --query 'pipelineExecutionSummaries[0].[status, startTime, lastUpdateTime]' \
  --output table

# ------------------------------
# 動作確認②ECSのrunningの確認
# ------------------------------

# # サービスの詳細情報を取得し、ロードバランサーの情報のみをフィルタリング
# aws ecs describe-services \
#     --cluster ${CLUSTER_NAME} \
#     --services ${SERVICE_NAME} \
#     --region ${REGION} \
#     --query 'services[0].loadBalancers[0].loadBalancerName' \
#     --output text
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
# 動作確認④ブラウザで動作確認
# ------------------------------
PAM_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $(aws ecs describe-tasks \
    --cluster "${CLUSTER_NAME}" \
    --tasks $(aws ecs list-tasks \
      --cluster "${CLUSTER_NAME}" \
      --service-name "${SERVICE_NAME}" \
      --query "taskArns[0]" \
      --output text) \
    --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
    --output text) \
  --query "NetworkInterfaces[0].Association.PublicIp" \
  --output text)

URL="http://"${PAM_IP}
echo "URLにアクセス:"${URL}

