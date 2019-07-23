terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region     = "eu-central-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_vpc" "k8s" {
  cidr_block = "10.10.0.0/16"

  tags = {
    Name = "ldap_k8s"
  }
}

resource "aws_subnet" "k8s_external" {
  vpc_id     = aws_vpc.k8s.id
  cidr_block = "10.10.1.0/24"

  tags = {
    Name = "external"
  }
}

resource "aws_internet_gateway" "k8s" {
  vpc_id = aws_vpc.k8s.id

  tags = {
    Name = "for_k8s"
  }
}

resource "aws_key_pair" "ssh_access" {
  key_name   = "stanislav_ssh"
  public_key = var.ssh_key
}

data "aws_ami" "amazon_ami" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  owners = ["amazon"]
}

data "aws_ami" "ubuntu_ami" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  owners = ["099720109477"]
}

resource "aws_security_group" "bastion" {
  name   = "bastion"
  vpc_id = aws_vpc.k8s.id
  ingress {
    from_port   = "443"
    to_port     = "443"
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "k8s" {
  name   = "k8s"
  vpc_id = aws_vpc.k8s.id
  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = [aws_subnet.k8s_external.cidr_block]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_route_table" "ext" {
  vpc_id = aws_vpc.k8s.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s.id
  }
}

resource "aws_route_table_association" "ext" {
  subnet_id      = aws_subnet.k8s_external.id
  route_table_id = aws_route_table.ext.id
}

data "template_file" "init_sh" {
  template = file("./init.sh")
  vars = {
    master_ip    = aws_instance.master.private_ip
    worker1_ip   = aws_instance.worker1.private_ip
    worker2_ip   = aws_instance.worker2.private_ip
    ssh_key      = var.ssh_priv
    dependencies = file("./ansible/dependencies.yml")
    master       = file("./ansible/master.yml")
    workers      = file("./ansible/workers.yml")
  }
}

data "template_file" "init_py" {
  template = file("./init_py.sh")
}

data "template_cloudinit_config" "bastion" {
  gzip = true
  base64_encode = true
  part {
    content_type = "text/x-shellscript"
    content = data.template_file.init_sh.rendered
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_ami.id
  subnet_id                   = aws_subnet.k8s_external.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.ssh_access.key_name
  instance_type               = "t2.micro"
  user_data_base64            = data.template_cloudinit_config.bastion.rendered
  tags = {
    Name = "bastion"
  }
}

resource "aws_instance" "master" {
  ami                    = data.aws_ami.ubuntu_ami.id
  subnet_id              = aws_subnet.k8s_external.id
  vpc_security_group_ids = [aws_security_group.k8s.id]
  associate_public_ip_address = true
  key_name               = aws_key_pair.ssh_access.key_name
  user_data_base64            = base64encode(data.template_file.init_py.rendered)
  instance_type          = "t2.medium"
  tags = {
    Name = "master"
  }
}

resource "aws_instance" "worker1" {
  ami                    = data.aws_ami.ubuntu_ami.id
  subnet_id              = aws_subnet.k8s_external.id
  vpc_security_group_ids = [aws_security_group.k8s.id]
  associate_public_ip_address = true
  key_name               = aws_key_pair.ssh_access.key_name
  user_data_base64            = base64encode(data.template_file.init_py.rendered)
  instance_type          = "t2.medium"
  tags = {
    Name = "worker1"
  }
}

resource "aws_instance" "worker2" {
  ami                    = data.aws_ami.ubuntu_ami.id
  subnet_id              = aws_subnet.k8s_external.id
  vpc_security_group_ids = [aws_security_group.k8s.id]
  associate_public_ip_address = true
  key_name               = aws_key_pair.ssh_access.key_name
  user_data_base64            = base64encode(data.template_file.init_py.rendered)
  instance_type          = "t2.medium"
  tags = {
    Name = "worker2"
  }
}

