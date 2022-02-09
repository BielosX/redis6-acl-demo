#!/bin/bash

REPO_NAME="redis-lambda-images"
QUERY=".repositories[] | select(.repositoryName == '$REPO_NAME')"
RESULT=$(aws --region eu-west-1 ecr describe-repositories | jq '"$QUERY"')
ACCOUNT_ID=$(aws sts get-caller-identity | jq '.Account' | tr -d '"')
echo "Account ID: ${ACCOUNT_ID}"
if [ "$RESULT" = "" ]; then
  aws --region eu-west-1 ecr create-repository --repository-name "$REPO_NAME"
else
  echo "Repository already exist"
fi
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.eu-west-1.amazonaws.com"
docker build . -t "$ACCOUNT_ID.dkr.ecr.eu-west-1.amazonaws.com/$REPO_NAME"
docker push "$ACCOUNT_ID.dkr.ecr.eu-west-1.amazonaws.com/$REPO_NAME"