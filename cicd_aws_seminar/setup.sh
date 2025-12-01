#!/bin/bash
# ==========================================================
# 第3章～第4章までの設定
# ==========================================================
# ==========================================================
# 第3章
# ==========================================================
# ==========================================================
# ⓪ 必須変数の設定 (入力ミス防止のため分割)
# ==========================================================
# 氏名（例: Yamada）
export USER_NAME="（ここに苗字を入力してください）" 
# 日付（例: 1019）
export DATE="（ここに本日の月日を入力してください）" 

# CloudFormationのUserNameDateパラメータ（ECR名に使用）
# ハイフンを自動で結合します
export USER_NAME_DATE="${USER_NAME}-${DATE}" 

# AWSアカウントID (Registry ID) とリージョンの設定
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export REGION="ap-northeast-1" # ★ デプロイするリージョンに合わせて修正してください
export GITHUB_USER="(GITHUBのユーザー名)"

# ------------------------------
# ①作業directoryへ移動
# ------------------------------
cd /mnt/c/ci_cd_aws_seminar

# ------------------------------
# ②ECRの作成
# ------------------------------
aws ecr create-repository --repository-name ecr-php-${USER_NAME_DATE} --region ${REGION}
aws ecr create-repository --repository-name ecr-phpmyadmin-${USER_NAME_DATE} --region ${REGION}
aws ecr create-repository --repository-name ecr-php-apache-${USER_NAME_DATE} --region ${REGION}

# ECRにログイン
aws ecr get-login-password --region ${REGION} | \
docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# ==========================================================
# ③ PHPイメージのプッシュ (リポジトリ名: ecr-php-...)
# ==========================================================
export PHP_REPO_NAME="ecr-php-${USER_NAME_DATE}" # ECR名に 'ecr-' プレフィックス
export PHP_IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${PHP_REPO_NAME}"

echo "PHPアプリケーションをビルド中..."
docker build -t ${PHP_REPO_NAME}:latest ./php-cicd/app

docker tag ${PHP_REPO_NAME}:latest ${PHP_IMAGE_URI}:latest

echo "PHPイメージをプッシュ中: ${PHP_IMAGE_URI}:latest"
docker push ${PHP_IMAGE_URI}:latest

# ==========================================================
# ④ phpMyAdminイメージのプッシュ (リポジトリ名: ecr-phpmyadmin-...)
# ==========================================================
export PMA_REPO_NAME="ecr-phpmyadmin-${USER_NAME_DATE}" 
export PMA_IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${PMA_REPO_NAME}"
export PMA_TAG="5.2.1" 

echo "phpMyAdminイメージをプルし、タグ付け..."
docker pull phpmyadmin/phpmyadmin:${PMA_TAG}

# ECRのリポジトリ名とタグに合わせる
docker tag phpmyadmin/phpmyadmin:${PMA_TAG} ${PMA_IMAGE_URI}:${PMA_TAG}

echo "phpMyAdminイメージをプッシュ中: ${PMA_IMAGE_URI}:${PMA_TAG}"
docker push ${PMA_IMAGE_URI}:${PMA_TAG}

echo "完了しました。両方のイメージがECRにプッシュされました。"

# ==========================================================
# ④ PHP-Apacheイメージのプッシュ (リポジトリ名: ecr-php-apache...)
# ==========================================================
export PHP_APACHE_REPO_NAME="ecr-php-apache-${USER_NAME_DATE}" 
export PHP_APACHE_IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${PHP_APACHE_REPO_NAME}"
export PHP_APACHE_TAG="8.1-apache" 

echo "php-apacheイメージをプルし、タグ付け..."
docker pull php:${PHP_APACHE_TAG}

# ECRのリポジトリ名とタグに合わせる
docker tag php:${PHP_APACHE_TAG} ${PHP_APACHE_IMAGE_URI}:${PHP_APACHE_TAG}

echo "phpapacheイメージをプッシュ中: ${PHP_APACHE_IMAGE_URI}:${PHP_APACHE_TAG}"
docker push ${PHP_APACHE_IMAGE_URI}:${PHP_APACHE_TAG}


# ==========================================================
# 第4章
# ==========================================================

# ------------------------------
# ⑤ cloudformationの作成
# ------------------------------
# cloudformationの作成
aws cloudformation deploy \
  --template-file cicd-seminar-infra.yaml \
  --stack-name cicd-${USER_NAME_DATE} \
  --parameter-overrides UserNameDate=${USER_NAME_DATE} \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --region ${REGION}

# 出力値(環境変数に登録する値)の確認
aws cloudformation describe-stacks --stack-name cicd-${USER_NAME_DATE} \
  --query "Stacks[0].Outputs"

# ==========================================================
# 第5章
# ==========================================================
# ------------------------------
# ⑥ AWSとGITHUBを接続する（CodeStar Connections 作成）
# ------------------------------
aws codestar-connections create-connection \
  --provider-type GitHub \
  --connection-name cs-conn-${USER_NAME_DATE}

# ------------------------------
# ⑧ GITHUBへSSSの設定 ※ブラウザでの設定も必要なので教科書も併用して設定ください。
# ------------------------------
mkdir ~/.ssh
cd ~/.ssh
#パスフレーズ入力を求められますが無視してエンター3回
ssh-keygen -t rsa
#後ほど利用するので出力内容をコピーする
cat ~/.ssh/id_rsa.pub

# ------------------------------
# ⑦ 文字列の置換
# ------------------------------
#以下、ファイルを実行する前に、これまで確認した値を、「replace_placeholders.sh」に設定しなさい
chmod +x replace_placeholders.sh
./replace_placeholders.sh