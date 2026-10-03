$ErrorActionPreference = "Continue"

$accountId = (aws sts get-caller-identity --profile devops-admin --query Account --output text).Trim()
Write-Host "AWS Account: $accountId" -ForegroundColor Cyan

# 1. Trust policy for GitHub Actions OIDC
$trustGithub = @"
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::$accountId:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:VidyasagarJalkote/calculator-app:*"
      }
    }
  }]
}
"@
$trustGithub | Set-Content -Path "$PSScriptRoot\trust-github.json" -Encoding utf8

Write-Host "Creating github-actions-deploy IAM role..." -ForegroundColor Yellow
aws iam create-role --role-name github-actions-deploy --assume-role-policy-document "file://$PSScriptRoot/trust-github.json" --profile devops-admin 2>$null

aws iam attach-role-policy --role-name github-actions-deploy --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser --profile devops-admin
aws iam attach-role-policy --role-name github-actions-deploy --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess --profile devops-admin

$passRole = @"
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "iam:PassRole",
    "Resource": [
      "arn:aws:iam::$accountId:role/ecsTaskExecutionRole",
      "arn:aws:iam::$accountId:role/ecsInfrastructureRoleForExpressServices"
    ]
  }]
}
"@
$passRole | Set-Content -Path "$PSScriptRoot\passrole.json" -Encoding utf8
aws iam put-role-policy --role-name github-actions-deploy --policy-name allow-pass-ecs-roles --policy-document "file://$PSScriptRoot/passrole.json" --profile devops-admin

# 2. Role ECS uses to pull image & write logs
$trustTasks = @"
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ecs-tasks.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
"@
$trustTasks | Set-Content -Path "$PSScriptRoot\trust-tasks.json" -Encoding utf8

Write-Host "Creating ecsTaskExecutionRole..." -ForegroundColor Yellow
aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document "file://$PSScriptRoot/trust-tasks.json" --profile devops-admin 2>$null
aws iam attach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy --profile devops-admin

# 3. Role ECS Express Mode uses
$trustEcs = @"
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ecs.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
"@
$trustEcs | Set-Content -Path "$PSScriptRoot\trust-ecs.json" -Encoding utf8

Write-Host "Creating ecsInfrastructureRoleForExpressServices..." -ForegroundColor Yellow
aws iam create-role --role-name ecsInfrastructureRoleForExpressServices --assume-role-policy-document "file://$PSScriptRoot/trust-ecs.json" --profile devops-admin 2>$null
$infraPolicyArn = (aws iam list-policies --scope AWS --query "Policies[?PolicyName=='AmazonECSInfrastructureRoleforExpressGatewayServices'].Arn" --output text --profile devops-admin).Trim()
if ($infraPolicyArn) {
    aws iam attach-role-policy --role-name ecsInfrastructureRoleForExpressServices --policy-arn "$infraPolicyArn" --profile devops-admin
}

# 4. Service-linked roles
aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com --profile devops-admin 2>$null
aws iam create-service-linked-role --aws-service-name elasticloadbalancing.amazonaws.com --profile devops-admin 2>$null

# 5. ECR Repository
Write-Host "Creating ECR repository 'calculator-app' in ap-south-1..." -ForegroundColor Yellow
aws ecr create-repository --repository-name calculator-app --region ap-south-1 --profile devops-admin 2>$null

Write-Host "SUCCESS! AWS Infrastructure configuration complete." -ForegroundColor Green
Write-Host "Account ID for GitHub Actions: $accountId" -ForegroundColor Green
