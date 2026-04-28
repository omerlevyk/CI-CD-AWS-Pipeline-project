resource "aws_security_group" "efs" {
  name        = "${var.cluster_name}-efs-sg"
  description = "Allow EKS nodes to access EFS over NFS"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "efs_ingress_nfs_from_eks_nodes" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  source_security_group_id = module.eks.node_security_group_id
  description              = "NFS from EKS node security group"
}

resource "aws_security_group_rule" "efs_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.efs.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
}

resource "aws_efs_file_system" "weather_history" {
  creation_token = "${var.cluster_name}-weather-history"
}

resource "aws_efs_mount_target" "weather_history" {
  # Use static keys so Terraform can plan even when subnet IDs are unknown until apply.
  for_each = {
    subnet0 = module.vpc.private_subnet_ids[0]
    subnet1 = module.vpc.private_subnet_ids[1]
  }

  file_system_id  = aws_efs_file_system.weather_history.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}
