resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Allow HTTP/HTTPS from internet"
  vpc_id      = var.vpc_id
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Allow SSH from internet"
  vpc_id      = var.vpc_id
}

resource "aws_security_group" "private_instances_sg" {
  name        = "private_instances_sg"
  description = "Allow traffic only from ALB and bastion"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "alb_http" {
  type              = "ingress"
  security_group_id = aws_security_group.alb_sg.id

  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = var.alb_ingress_cidrs
}

resource "aws_security_group_rule" "alb_https" {
  type              = "ingress"
  security_group_id = aws_security_group.alb_sg.id

  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = var.alb_ingress_cidrs
}

resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  security_group_id = aws_security_group.alb_sg.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "bastion_ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.bastion_sg.id

  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "private_from_alb_80" {
  type                     = "ingress"
  security_group_id        = aws_security_group.private_instances_sg.id
  source_security_group_id = aws_security_group.alb_sg.id

  from_port = 80
  to_port   = 80
  protocol  = "tcp"
}

resource "aws_security_group_rule" "private_from_alb_8080" {
  type                     = "ingress"
  security_group_id        = aws_security_group.private_instances_sg.id
  source_security_group_id = aws_security_group.alb_sg.id

  from_port = 8080
  to_port   = 8080
  protocol  = "tcp"
}

resource "aws_security_group_rule" "private_from_alb_443" {
  type                     = "ingress"
  security_group_id        = aws_security_group.private_instances_sg.id
  source_security_group_id = aws_security_group.alb_sg.id

  from_port = 443
  to_port   = 443
  protocol  = "tcp"
}

resource "aws_security_group_rule" "private_ssh_internal" {
  type                     = "ingress"
  security_group_id        = aws_security_group.private_instances_sg.id
  source_security_group_id = aws_security_group.private_instances_sg.id

  from_port = 22
  to_port   = 22
  protocol  = "tcp"
}

resource "aws_security_group_rule" "private_from_bastion_ssh" {
  type                     = "ingress"
  security_group_id        = aws_security_group.private_instances_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id

  from_port = 22
  to_port   = 22
  protocol  = "tcp"
}

resource "aws_security_group_rule" "private_egress" {
  type              = "egress"
  security_group_id = aws_security_group.private_instances_sg.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
