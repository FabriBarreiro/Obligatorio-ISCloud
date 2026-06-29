resource "aws_instance" "bastion" {

  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name

  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.instance_name}"
      Role = "Bastion"
    }
  )
}