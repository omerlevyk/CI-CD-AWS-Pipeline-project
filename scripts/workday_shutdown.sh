#!/usr/bin/env bash
set -euo pipefail

# End-of-day cost saver (non-destructive):
# - Stops GitLab/Jenkins EC2 instances
# - Scales EKS managed nodegroups down to 0
#
# Default behavior is optimized for speed:
# - Sends stop/scale requests immediately
# - Optional bounded wait (default 120s)

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") [--profile new] [--region us-east-1] [--cluster weather-app-eks] [--wait-seconds 120] [--dry-run]

Options:
  --profile       AWS CLI profile (default: new)
  --region        AWS region (default: us-east-1)
  --cluster       EKS cluster name (default: weather-app-eks)
  --wait-seconds  Max seconds to wait for stop/down requests (default: 120)
  --dry-run       Print actions only
USAGE
}

PROFILE="new"
REGION="us-east-1"
CLUSTER_NAME="weather-app-eks"
WAIT_SECONDS=120
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --cluster) CLUSTER_NAME="$2"; shift 2 ;;
    --wait-seconds) WAIT_SECONDS="$2"; shift 2 ;;
    --dry-run) DRY_RUN="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
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
      Name=instance-state-name,Values=pending,running,stopping \
      Name=tag:Name,Values='*gitlab*','*jenkins*' \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text 2>/dev/null || true
}

stop_ec2_targets() {
  local ids="$1"
  if [[ -z "$ids" ]]; then
    log "No running/pending/stopping GitLab/Jenkins instances found"
    return
  fi

  log "Stopping EC2 instances: $ids"
  run "${AWS[*]} ec2 stop-instances --instance-ids $ids >/dev/null"

  if [[ "$DRY_RUN" == "false" && "$WAIT_SECONDS" -gt 0 ]]; then
    log "Waiting (max ${WAIT_SECONDS}s) for EC2 instances to stop..."
    timeout "${WAIT_SECONDS}" "${AWS[@]}" ec2 wait instance-stopped --instance-ids $ids || \
      log "EC2 stop wait timed out (requests were still sent)"
  fi
}

scale_nodegroups_down() {
  local ngs
  ngs="$("${AWS[@]}" eks list-nodegroups --cluster-name "$CLUSTER_NAME" --query 'nodegroups[]' --output text 2>/dev/null || true)"
  if [[ -z "$ngs" ]]; then
    log "No EKS nodegroups found for cluster: $CLUSTER_NAME"
    return
  fi

  for ng in $ngs; do
    log "Scaling down nodegroup $ng -> min=0 desired=0 (max unchanged by default)"
    run "${AWS[*]} eks update-nodegroup-config --cluster-name '$CLUSTER_NAME' --nodegroup-name '$ng' --scaling-config minSize=0,desiredSize=0 >/dev/null"
  done

  if [[ "$DRY_RUN" == "false" && "$WAIT_SECONDS" -gt 0 ]]; then
    for ng in $ngs; do
      log "Waiting (max ${WAIT_SECONDS}s) for nodegroup update to settle: $ng"
      timeout "${WAIT_SECONDS}" "${AWS[@]}" eks wait nodegroup-active --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" || \
        log "Nodegroup wait timed out for $ng (update request was still sent)"
    done
  fi
}

log "Starting workday shutdown"
log "profile=$PROFILE region=$REGION cluster=$CLUSTER_NAME dry_run=$DRY_RUN"

ids="$(find_ec2_targets)"
stop_ec2_targets "$ids"
scale_nodegroups_down

log "Shutdown script finished"

