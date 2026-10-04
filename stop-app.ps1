# Run this script to stop all resources and freeze AWS costs immediately.
Write-Host "Stopping ECS service and deleting Load Balancer to freeze costs..." -ForegroundColor Yellow

$cluster = "default"
$service = "calculator-service"
$region = "ap-south-1"
$profile = "devops-admin"

# 1. Scale service to 0 and delete
aws ecs update-service --cluster $cluster --service $service --desired-count 0 --region $region --profile $profile 2>$null
Start-Sleep -Seconds 5
aws ecs delete-service --cluster $cluster --service $service --force --region $region --profile $profile 2>$null

# 2. Find and delete the Application Load Balancer
$albs = aws elbv2 describe-load-balancers --region $region --profile $profile | ConvertFrom-Json
foreach ($alb in $albs.LoadBalancers) {
    if ($alb.LoadBalancerName -like "*ecs-express*") {
        Write-Host "Deleting Load Balancer: $($alb.LoadBalancerName)..." -ForegroundColor Yellow
        aws elbv2 delete-load-balancer --load-balancer-arn $alb.LoadBalancerArn --region $region --profile $profile
    }
}

Write-Host "All active resources stopped! AWS costs are now frozen at $0/hour." -ForegroundColor Green
Write-Host "To redeploy tomorrow morning, simply run: .\start-app.ps1" -ForegroundColor Cyan
