#!/bin/bash

#This script was created from the Official documentation
#Please ensure to follow all steps before executing

# Update the service name variables as needed
#Service name
SERVICE="s3"
#Cluster name
EKS_CLUSTER_NAME="k8s-accedia-demo"
#AWS Region
AWS_REGION="eu-west-1"
#AWS Profile
AWS_PROFILE=meetup
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text --profile $AWS_PROFILE)
OIDC_PROVIDER=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION --profile $AWS_PROFILE --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")
#AWS Namespace
ACK_K8S_NAMESPACE="ack-system"
#Template for the service account names
ACK_K8S_SERVICE_ACCOUNT_NAME=ack-$SERVICE-controller
RELEASE_VERSION=`curl -sL https://api.github.com/repos/aws-controllers-k8s/$SERVICE-controller/releases/latest | grep '"tag_name":' | cut -d'"' -f4`

echo "Installing the controller ..."

aws ecr-public get-login-password --region us-east-1 --profile $AWS_PROFILE | helm registry login --username AWS --password-stdin public.ecr.aws

helm install --create-namespace -n $ACK_K8S_NAMESPACE ack-$SERVICE-controller \
  oci://public.ecr.aws/aws-controllers-k8s/$SERVICE-chart --version=$RELEASE_VERSION --set=aws.region=$AWS_REGION

echo "Wait 10 seconds in order for the controller to be deployed ..."
sleep 10

read -r -d '' TRUST_RELATIONSHIP <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:${ACK_K8S_NAMESPACE}:${ACK_K8S_SERVICE_ACCOUNT_NAME}"
        }
      }
    }
  ]
}
EOF
echo "${TRUST_RELATIONSHIP}" > trust.json

ACK_CONTROLLER_IAM_ROLE="ack-${SERVICE}-controller-$EKS_CLUSTER_NAME"
ACK_CONTROLLER_IAM_ROLE_DESCRIPTION="IRSA role for ACK ${SERVICE} controller deployment on EKS cluster using Helm charts"
aws iam create-role --role-name "${ACK_CONTROLLER_IAM_ROLE}" --profile $AWS_PROFILE --assume-role-policy-document file://trust.json --description "${ACK_CONTROLLER_IAM_ROLE_DESCRIPTION}"
ACK_CONTROLLER_IAM_ROLE_ARN=$(aws iam get-role --role-name=$ACK_CONTROLLER_IAM_ROLE --query Role.Arn --output text --profile $AWS_PROFILE)

#===================================

# Download the recommended managed and inline policies and apply them to the
# newly created IRSA role
BASE_URL=https://raw.githubusercontent.com/aws-controllers-k8s/${SERVICE}-controller/main
POLICY_ARN_URL=${BASE_URL}/config/iam/recommended-policy-arn
POLICY_ARN_STRINGS="$(wget -qO- ${POLICY_ARN_URL})"

INLINE_POLICY_URL=${BASE_URL}/config/iam/recommended-inline-policy
INLINE_POLICY="$(wget -qO- ${INLINE_POLICY_URL})"

while IFS= read -r POLICY_ARN; do
    echo -n "Attaching $POLICY_ARN ... "
    aws iam attach-role-policy \
        --role-name "${ACK_CONTROLLER_IAM_ROLE}" \
        --policy-arn "${POLICY_ARN}" \
        --profile $AWS_PROFILE
    echo "ok."
done <<< "$POLICY_ARN_STRINGS"

if [ ! -z "$INLINE_POLICY" ]; then
    echo -n "Putting inline policy ... "
    aws iam put-role-policy \
        --role-name "${ACK_CONTROLLER_IAM_ROLE}" \
        --policy-name "ack-recommended-policy" \
        --policy-document "$INLINE_POLICY" \
        --profile $AWS_PROFILE
    echo "ok."
fi


#==========================

kubectl describe serviceaccount/$ACK_K8S_SERVICE_ACCOUNT_NAME -n $ACK_K8S_NAMESPACE

# Annotate the service account with the ARN
IRSA_ROLE_ARN=eks.amazonaws.com/role-arn=$ACK_CONTROLLER_IAM_ROLE_ARN
kubectl annotate serviceaccount -n $ACK_K8S_NAMESPACE $ACK_K8S_SERVICE_ACCOUNT_NAME $IRSA_ROLE_ARN --overwrite


# Note the deployment name for ACK service controller from following command
kubectl get deployments -n $ACK_K8S_NAMESPACE
kubectl -n $ACK_K8S_NAMESPACE rollout restart deployment ack-$SERVICE-controller-$SERVICE-chart
