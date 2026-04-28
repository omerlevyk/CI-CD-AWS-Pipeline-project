#!/usr/bin/env bash
set -euo pipefail

# Morning startup (non-destructive):
# - Starts GitLab/Jenkins EC2 instances
# - Scales EKS managed nodegroups up for working day
#
# Default targets align with current Terraform:
# - min=1 desired=2 max=2

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") [--profile new] [--region us-east-1] [--cluster weather-app-eks] [--min 1] [--desired 2] [--max 2] [--wait-seconds 300] [--dry-run]

Options:
  --profile       AWS CLI profile (default: new)
  --region        AWS region (default: us-east-1)
  --cluster       EKS cluster name (default: weather-app-eks)
  --min           EKS nodegroup min size (default: 1)
  --desired       EKS nodegroup desired size (default: 2)
  --max           EKS nodegroup max size (default: 2)
  --wait-seconds  Max seconds to wait for start/up requests (default: 300)
  --dry-run       Print actions only
USAGE
}

PROFILE="new"
REGION="us-east-1"
CLUSTER_NAME="weather-app-eks"
MIN_SIZE=1
DESIRED_SIZE=2
MAX_SIZE=2
WAIT_SECONDS=300
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --profile)
    PROFILE="$2"
    shift 2
    ;;
  --region)
    REGION="$2"
    shift 2
    ;;
  --cluster)
    CLUSTER_NAME="$2"
    shift 2
    ;;
  --min)
    MIN_SIZE="$2"
    shift 2
    ;;
  --desired)
    DESIRED_SIZE="$2"
    shift 2
    ;;
  --max)
    MAX_SIZE="$2"
    shift 2
    ;;
  --wait-seconds)
    WAIT_SECONDS="$2"
    shift 2
    ;;
  --dry-run)
    DRY_RUN="true"
    shift
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

AWS=(aws --profile "$PROFILE" --region "$REGION")

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY-RUN: $*"
  else
    eval "$*"
  fi
}

find_ec2_targets() {
  "${AWS[@]}" ec2 describe-instances \
    --filters \
    Name=instance-state-name,Values=stopped,stopping \
    Name=tag:Name,Values='*gitlab*','*jenkins*' \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text 2>/dev/null || true
}

start_ec2_targets() {
  local ids="$1"
  if [[ -z "$ids" ]]; then
    log "No stopped/stopping GitLab/Jenkins instances found"
    return
  fi

  log "Starting EC2 instances: $ids"
  run "${AWS[*]} ec2 start-instances --instance-ids $ids >/dev/null"

  if [[ "$DRY_RUN" == "false" && "$WAIT_SECONDS" -gt 0 ]]; then
    log "Waiting (max ${WAIT_SECONDS}s) for EC2 instances to be running..."
    timeout "${WAIT_SECONDS}" "${AWS[@]}" ec2 wait instance-running --instance-ids $ids ||
      log "EC2 start wait timed out (requests were still sent)"
  fi
}

scale_nodegroups_up() {
  local ngs
  ngs="$("${AWS[@]}" eks list-nodegroups --cluster-name "$CLUSTER_NAME" --query 'nodegroups[]' --output text 2>/dev/null || true)"
  if [[ -z "$ngs" ]]; then
    log "No EKS nodegroups found for cluster: $CLUSTER_NAME"
    return
  fi

  for ng in $ngs; do
    log "Scaling up nodegroup $ng -> min=$MIN_SIZE desired=$DESIRED_SIZE max=$MAX_SIZE"
    run "${AWS[*]} eks update-nodegroup-config --cluster-name '$CLUSTER_NAME' --nodegroup-name '$ng' --scaling-config minSize=$MIN_SIZE,desiredSize=$DESIRED_SIZE,maxSize=$MAX_SIZE >/dev/null"
  done

  if [[ "$DRY_RUN" == "false" && "$WAIT_SECONDS" -gt 0 ]]; then
    for ng in $ngs; do
      log "Waiting (max ${WAIT_SECONDS}s) for nodegroup update to settle: $ng"
      timeout "${WAIT_SECONDS}" "${AWS[@]}" eks wait nodegroup-active --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" ||
        log "Nodegroup wait timed out for $ng (update request was still sent)"
    done
  fi
}

log "Starting workday startup"
log "profile=$PROFILE region=$REGION cluster=$CLUSTER_NAME min=$MIN_SIZE desired=$DESIRED_SIZE max=$MAX_SIZE dry_run=$DRY_RUN"

ids="$(find_ec2_targets)"
start_ec2_targets "$ids"
scale_nodegroups_up

log "Startup script finished"
