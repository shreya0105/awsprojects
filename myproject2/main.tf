#creating a VPC

resource aws_vpc myvpc {
    cidr_block = "10.0.0.0/16"
    tags = {
    Name = "vpcforautomation"
  }
}

#creating Internet Getway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "gatewayforint"
  }
}

#creating custom route table

resource "aws_route_table" "routetable" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "mycustomroutetable"
  }
}

#creating subnet

resource "aws_subnet" "subnetting" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "subnetting"
  }
}

#Associate subnet with route table

resource "aws_route_table_association" "Association" {
  subnet_id      = aws_subnet.subnetting.id
  route_table_id = aws_route_table.routetable.id
}

#Create security group to allow only 22,88,443 ports

resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "allow web traffic from three ports"
  vpc_id      = aws_vpc.myvpc.id
ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    description ="worldwide"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    description ="worldwide"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    description ="worldwide"
    cidr_blocks = ["0.0.0.0/0"]
  }
egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
    Name = "allow_web"
  }
}

#creating a network interface with IP in subnet that was created in step4

resource "aws_network_interface" "interface" {
  subnet_id       = aws_subnet.subnetting.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

#Assign an elastic IP so that public can access 

resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.interface.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

#create ubuntu server and install/enable apache2

resource "aws_instance" "web" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"

network_interface {
    network_interface_id = aws_network_interface.interface.id
    device_index         = 0
  }
  tags = {
    Name = "Grad Student"
  }

  user_data = <<-EOF
            #!/bin/bash
            sudo apt update -y
            sudo apt install apache2 -y
            sudo systemctl start apache2
            sudo bash -c 'echo I am a grad student at UB > /var/www/html/index.html'
            EOF
}