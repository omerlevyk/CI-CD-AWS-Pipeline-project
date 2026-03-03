#!/usr/bin/env bash
set -euo pipefail

# Bootstrap a new AWS account for this Terraform project.
# Creates:
# - S3 bucket for Terraform state
# - DynamoDB lock table
# - AWSLoadBalancerControllerIAMPolicy (if missing)
# - Optional EC2 key pair (create or import)

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") \
    --account-id <NEW_ACCOUNT_ID> \
    --region <AWS_REGION> \
    --state-bucket <S3_BUCKET_NAME> \
    [--lock-table terraform-locks] \
    [--key-name gitlab-key] \
    [--create-keypair] \
    [--import-public-key /path/to/key.pub] \
    [--profile PROFILE]

Examples:
  $(basename "$0") \
    --account-id 123456789012 \
    --region us-east-1 \
    --state-bucket my-new-tf-state-bucket \
    --create-keypair

  $(basename "$0") \
    --account-id 123456789012 \
    --region us-east-1 \
    --state-bucket my-new-tf-state-bucket \
    --import-public-key ~/.ssh/id_rsa.pub
USAGE
}

ACCOUNT_ID=""
REGION=""
STATE_BUCKET=""
LOCK_TABLE="terraform-locks"
KEY_NAME="gitlab-key"
PROFILE=""
CREATE_KEYPAIR="false"
IMPORT_PUBLIC_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --account-id)
      ACCOUNT_ID="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --state-bucket)
      STATE_BUCKET="$2"
      shift 2
      ;;
    --lock-table)
      LOCK_TABLE="$2"
      shift 2
      ;;
    --key-name)
      KEY_NAME="$2"
      shift 2
      ;;
    --create-keypair)
      CREATE_KEYPAIR="true"
      shift
      ;;
    --import-public-key)
      IMPORT_PUBLIC_KEY="$2"
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$ACCOUNT_ID" || -z "$REGION" || -z "$STATE_BUCKET" ]]; then
  echo "Error: --account-id, --region, and --state-bucket are required." >&2
  usage
  exit 1
fi

if [[ "$CREATE_KEYPAIR" == "true" && -n "$IMPORT_PUBLIC_KEY" ]]; then
  echo "Error: choose either --create-keypair or --import-public-key, not both." >&2
  exit 1
fi

if [[ -n "$IMPORT_PUBLIC_KEY" && ! -f "$IMPORT_PUBLIC_KEY" ]]; then
  echo "Error: public key file not found: $IMPORT_PUBLIC_KEY" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
POLICY_FILE="$ROOT_DIR/infra/envs/dev/iam_policy.json"
if [[ ! -f "$POLICY_FILE" ]]; then
  echo "Error: policy file not found: $POLICY_FILE" >&2
  exit 1
fi

AWS_CMD=(aws)
if [[ -n "$PROFILE" ]]; then
  AWS_CMD+=(--profile "$PROFILE")
fi

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

run_aws() {
  "${AWS_CMD[@]}" "$@"
}

# 1) Verify identity/account
CURRENT_ACCOUNT="$(run_aws sts get-caller-identity --query 'Account' --output text)"
CURRENT_ARN="$(run_aws sts get-caller-identity --query 'Arn' --output text)"
log "Authenticated as: $CURRENT_ARN"

if [[ "$CURRENT_ACCOUNT" != "$ACCOUNT_ID" ]]; then
  echo "Error: active account is $CURRENT_ACCOUNT, expected $ACCOUNT_ID" >&2
  echo "Switch AWS credentials/profile to the new account and re-run." >&2
  exit 1
fi

# 2) Create S3 state bucket (if missing)
if run_aws s3api head-bucket --bucket "$STATE_BUCKET" >/dev/null 2>&1; then
  log "S3 bucket already exists: $STATE_BUCKET"
else
  log "Creating S3 bucket: $STATE_BUCKET ($REGION)"
  if [[ "$REGION" == "us-east-1" ]]; then
    run_aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION" >/dev/null
  else
    run_aws s3api create-bucket \
      --bucket "$STATE_BUCKET" \
      --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION" >/dev/null
  fi
fi

log "Configuring S3 bucket security/versioning"
run_aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled
run_aws s3api put-bucket-encryption --bucket "$STATE_BUCKET" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
run_aws s3api put-public-access-block --bucket "$STATE_BUCKET" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# 3) Create DynamoDB lock table (if missing)
if run_aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$REGION" >/dev/null 2>&1; then
  log "DynamoDB table already exists: $LOCK_TABLE"
else
  log "Creating DynamoDB lock table: $LOCK_TABLE"
  run_aws dynamodb create-table \
    --table-name "$LOCK_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" >/dev/null

  run_aws dynamodb wait table-exists --table-name "$LOCK_TABLE" --region "$REGION"
fi

# 4) Create ALB controller IAM policy (if missing)
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
POLICY_ARN="$(run_aws iam list-policies --scope Local --query "Policies[?PolicyName=='${POLICY_NAME}'].Arn | [0]" --output text)"
if [[ "$POLICY_ARN" == "None" || -z "$POLICY_ARN" ]]; then
  log "Creating IAM managed policy: $POLICY_NAME"
  POLICY_ARN="$(run_aws iam create-policy --policy-name "$POLICY_NAME" --policy-document "file://$POLICY_FILE" --query 'Policy.Arn' --output text)"
else
  log "IAM managed policy already exists: $POLICY_ARN"
fi

# 5) Key pair handling
EXISTING_KEY="$(run_aws ec2 describe-key-pairs --region "$REGION" --query "KeyPairs[?KeyName=='${KEY_NAME}'].KeyName | [0]" --output text 2>/dev/null || true)"
if [[ "$EXISTING_KEY" != "None" && -n "$EXISTING_KEY" ]]; then
  log "EC2 key pair already exists: $KEY_NAME"
else
  if [[ "$CREATE_KEYPAIR" == "true" ]]; then
    OUT_PEM="$ROOT_DIR/infra/envs/dev/${KEY_NAME}.pem"
    log "Creating EC2 key pair: $KEY_NAME"
    run_aws ec2 create-key-pair --region "$REGION" --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "$OUT_PEM"
    chmod 600 "$OUT_PEM"
    log "Saved private key: $OUT_PEM"
  elif [[ -n "$IMPORT_PUBLIC_KEY" ]]; then
    log "Importing EC2 key pair from public key: $KEY_NAME"
    run_aws ec2 import-key-pair --region "$REGION" --key-name "$KEY_NAME" --public-key-material "fileb://$IMPORT_PUBLIC_KEY" >/dev/null
  else
    log "Skipping key pair creation/import (use --create-keypair or --import-public-key)"
  fi
fi

cat <<SUMMARY

Bootstrap complete.

Account:      $ACCOUNT_ID
Region:       $REGION
State bucket: $STATE_BUCKET
Lock table:   $LOCK_TABLE
ALB policy:   $POLICY_ARN
Key pair:     $KEY_NAME

Next steps:
1) Update infra/envs/dev/providers.tf with backend "s3" (bucket/key/region/dynamodb_table).
2) Update infra/envs/dev/terraform.tfvars for new AMIs, certificate ARN, and any CIDR changes.
3) Run terraform init -reconfigure in infra/envs/dev.
SUMMARY
