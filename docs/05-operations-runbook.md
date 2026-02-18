# Operations Runbook

This document lists operational checks and troubleshooting steps.

---

## Check EKS Cluster

kubectl get nodes
kubectl get pods -A


---

## Check ALB Health

AWS Console:
EC2 → Target Groups → Health Status

Targets must be healthy.

---

## Check Application

kubectl logs <pod-name>


---

## Restart Deployment

kubectl rollout restart deployment weather-app

---

## Scale Application

kubectl scale deployment weather-app --replicas=3


---

## Check Route Tables

Public subnet → IGW
Private subnet → NAT Gateway

---

## Common Issues

### Pods not starting
- Check image pull
- Check DockerHub credentials

### ALB target unhealthy
- Verify NodePort
- Verify Security Groups
- Verify listener rules

### Jenkins cannot deploy
- Check kubeconfig
- Check AWS credentials
- Check IAM role

