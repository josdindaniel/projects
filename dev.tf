# Initial configuration AWS
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

# Create VPC
resource "aws_vpc" "vpc-dev-mcp" {
  cidr_block           = "${var.cidrs_vpc[0]}"
  enable_dns_hostnames = true
  tags {
    Name = "vpc-dev-mcp"
    Env  = "dev"
  }
}

# Create subnet public 1
resource "aws_subnet" "public_subnet-dev-mcp" {
  vpc_id                  = "${aws_vpc.vpc-dev-mcp.id}"
  cidr_block              = "${var.cidrs_vpc[1]}"
  availability_zone       = "${var.az[0]}"
  map_public_ip_on_launch = true
  tags {
    Name  = "public_subnet-dev-mcp"
    Env   = "dev"
  }
}

# Create subnet public 2
resource "aws_subnet" "public_subnet2-dev-mcp" {
  vpc_id                  = "${aws_vpc.vpc-dev-mcp.id}"
  cidr_block              = "${var.cidrs_vpc[2]}"
  availability_zone       = "${var.az[1]}"
  map_public_ip_on_launch = true
  tags {
    Name  = "public_subnet2-dev-mcp"
    Env   = "dev"
  }
}

# Create internet gateway
resource "aws_internet_gateway" "igw-dev-mcp" {
  vpc_id = "${aws_vpc.vpc-dev-mcp.id}"
  tags {
    Name = "igw-dev-mcp"
    Env = "dev"
  }
}

# Create public route table
resource "aws_route_table" "public-rt-dev-mcp" {
  vpc_id = "${aws_vpc.vpc-dev-mcp.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw-dev-mcp.id}"
  }
  tags {
    Name = "public-rt-dev-mcp"
    Env = "dev"
  }
}

# Association public subnet 1 and public route table
resource "aws_route_table_association" "public-rta" {
  subnet_id      = "${aws_subnet.public_subnet-dev-mcp.id}"
  route_table_id = "${aws_route_table.public-rt-dev-mcp.id}"
}

# Association public subnet 2 and public route table
resource "aws_route_table_association" "public-rta2" {
  subnet_id      = "${aws_subnet.public_subnet2-dev-mcp.id}"
  route_table_id = "${aws_route_table.public-rt-dev-mcp.id}"
}

resource "aws_iam_role" "app-dev-role" {
  name = "app-dev-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
tags = {
    Name = "app-dev-role"
    Env = "dev"
  }
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "app_profile"
  role = "${aws_iam_role.app-dev-role.name}"
}

resource "aws_iam_role_policy" "app-dev-role_policy" {
    name = "app-dev-role_policy"
    role = "${aws_iam_role.app-dev-role.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codecommit:BatchGet*",
        "codecommit:Get*",
        "codecommit:Describe*",
        "codecommit:List*",
        "codecommit:GitPull"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchEventsCodeCommitRulesReadOnlyAccess",
      "Effect": "Allow",
      "Action": [
        "events:DescribeRule",
        "events:ListTargetsByRule"
      ],
      "Resource": "arn:aws:events:*:*:rule/codecommit*"
    },
    {
      "Sid": "SNSSubscriptionAccess",
      "Effect": "Allow",
      "Action": [
        "sns:ListTopics",
        "sns:ListSubscriptionsByTopic",
        "sns:GetTopicAttributes"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LambdaReadOnlyListAccess",
      "Effect": "Allow",
      "Action": [
        "lambda:ListFunctions"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMReadOnlyListAccess",
      "Effect": "Allow",
      "Action": [
        "iam:ListUsers"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# Create security groups instances
resource "aws_security_group" "app-sg-dev-mcp" {
  name        = "app-sg-dev-mcp"
  description = "Secure connection SSH for instances"
  vpc_id      = "${aws_vpc.vpc-dev-mcp.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3002
    to_port     = 3002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "app-sg-dev-mcp"
    Env = "dev"
  }
}

# Create security groups database
resource "aws_security_group" "db-sg-dev-mcp" {
  name        = "db-sg-dev-mcp"
  description = "Secure connection database for instances"
  vpc_id      = "${aws_vpc.vpc-dev-mcp.id}"

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    security_groups = ["${aws_security_group.app-sg-dev-mcp.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "db-sg-dev-mcp"
    Env = "dev"
  }
}

resource "aws_docdb_cluster" "docdb-dev-mcp" {
  cluster_identifier      = "my-docdb-cluster"
  engine                  = "docdb"
  master_username         = "${var.userdb}"
  master_password         = "${var.passdb}"
  backup_retention_period = 5
  preferred_backup_window = "05:00-06:00"
  skip_final_snapshot     = true
  apply_immediately = true
  availability_zones = ["${var.az[0]}", "${var.az[1]}"]
  db_subnet_group_name = "${aws_docdb_subnet_group.docdb-sg-dev-mcp.id}"
  db_cluster_parameter_group_name = "${aws_docdb_cluster_parameter_group.docdb-pg-dev-mcp.id}"
  vpc_security_group_ids = ["${aws_security_group.db-sg-dev-mcp.id}"]
  tags = {
    Name = "docdb-dev-mcp"
    Env = "dev"
  }
}

resource "aws_docdb_cluster_instance" "docdb-cluster-dev-mcp" {
  count              = 1
  identifier         = "my-docdb-cluster-${count.index}"
  cluster_identifier = "${aws_docdb_cluster.docdb-dev-mcp.id}"
  instance_class     = "db.r4.large"
  apply_immediately = true
  tags = {
    Name = "docdb-cluster-dev-mcp"
    Env = "dev"
  }
}

resource "aws_docdb_subnet_group" "docdb-sg-dev-mcp" {
  name       = "docdb-sg-dev-mcp"
  description = "docdb cluster subnet group"
  subnet_ids = ["${aws_subnet.public_subnet-dev-mcp.id}", "${aws_subnet.public_subnet2-dev-mcp.id}"]
  tags = {
    Name = "docdb-sg-dev-mcp"
    Env = "dev"
  }
}

resource "aws_docdb_cluster_parameter_group" "docdb-pg-dev-mcp" {
  family      = "docdb3.6"
  name        = "docdb-pg-dev-mcp"
  description = "docdb cluster parameter group"
  parameter {
    name  = "tls"
    value = "enabled"
  }
  tags = {
    Name = "docdb-pg-dev-mcp"
    Env = "dev"
  }
}

# Create dev instance
resource "aws_instance" "dev-mcp" {
  ami                    = "${var.ec2_info[0]}"
  instance_type          = "${var.ec2_info[1]}"
  availability_zone      = "${var.az[0]}"
  key_name               = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.app-sg-dev-mcp.id}"]
  subnet_id              = "${aws_subnet.public_subnet-dev-mcp.id}"
  iam_instance_profile   = "${aws_iam_instance_profile.app_profile.name}"
  user_data = <<EOF
		#! /bin/bash
    yum install -y git
    yum install -y gcc-c++ make
    curl -sL https://rpm.nodesource.com/setup_11.x | sudo -E bash -
    yum install -y nodejs
    git config --system credential.https://git-codecommit.us-east-1.amazonaws.com.helper '!aws codecommit credential-helper $@'
    git config --system credential.https://git-codecommit.us-east-1.amazonaws.com.UseHttpPath true
    git clone https://git-codecommit.us-east-1.amazonaws.com/v1/repos/mycloudprices /home/ec2-user/mycloudprices
    printf "module.exports = {\n    mongodb: {\n        URI: 'mongodburl'\n    }\n};" > /home/ec2-user/mycloudprices/src/keys.js
    sed -i "s+mongodburl+mongodb://${var.userdb}:${var.passdb}@${aws_docdb_cluster.docdb-dev-mcp.endpoint}:${var.port}/${var.databasename}?ssl=true&replicaSet=rs0+g" /home/ec2-user/mycloudprices/src/keys.js
    sudo chown -R ec2-user /home/ec2-user/mycloudprices/
    sudo chgrp -R ec2-user /home/ec2-user/mycloudprices/
    cd /home/ec2-user/mycloudprices
    npm run dev
	EOF
  depends_on = ["aws_docdb_cluster.docdb-dev-mcp", "aws_docdb_cluster_instance.docdb-cluster-dev-mcp"]
  tags {
    Name = "dev-mcp"
    Env = "dev"
  }
}

# Assign elastic ip to bastion host instance 1
resource "aws_eip" "ip-dev-mcp" {
  instance   = "${aws_instance.dev-mcp.id}"
  depends_on = ["aws_instance.dev-mcp"]

  tags {
    Name = "ip-dev-mcp"
    Env = "dev"
  }
}



# Output
output "arn database" {
  value = "${aws_docdb_cluster.docdb-dev-mcp.endpoint}"
}