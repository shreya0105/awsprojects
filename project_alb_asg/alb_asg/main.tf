#creating VPC

resource "aws_vpc" "vpcforalbasg" {
  cidr_block       = "12.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "vpcforalbasg"
  }
}

#creating internet gateway and attaching VPC

resource "aws_internet_gateway" "gatewayforalbasg" {
  vpc_id = aws_vpc.vpcforalbasg.id

  tags = {
    Name = "gatewayforalbasg"
  }
}

resource "aws_internet_gateway_attachment" "attachingvpcforalbasg" {
  internet_gateway_id = aws_internet_gateway.gatewayforalbasg.id
  vpc_id              = aws_vpc.vpcforalbasg.id
}

#Creating two public subnets in region us-east-1a and us-east-1b

resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.vpcforalbasg.id
  cidr_block        = "12.0.7.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.vpcforalbasg.id
  cidr_block        = "12.0.9.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}

#creating custom route table

resource "aws_route_table" "routetableforalbasg" {
  vpc_id = aws_vpc.vpcforalbasg.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gatewayforalbasg.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gatewayforalbasg.id
  }

  tags = {
    Name = "routetableforalbasg"
  }
}

#Associating route_table with subnets

  resource "aws_route_table_association" "subneta_association" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.routetableforalbasg.id
}

resource "aws_route_table_association" "subnetb_association" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.routetableforalbasg.id
}

#creating two ec2 instances one in each region

resource "aws_instance" "instance1foralbasg" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "test-alb-demo-key-pair"
  subnet_id  = aws_subnet.subnet_a.id

  tags = {
    Name = "instance1foralbasg"
  }
user_data = <<-EOF
#!/bin/bash
sudo apt update
sudo apt install apache2
sudo apt install php
sudo mv /var/www/html/index.html /var/www/html/index.php
vim /var/www/html/index.php
<!DOCTYPE html>
<html>
<head>
    <title>Server Details</title>
</head>
<body>
    <h1>Server Details</h1>
    <p><strong>Hostname:</strong> <?php echo gethostname(); ?></p>
    <p><strong>IP Address:</strong> <?php echo $_SERVER['SERVER_ADDR']; ?></p>
</body>
</html>
sudo systemctl status apache2
sudo systemctl restart apache2
EOF
}

resource "aws_instance" "instance2foralbasg" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t2.micro"
  availability_zone = "us-east-1b"
  key_name = "test-alb-demo-key-pair"
  subnet_id  = aws_subnet.subnet_b.id

  tags = {
    Name = "instance2foralbasg"
  }
user_data = <<-EOF
#!/bin/bash
sudo apt update
sudo apt install apache2
sudo apt install php
sudo mv /var/www/html/index.html /var/www/html/index.php
vim /var/www/html/index.php
<!DOCTYPE html>
<html>
<head>
    <title>Server Details</title>
</head>
<body>
    <h1>Server Details</h1>
    <p><strong>Hostname:</strong> <?php echo gethostname(); ?></p>
    <p><strong>IP Address:</strong> <?php echo $_SERVER['SERVER_ADDR']; ?></p>
</body>
</html>
sudo systemctl status apache2
sudo systemctl restart apache2
EOF
}

#creating target group to club two instances for our alb

resource "aws_lb_target_group" "tgroupforalbasg" {
  name     = "tf-group-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpcforalbasg.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}
# Target group attachment for instance1
resource "aws_lb_target_group_attachment" "instance1_attachment" {
  target_group_arn = aws_lb_target_group.tgroupforalbasg.arn
  target_id        = aws_instance.instance1foralbasg.id
  port             = 80
}

# Target group attachment for instance2
resource "aws_lb_target_group_attachment" "instance2_attachment" {
  target_group_arn = aws_lb_target_group.tgroupforalbasg.arn
  target_id        = aws_instance.instance2foralbasg.id
  port             = 80
}

#creating security group to be included in load balancer

resource "aws_security_group" "albasg_sg" {
  name        = "albasg_securitygroup"
  description = "Security group for ALB"
  vpc_id  = "vpc-076748484ab89f549"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks  = ["::/0"]
  }
}

#creating loadbalancer

resource "aws_lb" "albasg" {
  name               = "loadbalancerforalbasg"
  internal           = false
  load_balancer_type = "application"
  
  security_groups    = [aws_security_group.albasg_sg.id]
  
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
tags = {
    "InternetFacing" = "true"
}

}

# Attach target group to ALB
resource "aws_lb_target_group_attachment" "tgroupattachalb" {
  target_group_arn = aws_lb_target_group.tgroupforalbasg.arn
  target_id        = aws_instance.instance1foralbasg.id 
  port             = 80
}

resource "aws_lb_target_group_attachment" "targetgroupattachalb" {
  target_group_arn = aws_lb_target_group.tgroupforalbasg.arn
  target_id        = aws_instance.instance2foralbasg.id 
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.albasg.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tgroupforalbasg.arn
  }
}

#creating launch template for my ASG
resource "aws_launch_template" "first-template" {
  # Name of the launch template
  name          = "first-template"

  # ID of the Amazon Machine Image (AMI) to use for the instance
  image_id      = "ami-0c7217cdde317cfec"

  # Instance type for the EC2 instance
  instance_type = "t2.micro"

  # SSH key pair name for connecting to the instance
  key_name = "test-alb-demo-key-pair"

  # Block device mappings for the instance
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      # Size of the EBS volume in GB
      volume_size = 20

      # Type of EBS volume (General Purpose SSD in this case)
      volume_type = "gp2"
    }
  }

  # Network interface configuration
  network_interfaces {
    # Associates a public IP address with the instance
    associate_public_ip_address = true

    # Security groups to associate with the instance
    security_groups = ["sg-0c70135b6036c9f0b","sg-00cc4ebc1f0cca06a"]
  }

  # Tag specifications for the instance
  tag_specifications {
    # Specifies the resource type as "instance"
    resource_type = "instance"

    # Tags to apply to the instance
    tags = {
      Name = "first template"
    }
  }
}
#creating auto-scaling group

resource "aws_autoscaling_group" "asgforalbasg" {
  name                      = "asgforalbasg"
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = true
  vpc_zone_identifier       = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  instance_maintenance_policy {
    min_healthy_percentage = 90
    max_healthy_percentage = 120
  }
  launch_template {
    id      = aws_launch_template.first-template.id
    version = "$Latest"
  }
}