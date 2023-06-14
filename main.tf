provider "aws" {
  region = "us-east-1" # Change to your desired region
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0.0"
    }
    grafana = {
      source  = "grafana/grafana"
      version = ">= 1.11.0"
    }
  }
}

provider "grafana" {
  auth = "${var.grafana_username}:${var.grafana_password}"
  url  = "http://${aws_instance.grafana_instance.public_ip}:3000"
}



resource "grafana_dashboard" "example_dashboard" {
  config_json = file("./grafana.json")
  depends_on = [aws_instance.grafana_instance]
}

resource "aws_instance" "grafana_instance" {
  ami                         = "ami-04a0ae173da5807d3" # Replace with the AMI ID for Amazon Linux in your region
  instance_type               = var.instance_type
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.example_subnet.id
  vpc_security_group_ids      = [aws_security_group.example_sg.id]
  key_name                    = var.key_pair_name # Replace with your key pair name

  tags = {
    Name = "grafana-instance"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "GRAFANA_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids ${aws_instance.grafana_instance.id} --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)" >> userdata_env.txt
      echo "GRAFANA_API_KEY=${data.external.grafana_api_key.result.api_key}" >> userdata_env.txt
      envsubst < user_data_template.sh > user_data_final.sh
    EOT
  }

  user_data = filebase64("${path.module}/user_data/user_data_final.sh")
}

  data "local_file" "user_data_file" {
  filename   = "${path.module}/user_data/user_data_final.sh"
  depends_on = [aws_instance.grafana_instance]
}

data "external" "grafana_api_key" {
  program = ["bash", "${path.module}/get_grafana_api_key.sh"]
}


output "grafana_instance_public_ip" {
  value = aws_instance.grafana_instance.public_ip
}

resource "aws_vpc" "example_vpc" {
  cidr_block = var.vpc_cidr_block
}

# Create a subnet within the VPC
resource "aws_subnet" "example_subnet" {
  vpc_id                  = aws_vpc.example_vpc.id
  cidr_block              = var.subnet_cidr_block
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
}

# Create an internet gateway
resource "aws_internet_gateway" "example_igw" {
  vpc_id = aws_vpc.example_vpc.id
}

# Create a route table
resource "aws_route_table" "example_route_table" {
  vpc_id = aws_vpc.example_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example_igw.id
  }
}

# Associate the route table with the subnet
resource "aws_route_table_association" "example_association" {
  subnet_id      = aws_subnet.example_subnet.id
  route_table_id = aws_route_table.example_route_table.id
}

# Create a security group for the EC2 instances
resource "aws_security_group" "example_sg" {
  name        = var.security_group_name
  description = var.security_group_description
  vpc_id      = aws_vpc.example_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000 # Grafana port
    to_port     = 3000 # Grafana port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090 # Prometheus port
    to_port     = 9090 # Prometheus port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9100 # Node Exporter port
    to_port     = 9100 # Node Exporter port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
