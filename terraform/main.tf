terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = local.region
}

locals {
  name   = "iacdemo"
  region = "us-west-2"

  engine         = "postgres"
  engine_version = "12.8"
  family         = "postgres12"
  instance_class = "db.t2.micro"

  allocated_storage = 5
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"

  name                 = "my_vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_db_subnet_group" "my_db_subnet" {
  name       = local.name
  subnet_ids = module.vpc.public_subnets
}

resource "aws_security_group" "rds" {
  name   = local.name
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_parameter_group" "dbparams" {
  name   = local.name
  family = local.family

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "masterdb" {
  identifier = "${local.name}-master"

  engine         = local.engine
  engine_version = local.engine_version
  instance_class = local.instance_class

  allocated_storage = local.allocated_storage
  storage_encrypted = false

  username = var.dbuser
  password = var.dbpass

  db_subnet_group_name   = aws_db_subnet_group.my_db_subnet.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.dbparams.name
  publicly_accessible    = true
  skip_final_snapshot    = true
  deletion_protection    = false

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # Backups are required in order to create a replica
  backup_retention_period = 1
}

resource "aws_db_instance" "replicadb" {
  identifier          = "${local.name}-replica"
  replicate_source_db = aws_db_instance.masterdb.identifier

  engine         = local.engine
  engine_version = local.engine_version
  instance_class = local.instance_class

  storage_encrypted = false

  # Username and password should not be set for replicas
  username = null
  password = null

  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.dbparams.name
  publicly_accessible    = true
  skip_final_snapshot    = true
  deletion_protection    = false

  #  DB Backups not supported on a read replica for engine postgres
  backup_retention_period = 0
}