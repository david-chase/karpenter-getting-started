cls
Write-Host ""
Write-Host ::: Destroy EKS Cluster With Karpenter v1 ::: -ForegroundColor Cyan
Write-Host ""

Write-Host Deleting CF stacks -ForegroundColor Cyan
aws cloudformation delete-stack --stack-name "Karpenter-$env:CLUSTER_NAME"
aws cloudformation delete-stack --stack-name ( "eksctl-" + $env:CLUSTER_NAME + "-addon-vpc-cni" )
aws cloudformation delete-stack --stack-name ( "eksctl-" + $env:CLUSTER_NAME + "-cluster" )
# aws ec2 describe-launch-templates --filters "Name=tag:karpenter.k8s.aws/cluster,Values=$env:CLUSTER_NAME" |
#     jq -r ".LaunchTemplates[].LaunchTemplateName" |
#     xargs -I{} aws ec2 delete-launch-template --launch-template-name {}

Write-Host `nDeleting cluster -ForegroundColor Cyan
eksctl delete cluster --name "$env:CLUSTER_NAME"

Write-Host `nPausing for 5 minutes to allow the cluster to deprovision -ForegroundColor Cyan
Start-Sleep -Seconds 250

Write-Host `nDeleting IAM role -ForegroundColor Cyan
aws iam delete-role --role-name ( "KarpenterNodeRole-" + $env:CLUSTER_NAME )

# This can take a long time, so make a sound so the user know it's complete
[console]::beep(500,300)