cls
Write-Host ""
Write-Host ::: Build EKS Cluster With Karpenter v1 ::: -ForegroundColor Cyan
Write-Host ""

# Prompt for the user's name
Write-Host Please type your userid.  This is used to tag these cloud resources as yours -ForegroundColor Green 
$sOwner = Read-Host
$env:CLUSTER_OWNER = $sOwner

# Start a timer
$oStopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
$oStopWatch.Start()

Write-Host `nReading AWS settings  -ForegroundColor Cyan
$env:KARPENTER_NAMESPACE = "kube-system"
$env:KARPENTER_VERSION = "1.0.1"
$env:K8S_VERSION = "1.30"

$env:AWS_PARTITION = "aws" # if you are not using standard partitions, you may need to configure to aws-cn / aws-us-gov
$env:CLUSTER_NAME = $env:CLUSTER_OWNER + "-karpenter-demo"
$env:AWS_DEFAULT_REGION = "us-east-2"
$env:AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
$env:TEMPOUT = "NUL"
$env:ARM_AMI_ID = "$(aws ssm get-parameter --name /aws/service/eks/optimized-ami/$env:K8S_VERSION/amazon-linux-2-arm64/recommended/image_id --query Parameter.Value --output text)"
$env:AMD_AMI_ID = "$(aws ssm get-parameter --name /aws/service/eks/optimized-ami/$env:K8S_VERSION/amazon-linux-2/recommended/image_id --query Parameter.Value --output text)"
$env:GPU_AMI_ID = "$(aws ssm get-parameter --name /aws/service/eks/optimized-ami/$env:K8S_VERSION/amazon-linux-2-gpu/recommended/image_id --query Parameter.Value --output text)"

Write-Host `nWriting cluster.config  -ForegroundColor Cyan
envsubst -i .\cluster.template -o cluster.config

Write-Host `nCreating cluster $env:CLUSTER_NAME `n -ForegroundColor Cyan
curl -fsSL https://raw.githubusercontent.com/aws/karpenter-provider-aws/v"$env:KARPENTER_VERSION"/website/content/en/preview/getting-started/getting-started-with-karpenter/cloudformation.yaml  > "./karpenter.cftemplate"
aws cloudformation deploy `
  --stack-name "Karpenter-$env:CLUSTER_NAME" `
  --template-file "./karpenter.cftemplate" `
  --capabilities CAPABILITY_NAMED_IAM `
  --parameter-overrides "ClusterName=$env:CLUSTER_NAME"

eksctl create cluster -f cluster.config

$env:CLUSTER_ENDPOINT="$(aws eks describe-cluster --name "$env:CLUSTER_NAME" --query "cluster.endpoint" --output text)"
$env:KARPENTER_IAM_ROLE_ARN="arn:$env:AWS_PARTITION:iam::$env:AWS_ACCOUNT_ID:role/$env:CLUSTER_NAME-karpenter"

Write-Host `nCreating a linked role to allow using spot instances  `n -ForegroundColor Cyan
Write-Host `nNOTE: If you see an error '"Service role name AWSServiceRoleForEC2Spot has been taken in this account"' simply disregard.  It means the linked role is already created.
aws iam create-service-linked-role --aws-service-name spot.amazonaws.com

Write-Host `nInstalling Karpenter  -ForegroundColor Cyan
helm registry logout public.ecr.aws
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter --version "$env:KARPENTER_VERSION" --namespace "$env:KARPENTER_NAMESPACE" --create-namespace `
  --set "settings.clusterName=$env:CLUSTER_NAME" `
  --set "settings.interruptionQueue=$env:CLUSTER_NAME" `
  --set controller.resources.requests.cpu=1 `
  --set controller.resources.requests.memory=1Gi `
  --set controller.resources.limits.cpu=1 `
  --set controller.resources.limits.memory=1Gi `
  --wait

Write-Host `nCreating nodepool  -ForegroundColor Cyan
envsubst -i .\nodepool.template -o nodepool.yaml
kubectl apply -f nodepool.yaml

# Stop the timer
$oStopWatch.Stop()
Write-Host `nMinutes elapsed: $oStopWatch.Elapsed.Minutes -ForegroundColor Cyan

# This can take a long time, so make a sound so the user know it's complete
[console]::beep(500,300)
