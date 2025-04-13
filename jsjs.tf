###############################################################################
# PROVIDER
###############################################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.1.0"
}

provider "aws" {
  region = "us-east-1"
}

###############################################################################
# VPC
###############################################################################
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.10.0.0/20"
  tags = {
    Name = "MainVPC"
  }
}

###############################################################################
# INTERNET GATEWAY
###############################################################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "MainIGW"
  }
}

###############################################################################
# SUBNET PÚBLICA
###############################################################################
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.10.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "PublicSubnet"
  }
}

###############################################################################
# ROUTE TABLE Y ASOCIACIÓN
###############################################################################
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table_association" "public_subnet_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

###############################################################################
# SECURITY GROUPS
###############################################################################
# SG para el Jump Server (bastión SSH)
resource "aws_security_group" "jump_sg" {
  name        = "jump_sg"
  description = "Permite SSH desde Internet"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "SSH desde cualquier IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jump-sg"
  }
}

# SG para los Web Servers (solo Linux)
resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Permite HTTP desde Internet y SSH solo desde Jump SG"
  vpc_id      = aws_vpc.main_vpc.id

  # Permite HTTP desde cualquier IP
  ingress {
    description = "HTTP desde cualquier IP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permite SSH solo desde el Security Group del Jump Server
  ingress {
    description     = "SSH desde Jump"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jump_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

###########################################
# KEY PAIR
###########################################
# Asegúrate de tener el archivo de llave pública en la ruta especificada
resource "aws_key_pair" "my_key" {
  key_name   = "my_key"
  public_key = file("~/.ssh/id_rsa.pub")
}

############################################
# INSTANCIAS
############################################
# 1 Servidor Jump (bastión SSH)
resource "aws_instance" "jump_server" {
  ami                    = "ami-0c55b159cbfafe1f0"  # AMI Linux (Amazon Linux 2, ajusta según tu región)
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.jump_sg.id]
  key_name               = aws_key_pair.my_key.key_name

  tags = {
    Name = "JumpServer"
  }
}

# 3 Servidores Web Linux
resource "aws_instance" "web_server" {
  count                  = 3
  ami                    = "ami-0c55b159cbfafe1f0"  # AMI Linux (Amazon Linux 2, ajusta según tu región)
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.my_key.key_name

  tags = {
    Name = "WebServer-${count.index + 1}"
  }
}

###############################################################################
# OUTPUTS (Opcional, para visualizar IPs)
###############################################################################
output "jump_server_public_ip" {
  description = "Dirección IP pública del Jump Server"
  value       = aws_instance.jump_server.public_ip
}

output "web_servers_public_ips" {
  description = "Direcciones IP públicas de los Web Servers"
  value       = [for instance in aws_instance.web_server : instance.public_ip]
}
