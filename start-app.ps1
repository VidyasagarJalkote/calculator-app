# Run this script tomorrow morning to automatically redeploy and launch the app for your demo!
Write-Host "Triggering automated deployment via GitHub Actions..." -ForegroundColor Cyan

git commit --allow-empty -m "Deploy calculator for demo"
git push

Write-Host ""
Write-Host "GitHub Actions pipeline started! Building container and launching on AWS (takes ~3 minutes)..." -ForegroundColor Yellow

$runUrl = "https://github.com/VidyasagarJalkote/calculator-app/actions"
Write-Host "You can view live deployment progress at: $runUrl" -ForegroundColor Cyan

# Poll for service and load balancer URL
Write-Host "Waiting for live AWS URL..." -NoNewline
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 10
    Write-Host "." -NoNewline
    $rules = aws elbv2 describe-rules --listener-arn $(aws elbv2 describe-listeners --load-balancer-arn $(aws elbv2 describe-load-balancers --region ap-south-1 --profile devops-admin --query "LoadBalancers[?contains(LoadBalancerName, 'ecs-express')].LoadBalancerArn" --output text 2>$null) --region ap-south-1 --profile devops-admin --query "Listeners[0].ListenerArn" --output text 2>$null) --region ap-south-1 --profile devops-admin 2>$null | ConvertFrom-Json
    if ($rules -and $rules.Rules) {
        $hostHeader = $rules.Rules[0].Conditions[0].Values[0]
        if ($hostHeader -like "*on.aws*") {
            $liveUrl = "https://$hostHeader"
            Write-Host "`n`nSUCCESS! Your application is live at:" -ForegroundColor Green
            Write-Host "$liveUrl" -ForegroundColor Green
            Start-Process $liveUrl
            break
        }
    }
}
