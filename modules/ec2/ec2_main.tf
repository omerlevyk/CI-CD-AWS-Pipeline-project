resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = var.associate_public_ip
  key_name                    = var.key_name != "" ? var.key_name : null
  user_data                   = var.user_data != "" ? var.user_data : null
  iam_instance_profile        = var.iam_instance_profile_name != "" ? var.iam_instance_profile_name : null

  tags = {
    Name = var.instance_name
  }
}
