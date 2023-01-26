### Tools needed:
bash
kubectl
helm

### Steps:

1. Create EKS Cluster

2. Get the kube config

3. Associate OIDC IAM Identity provider for EKS
- This is needed so pods can authenticate with IAM Role to AWS IAM just like EC2 Instance will do

4. Install the specific controller via deploy-controller.sh (modify the variables on top first)
