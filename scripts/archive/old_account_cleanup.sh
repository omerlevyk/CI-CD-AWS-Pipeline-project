#!/usr/bin/env bash
set -euo pipefail

# Guarded cleanup script for old AWS account resources.
# Default profile: old

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") [--profile old] [--region us-east-1] [--yes] [--dry-run]

Options:
  --profile   AWS CLI profile to use (default: old)
  --region    AWS region to clean (default: us-east-1)
  --yes       Non-interactive mode (auto-confirm every step)
  --dry-run   Print actions only, do not execute deletions

This script targets high-cost resources first:
1) Ingress (Kubernetes)
2) EKS nodegroups + cluster
3) EC2 instances
4) NAT gateways + EIPs
5) EFS mount targets + file systems
6) ALBs + target groups
7) Unattached EBS volumes
8) Owned AMIs + snapshots

It performs explicit prompts before each destructive step unless --yes is used.
USAGE
}

PROFILE="old"
REGION="us-east-1"
AUTO_YES="false"
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
    --yes)
      AUTO_YES="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
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

AWS=(aws --profile "$PROFILE" --region "$REGION")

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY-RUN: $*"
  else
    eval "$*"
  fi
}

confirm() {
  local msg="$1"
  if [[ "$AUTO_YES" == "true" ]]; then
    return 0
  fi
  echo
  read -r -p "$msg [y/N]: " ans
  [[ "${ans:-}" =~ ^[Yy]$ ]]
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}

require_cmd aws

log "Verifying identity"
ACCT_ID="$(${AWS[@]} sts get-caller-identity --query 'Account' --output text)"
ARN="$(${AWS[@]} sts get-caller-identity --query 'Arn' --output text)"
log "Using profile=$PROFILE region=$REGION account=$ACCT_ID arn=$ARN"

if ! confirm "Proceed with cleanup in account $ACCT_ID ($PROFILE)?"; then
  echo "Aborted."
  exit 0
fi

# 1) Kubernetes ingress deletion (if kubeconfig points to old cluster)
if confirm "Step 1: Delete all ingress resources in current kubectl context?"; then
  run "kubectl delete ingress -A --all --ignore-not-found"
fi

# 2) EKS nodegroups + clusters
if confirm "Step 2: Delete EKS nodegroups and clusters in $REGION?"; then
  CLUSTERS="$(${AWS[@]} eks list-clusters --query 'clusters[]' --output text || true)"
  if [[ -n "$CLUSTERS" ]]; then
    for c in $CLUSTERS; do
      log "Cluster: $c"
      NODEGROUPS="$(${AWS[@]} eks list-nodegroups --cluster-name "$c" --query 'nodegroups[]' --output text || true)"
      for ng in $NODEGROUPS; do
        log "Deleting nodegroup $ng in $c"
        run "${AWS[*]} eks delete-nodegroup --cluster-name '$c' --nodegroup-name '$ng' >/dev/null"
      done
      for ng in $NODEGROUPS; do
        log "Waiting nodegroup deleted: $ng"
        run "${AWS[*]} eks wait nodegroup-deleted --cluster-name '$c' --nodegroup-name '$ng'"
      done
      log "Deleting cluster $c"
      run "${AWS[*]} eks delete-cluster --name '$c' >/dev/null"
      log "Waiting cluster deleted: $c"
      run "${AWS[*]} eks wait cluster-deleted --name '$c'"
    done
  else
    log "No EKS clusters found"
  fi
fi

# 3) EC2 instances
if confirm "Step 3: Terminate all EC2 instances in $REGION?"; then
  INSTANCES="$(${AWS[@]} ec2 describe-instances --filters Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[].Instances[].InstanceId' --output text || true)"
  if [[ -n "$INSTANCES" ]]; then
    log "Terminating instances: $INSTANCES"
    run "${AWS[*]} ec2 terminate-instances --instance-ids $INSTANCES >/dev/null"
  else
    log "No EC2 instances found"
  fi
fi

# 4) NAT gateways
if confirm "Step 4: Delete all NAT gateways in $REGION?"; then
  NATS="$(${AWS[@]} ec2 describe-nat-gateways --filter Name=state,Values=available,pending --query 'NatGateways[].NatGatewayId' --output text || true)"
  if [[ -n "$NATS" ]]; then
    for nat in $NATS; do
      log "Deleting NAT gateway: $nat"
      run "${AWS[*]} ec2 delete-nat-gateway --nat-gateway-id '$nat' >/dev/null"
    done
  else
    log "No NAT gateways found"
  fi
fi

# 5) Release EIPs
if confirm "Step 5: Release all Elastic IPs in $REGION?"; then
  EIPS="$(${AWS[@]} ec2 describe-addresses --query 'Addresses[].AllocationId' --output text || true)"
  if [[ -n "$EIPS" ]]; then
    for eip in $EIPS; do
      log "Releasing EIP: $eip"
      run "${AWS[*]} ec2 release-address --allocation-id '$eip' >/dev/null"
    done
  else
    log "No EIPs found"
  fi
fi

# 6) EFS
if confirm "Step 6: Delete EFS mount targets and file systems in $REGION?"; then
  FILESYSTEMS="$(${AWS[@]} efs describe-file-systems --query 'FileSystems[].FileSystemId' --output text || true)"
  if [[ -n "$FILESYSTEMS" ]]; then
    for fs in $FILESYSTEMS; do
      MOUNTS="$(${AWS[@]} efs describe-mount-targets --file-system-id "$fs" --query 'MountTargets[].MountTargetId' --output text || true)"
      for mt in $MOUNTS; do
        log "Deleting EFS mount target: $mt"
        run "${AWS[*]} efs delete-mount-target --mount-target-id '$mt' >/dev/null"
      done
      if [[ -n "$MOUNTS" && "$DRY_RUN" != "true" ]]; then
        log "Waiting for EFS mount targets to be deleted for $fs"
        sleep 20
      fi
      log "Deleting EFS file system: $fs"
      run "${AWS[*]} efs delete-file-system --file-system-id '$fs' >/dev/null"
    done
  else
    log "No EFS file systems found"
  fi
fi

# 7) ALBs + target groups
if confirm "Step 7: Delete all ALBs and target groups in $REGION?"; then
  LBS="$(${AWS[@]} elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerArn' --output text || true)"
  if [[ -n "$LBS" ]]; then
    for lb in $LBS; do
      log "Deleting ALB/NLB: $lb"
      run "${AWS[*]} elbv2 delete-load-balancer --load-balancer-arn '$lb' >/dev/null"
    done
  else
    log "No load balancers found"
  fi

  # TG deletion may require LBs fully deleted first.
  if [[ "$DRY_RUN" != "true" ]]; then
    sleep 20
  fi

  TGS="$(${AWS[@]} elbv2 describe-target-groups --query 'TargetGroups[].TargetGroupArn' --output text || true)"
  if [[ -n "$TGS" ]]; then
    for tg in $TGS; do
      log "Deleting target group: $tg"
      run "${AWS[*]} elbv2 delete-target-group --target-group-arn '$tg' >/dev/null || true"
    done
  else
    log "No target groups found"
  fi
fi

# 8) Unattached EBS volumes
if confirm "Step 8: Delete all available (unattached) EBS volumes in $REGION?"; then
  VOLS="$(${AWS[@]} ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[].VolumeId' --output text || true)"
  if [[ -n "$VOLS" ]]; then
    for v in $VOLS; do
      log "Deleting EBS volume: $v"
      run "${AWS[*]} ec2 delete-volume --volume-id '$v' >/dev/null"
    done
  else
    log "No unattached EBS volumes found"
  fi
fi

# 9) AMIs + snapshots
if confirm "Step 9: Deregister all owned AMIs and delete owned snapshots in $REGION?"; then
  AMIS="$(${AWS[@]} ec2 describe-images --owners self --query 'Images[].ImageId' --output text || true)"
  if [[ -n "$AMIS" ]]; then
    for ami in $AMIS; do
      log "Deregistering AMI: $ami"
      run "${AWS[*]} ec2 deregister-image --image-id '$ami' >/dev/null"
    done
  else
    log "No owned AMIs found"
  fi

  SNAPS="$(${AWS[@]} ec2 describe-snapshots --owner-ids self --query 'Snapshots[].SnapshotId' --output text || true)"
  if [[ -n "$SNAPS" ]]; then
    for s in $SNAPS; do
      log "Deleting snapshot: $s"
      run "${AWS[*]} ec2 delete-snapshot --snapshot-id '$s' >/dev/null || true"
    done
  else
    log "No owned snapshots found"
  fi
fi

# 10) Final quick summary
log "Final quick summary"
log "EC2 instances: $( ${AWS[@]} ec2 describe-instances --filters Name=instance-state-name,Values=pending,running,stopping,stopped --query 'length(Reservations[].Instances[])' --output text || echo n/a )"
log "EKS clusters:  $( ${AWS[@]} eks list-clusters --query 'length(clusters)' --output text || echo n/a )"
log "NAT gateways:  $( ${AWS[@]} ec2 describe-nat-gateways --query 'length(NatGateways)' --output text || echo n/a )"
log "Load balancers:$( ${AWS[@]} elbv2 describe-load-balancers --query 'length(LoadBalancers)' --output text || echo n/a )"
log "EFS filesystems:$( ${AWS[@]} efs describe-file-systems --query 'length(FileSystems)' --output text || echo n/a )"

log "Cleanup script completed"
