#!/usr/bin/env bash
set -euo pipefail

# Full AWS account inventory via AWS CLI.
# Outputs JSON files per service under a timestamped folder.

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") [--regions enabled|all|current|REGION[,REGION2...]] [--out-dir PATH]

Examples:
  $(basename "$0")
  $(basename "$0") --regions enabled
  $(basename "$0") --regions current
  $(basename "$0") --regions us-east-1,us-west-2 --out-dir /tmp/aws-inventory

Notes:
  - Uses current AWS CLI auth context (env vars / profile / SSO session).
  - Some calls may fail if the principal lacks permissions; failures are logged.
USAGE
}

REGIONS_MODE="enabled"
OUT_DIR_BASE="${PWD}/aws-account-inventory"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --regions)
    REGIONS_MODE="${2:-}"
    shift 2
    ;;
  --out-dir)
    OUT_DIR_BASE="${2:-}"
    shift 2
    ;;
  -h | --help)
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

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found in PATH" >&2
  exit 1
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${OUT_DIR_BASE%/}/${TS}"
GLOBAL_DIR="$OUT_DIR/global"
REGIONAL_DIR="$OUT_DIR/regional"
mkdir -p "$GLOBAL_DIR" "$REGIONAL_DIR"

FAIL_LOG="$OUT_DIR/failures.log"
RUN_LOG="$OUT_DIR/run.log"

touch "$FAIL_LOG" "$RUN_LOG"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "$RUN_LOG"
}

record_fail() {
  local name="$1"
  local err_file="$2"
  {
    echo "-----"
    echo "check: $name"
    sed 's/^/  /' "$err_file"
  } >>"$FAIL_LOG"
}

capture_json() {
  local name="$1"
  local out_file="$2"
  shift 2

  local err_file
  err_file="$(mktemp)"

  if "$@" >"$out_file" 2>"$err_file"; then
    rm -f "$err_file"
  else
    record_fail "$name" "$err_file"
    rm -f "$err_file"
  fi
}

# Validate caller identity first
CALLER_JSON="$OUT_DIR/caller_identity.json"
if ! aws sts get-caller-identity >"$CALLER_JSON" 2>"$OUT_DIR/auth_error.log"; then
  echo "Unable to call sts:GetCallerIdentity. Check your AWS auth/session." >&2
  cat "$OUT_DIR/auth_error.log" >&2
  exit 1
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo unknown)"
ARN="$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo unknown)"
log "Authenticated as $ARN (account: $ACCOUNT_ID)"

# Decide region list
get_current_region() {
  local r=""
  r="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
  if [[ -z "$r" ]]; then
    r="$(aws configure get region 2>/dev/null || true)"
  fi
  if [[ -z "$r" ]]; then
    r="us-east-1"
  fi
  echo "$r"
}

REGIONS=()
if [[ "$REGIONS_MODE" == "enabled" ]]; then
  mapfile -t REGIONS < <(aws ec2 describe-regions --all-regions --query "Regions[?OptInStatus=='opt-in-not-required'||OptInStatus=='opted-in'].RegionName" --output text | tr '\t' '\n' | sort)
elif [[ "$REGIONS_MODE" == "all" ]]; then
  mapfile -t REGIONS < <(aws ec2 describe-regions --all-regions --query 'Regions[].RegionName' --output text | tr '\t' '\n' | sort)
elif [[ "$REGIONS_MODE" == "current" ]]; then
  REGIONS=("$(get_current_region)")
else
  IFS=',' read -r -a REGIONS <<<"$REGIONS_MODE"
fi

if [[ ${#REGIONS[@]} -eq 0 ]]; then
  echo "No regions resolved. Aborting." >&2
  exit 1
fi

printf '%s\n' "${REGIONS[@]}" >"$OUT_DIR/regions.txt"

log "Collecting global services"

# Global-ish checks
capture_json "iam_list_account_aliases" "$GLOBAL_DIR/iam_list_account_aliases.json" aws iam list-account-aliases
capture_json "iam_get_account_summary" "$GLOBAL_DIR/iam_get_account_summary.json" aws iam get-account-summary
capture_json "iam_list_users" "$GLOBAL_DIR/iam_list_users.json" aws iam list-users
capture_json "iam_list_groups" "$GLOBAL_DIR/iam_list_groups.json" aws iam list-groups
capture_json "iam_list_roles" "$GLOBAL_DIR/iam_list_roles.json" aws iam list-roles
capture_json "iam_list_policies_local" "$GLOBAL_DIR/iam_list_policies_local.json" aws iam list-policies --scope Local
capture_json "iam_list_instance_profiles" "$GLOBAL_DIR/iam_list_instance_profiles.json" aws iam list-instance-profiles
capture_json "iam_list_open_id_connect_providers" "$GLOBAL_DIR/iam_list_open_id_connect_providers.json" aws iam list-open-id-connect-providers
capture_json "iam_list_saml_providers" "$GLOBAL_DIR/iam_list_saml_providers.json" aws iam list-saml-providers
capture_json "iam_get_credential_report" "$GLOBAL_DIR/iam_get_credential_report.json" aws iam get-credential-report

capture_json "s3api_list_buckets" "$GLOBAL_DIR/s3api_list_buckets.json" aws s3api list-buckets
capture_json "route53_list_hosted_zones" "$GLOBAL_DIR/route53_list_hosted_zones.json" aws route53 list-hosted-zones
capture_json "route53_list_health_checks" "$GLOBAL_DIR/route53_list_health_checks.json" aws route53 list-health-checks
capture_json "cloudfront_list_distributions" "$GLOBAL_DIR/cloudfront_list_distributions.json" aws cloudfront list-distributions
capture_json "organizations_describe_organization" "$GLOBAL_DIR/organizations_describe_organization.json" aws organizations describe-organization
capture_json "budgets_describe_budgets" "$GLOBAL_DIR/budgets_describe_budgets.json" aws budgets describe-budgets --account-id "$ACCOUNT_ID"

# Tagging API (regional endpoint)
for region in "${REGIONS[@]}"; do
  mkdir -p "$REGIONAL_DIR/$region"
  capture_json "tagging_get_resources_${region}" "$REGIONAL_DIR/$region/tagging_get_resources.json" \
    aws --region "$region" resourcegroupstaggingapi get-resources
  capture_json "tagging_get_tag_keys_${region}" "$REGIONAL_DIR/$region/tagging_get_tag_keys.json" \
    aws --region "$region" resourcegroupstaggingapi get-tag-keys
  capture_json "tagging_get_tag_values_Name_${region}" "$REGIONAL_DIR/$region/tagging_get_tag_values_name.json" \
    aws --region "$region" resourcegroupstaggingapi get-tag-values --key Name

done

log "Collecting regional services in ${#REGIONS[@]} region(s)"

for region in "${REGIONS[@]}"; do
  rdir="$REGIONAL_DIR/$region"
  mkdir -p "$rdir"

  log "Region: $region"

  # Core compute/network
  capture_json "ec2_describe_vpcs_${region}" "$rdir/ec2_describe_vpcs.json" aws --region "$region" ec2 describe-vpcs
  capture_json "ec2_describe_subnets_${region}" "$rdir/ec2_describe_subnets.json" aws --region "$region" ec2 describe-subnets
  capture_json "ec2_describe_instances_${region}" "$rdir/ec2_describe_instances.json" aws --region "$region" ec2 describe-instances
  capture_json "ec2_describe_security_groups_${region}" "$rdir/ec2_describe_security_groups.json" aws --region "$region" ec2 describe-security-groups
  capture_json "ec2_describe_internet_gateways_${region}" "$rdir/ec2_describe_internet_gateways.json" aws --region "$region" ec2 describe-internet-gateways
  capture_json "ec2_describe_nat_gateways_${region}" "$rdir/ec2_describe_nat_gateways.json" aws --region "$region" ec2 describe-nat-gateways
  capture_json "ec2_describe_route_tables_${region}" "$rdir/ec2_describe_route_tables.json" aws --region "$region" ec2 describe-route-tables
  capture_json "ec2_describe_addresses_${region}" "$rdir/ec2_describe_addresses.json" aws --region "$region" ec2 describe-addresses
  capture_json "ec2_describe_key_pairs_${region}" "$rdir/ec2_describe_key_pairs.json" aws --region "$region" ec2 describe-key-pairs
  capture_json "ec2_describe_volumes_${region}" "$rdir/ec2_describe_volumes.json" aws --region "$region" ec2 describe-volumes
  capture_json "ec2_describe_snapshots_self_${region}" "$rdir/ec2_describe_snapshots_self.json" aws --region "$region" ec2 describe-snapshots --owner-ids self

  # Load balancers
  capture_json "elbv2_describe_load_balancers_${region}" "$rdir/elbv2_describe_load_balancers.json" aws --region "$region" elbv2 describe-load-balancers
  capture_json "elbv2_describe_target_groups_${region}" "$rdir/elbv2_describe_target_groups.json" aws --region "$region" elbv2 describe-target-groups

  # Containers / Kubernetes
  capture_json "eks_list_clusters_${region}" "$rdir/eks_list_clusters.json" aws --region "$region" eks list-clusters
  capture_json "ecr_describe_repositories_${region}" "$rdir/ecr_describe_repositories.json" aws --region "$region" ecr describe-repositories
  capture_json "ecs_list_clusters_${region}" "$rdir/ecs_list_clusters.json" aws --region "$region" ecs list-clusters

  # Storage / DB
  capture_json "efs_describe_file_systems_${region}" "$rdir/efs_describe_file_systems.json" aws --region "$region" efs describe-file-systems
  capture_json "rds_describe_db_instances_${region}" "$rdir/rds_describe_db_instances.json" aws --region "$region" rds describe-db-instances
  capture_json "rds_describe_db_clusters_${region}" "$rdir/rds_describe_db_clusters.json" aws --region "$region" rds describe-db-clusters
  capture_json "dynamodb_list_tables_${region}" "$rdir/dynamodb_list_tables.json" aws --region "$region" dynamodb list-tables

  # Serverless / integration
  capture_json "lambda_list_functions_${region}" "$rdir/lambda_list_functions.json" aws --region "$region" lambda list-functions
  capture_json "apigateway_get_rest_apis_${region}" "$rdir/apigateway_get_rest_apis.json" aws --region "$region" apigateway get-rest-apis
  capture_json "apigatewayv2_get_apis_${region}" "$rdir/apigatewayv2_get_apis.json" aws --region "$region" apigatewayv2 get-apis
  capture_json "sqs_list_queues_${region}" "$rdir/sqs_list_queues.json" aws --region "$region" sqs list-queues
  capture_json "sns_list_topics_${region}" "$rdir/sns_list_topics.json" aws --region "$region" sns list-topics

  # Observability / infra mgmt
  capture_json "logs_describe_log_groups_${region}" "$rdir/logs_describe_log_groups.json" aws --region "$region" logs describe-log-groups
  capture_json "cloudwatch_describe_alarms_${region}" "$rdir/cloudwatch_describe_alarms.json" aws --region "$region" cloudwatch describe-alarms
  capture_json "cloudformation_list_stacks_${region}" "$rdir/cloudformation_list_stacks.json" aws --region "$region" cloudformation list-stacks
  capture_json "autoscaling_describe_auto_scaling_groups_${region}" "$rdir/autoscaling_describe_auto_scaling_groups.json" aws --region "$region" autoscaling describe-auto-scaling-groups

  # Security / encryption
  capture_json "acm_list_certificates_${region}" "$rdir/acm_list_certificates.json" aws --region "$region" acm list-certificates
  capture_json "kms_list_aliases_${region}" "$rdir/kms_list_aliases.json" aws --region "$region" kms list-aliases
  capture_json "secretsmanager_list_secrets_${region}" "$rdir/secretsmanager_list_secrets.json" aws --region "$region" secretsmanager list-secrets

  # Misc commonly used services
  capture_json "elasticache_describe_cache_clusters_${region}" "$rdir/elasticache_describe_cache_clusters.json" aws --region "$region" elasticache describe-cache-clusters
  capture_json "opensearch_list_domain_names_${region}" "$rdir/opensearch_list_domain_names.json" aws --region "$region" opensearch list-domain-names
  capture_json "events_list_rules_${region}" "$rdir/events_list_rules.json" aws --region "$region" events list-rules
  capture_json "backup_list_backup_plans_${region}" "$rdir/backup_list_backup_plans.json" aws --region "$region" backup list-backup-plans
  capture_json "ssm_describe_parameters_${region}" "$rdir/ssm_describe_parameters.json" aws --region "$region" ssm describe-parameters
  capture_json "ssm_describe_instance_information_${region}" "$rdir/ssm_describe_instance_information.json" aws --region "$region" ssm describe-instance-information

  # WAFv2 regional scope
  capture_json "wafv2_list_web_acls_regional_${region}" "$rdir/wafv2_list_web_acls_regional.json" aws --region "$region" wafv2 list-web-acls --scope REGIONAL

done

# WAFv2 global (CloudFront scope uses us-east-1 endpoint)
capture_json "wafv2_list_web_acls_cloudfront" "$GLOBAL_DIR/wafv2_list_web_acls_cloudfront.json" aws --region us-east-1 wafv2 list-web-acls --scope CLOUDFRONT

FILE_COUNT="$(find "$OUT_DIR" -type f | wc -l | tr -d ' ')"
FAIL_COUNT="0"
if [[ -s "$FAIL_LOG" ]]; then
  FAIL_COUNT="$(grep -c '^check:' "$FAIL_LOG" || true)"
fi

cat >"$OUT_DIR/SUMMARY.txt" <<SUMMARY
AWS account inventory completed.

Account ID: $ACCOUNT_ID
Principal ARN: $ARN
Timestamp (UTC): $TS
Regions scanned: ${#REGIONS[@]}
Output directory: $OUT_DIR
Files written: $FILE_COUNT
Checks with errors: $FAIL_COUNT

If errors > 0, review:
  $FAIL_LOG
SUMMARY

log "Done. Output: $OUT_DIR"
log "Checks with errors: $FAIL_COUNT (see failures.log)"

echo "$OUT_DIR"
