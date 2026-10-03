#!/usr/bin/env bash
# Run this ONCE in AWS CloudShell. Edit the two variables first.
set -euo pipefail

GITHUB_USER="VidyasagarJalkote"
GITHUB_REPO="calculator-app"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS account: $ACCOUNT_ID"

# 1) Let GitHub Actions log in to AWS without passwords/keys (OIDC)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 || echo "OIDC provider already exists"

cat > trust-github.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "repo:${GITHUB_USER}/${GITHUB_REPO}:ref:refs/heads/main"
      }
    }
  }]
}
EOF

aws iam create-role --role-name github-actions-deploy \
  --assume-role-policy-document file://trust-github.json
aws iam attach-role-policy --role-name github-actions-deploy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
aws iam attach-role-policy --role-name github-actions-deploy \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess

cat > passrole.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "iam:PassRole",
    "Resource": [
      "arn:aws:iam::${ACCOUNT_ID}:role/ecsTaskExecutionRole",
      "arn:aws:iam::${ACCOUNT_ID}:role/ecsInfrastructureRoleForExpressServices"
    ]
  }]
}
EOF
aws iam put-role-policy --role-name github-actions-deploy \
  --policy-name allow-pass-ecs-roles --policy-document file://passrole.json

# 2) Role ECS uses to pull the image and write logs
cat > trust-tasks.json <<EOF
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}
EOF
aws iam create-role --role-name ecsTaskExecutionRole \
  --assume-role-policy-document file://trust-tasks.json
aws iam attach-role-policy --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# 3) Role ECS Express Mode uses to create the load balancer, scaling, etc.
cat > trust-ecs.json <<EOF
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs.amazonaws.com"},"Action":"sts:AssumeRole"}]}
EOF
aws iam create-role --role-name ecsInfrastructureRoleForExpressServices \
  --assume-role-policy-document file://trust-ecs.json
INFRA_POLICY=$(aws iam list-policies --scope AWS \
  --query "Policies[?PolicyName=='AmazonECSInfrastructureRoleforExpressGatewayServices'].Arn" --output text)
aws iam attach-role-policy --role-name ecsInfrastructureRoleForExpressServices --policy-arn "$INFRA_POLICY"

# 4) Service-linked roles (harmless if they already exist)
aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com 2>/dev/null || true
aws iam create-service-linked-role --aws-service-name elasticloadbalancing.amazonaws.com 2>/dev/null || true

echo ""
echo "DONE. Your AWS account ID (save it for GitHub): $ACCOUNT_ID"
