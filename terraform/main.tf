resource "aws_ecr_repository" "frontend" {
  name                 = "frontend"
  image_tag_mutability = "MUTABLE" # Mutable for this exercise, so i can just use the latest tag, but immutable is always best
}

resource "aws_ecr_repository" "backend" {
  name                 = "backend"
  image_tag_mutability = "MUTABLE" # Mutable for this exercise, so i can just use the latest tag, but immutable is always best
}


locals {
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
  vpc_cidr = "10.0.0.0/16"

  db_user     = "john"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "elevated-signals"
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]


}

resource "aws_iam_role" "this" {
  name = "es-instance-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "this" {
  name = "es-instance-profile"
  role = aws_iam_role.this.name
}

resource "aws_iam_role_policy" "this" {
  name = "ecr-access"
  role = aws_iam_role.this.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Effect": "Allow",
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "SSM" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.this.name
}

module "frontend_instance" {
  source                      = "terraform-aws-modules/ec2-instance/aws"
  version                     = "~> 5.0"
  name                        = "frontend"
  instance_type               = "t2.micro"
  iam_instance_profile        = aws_iam_instance_profile.this.name
  key_name                    = "john"
  associate_public_ip_address = true
  monitoring                  = true
  vpc_security_group_ids = [
    module.frontend_security_group.security_group_id,
    module.allow_ssh.security_group_id
  ]
  subnet_id                   = element(module.vpc.public_subnets, 0)
  user_data_replace_on_change = true
  user_data                   = <<-EOF
    #!/bin/bash
    set -ex
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo yum install amazon-ecr-credential-helper -y
    mkdir ~/.docker && echo { \"credsStore\": \"ecr-login\" } >> ~/.docker/config.json
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    docker run -p 80:4567 --env BACKEND_PORT=80 --env BACKEND_HOST=${module.backend_instance.private_dns} --env POSTGRES_HOST=${module.db.db_instance_address} --env POSTGRES_USER=${local.db_user} ${aws_ecr_repository.frontend.repository_url} 
  EOF
}

module "backend_instance" {
  source                      = "terraform-aws-modules/ec2-instance/aws"
  version                     = "~> 5.0"
  name                        = "backend"
  instance_type               = "t2.micro"
  iam_instance_profile        = aws_iam_instance_profile.this.name
  key_name                    = var.ssh_key_name
  associate_public_ip_address = true
  monitoring                  = true
  vpc_security_group_ids = [
    module.backend_security_group.security_group_id,
    module.allow_ssh.security_group_id
  ]
  subnet_id                   = element(module.vpc.public_subnets, 0)
  user_data_replace_on_change = true
  user_data                   = <<-EOF
    #!/bin/bash
    set -ex
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo yum install amazon-ecr-credential-helper -y
    mkdir ~/.docker && echo { \"credsStore\": \"ecr-login\" } >> ~/.docker/config.json
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    docker run -p 80:5000 --env ELASTICSEARCH_HOST=${module.elasticsearch_instance.private_dns} ${aws_ecr_repository.backend.repository_url}
  EOF
}

module "elasticsearch_instance" {
  source                      = "terraform-aws-modules/ec2-instance/aws"
  version                     = "~> 5.0"
  name                        = "elasticsearch"
  instance_type               = "t2.micro"
  iam_instance_profile        = aws_iam_instance_profile.this.name
  key_name                    = var.ssh_key_name
  associate_public_ip_address = true
  monitoring                  = true
  vpc_security_group_ids = [
    module.es_security_group.security_group_id,
    module.allow_ssh.security_group_id
  ]
  subnet_id                   = element(module.vpc.public_subnets, 0)
  user_data_replace_on_change = true
  user_data                   = <<-EOF
    #!/bin/bash
    set -ex
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    docker run -p 9200:9200 --env discovery.type=single-node elasticsearch:7.17.14 
  EOF
}

module "allow_ssh" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "allow-ssh"
  description = "Allow SSH from my home IP"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["69.172.146.231/32"]
  ingress_rules       = ["ssh-tcp"]
}

module "frontend_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "frontend"
  description = "Security group for frontend"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "all-icmp"]
  egress_rules        = ["all-all"]
}

module "backend_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "backend"
  description = "Security group for backend"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      description              = "from frontend"
      rule                     = "http-80-tcp"
      source_security_group_id = module.frontend_security_group.security_group_id
    }
  ]
  egress_rules = ["all-all"]
}

module "es_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "elasticsearch"
  description = "Security group for elasticsearch"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      description              = "from backend"
      rule                     = "http-80-tcp"
      source_security_group_id = module.backend_security_group.security_group_id
    },
    {
      from_port                = 9200
      to_port                  = 9200
      protocol                 = "tcp"
      description              = "elasticsearch from backend"
      source_security_group_id = module.backend_security_group.security_group_id
    }
  ]
  egress_rules = ["all-all"]
}

module "db_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "db_sg"
  description = "Security group for the database"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      description              = "db access"
      rule                     = "postgresql-tcp"
      source_security_group_id = module.frontend_security_group.security_group_id
    }
  ]
  egress_rules = ["all-all"]
}

module "db" {

  source = "terraform-aws-modules/rds/aws"

  identifier = "elevatedsignals"

  engine               = "postgres"
  engine_version       = "14"
  family               = "postgres14" # DB parameter group
  major_engine_version = "14"         # DB option group
  instance_class       = "db.t4g.micro"
  allocated_storage    = 5
  storage_encrypted    = true

  db_name  = "example"
  username = local.db_user
  password = "password"
  port     = "5432"
  manage_master_user_password = false

  iam_database_authentication_enabled = true

  multi_az               = false
  create_db_subnet_group = true
  subnet_ids             = module.vpc.private_subnets
  vpc_security_group_ids = [module.db_security_group.security_group_id]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  backup_retention_period = 0

  deletion_protection = false

  parameters = [
    {
      name  = "random_page_cost"
      value = "1.1"
    }
  ]
}
