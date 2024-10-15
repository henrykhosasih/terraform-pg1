resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "my-vpc"
  }
}

resource "aws_subnet" "public-sub-1" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"
  tags = {
    Name = "Public Subnet 1"
  }
}

resource "aws_subnet" "private-sub-1" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "Private Subnet 1"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "public-RT" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  tags = {
    Name = "Public RT"
  }
}

resource "aws_route_table" "private-RT" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  tags = {
    Name = "Private RT"
  }
}

resource "aws_route_table_association" "public-RT-bind" {
  subnet_id      = aws_subnet.public-sub-1.id
  route_table_id = aws_route_table.public-RT.id
}

resource "aws_route_table_association" "private-RT-bind" {
  subnet_id      = aws_subnet.private-sub-1.id
  route_table_id = aws_route_table.private-RT.id
}

resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "My Security Group"
  vpc_id = aws_vpc.my-vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP from anywhere
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH only from a specific IP range
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web SG"
  }
}

resource "aws_security_group" "db" {
  name        = "db-sg"
  description = "My Security Group"
  vpc_id = aws_vpc.my-vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  tags = {
    Name = "DB SG"
  }
}

# Fetch the latest Amazon Linux 2 AMI ID
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]  # AWS-provided AMIs

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]  # Amazon Linux 2 AMI
  }
}

resource "aws_instance" "web" {
  ami = data.aws_ami.latest_amazon_linux.id
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = 0.02
      spot_instance_type = "persistent"
      instance_interruption_behavior = "stop"
    }
  }
  lifecycle {
    create_before_destroy = true
  }
  instance_type = "t3.medium"
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id = aws_subnet.public-sub-1.id
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              echo "Hello, Henry!" > /var/www/html/index.html
              systemctl start httpd
              systemctl enable httpd
              EOF
  tags = {
    Name = "Web Spot"
  }
}

