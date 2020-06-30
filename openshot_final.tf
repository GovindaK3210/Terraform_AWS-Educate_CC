provider "aws" {
  region     = "us-east-1"
}

#VPC
resource "aws_vpc" "cli-vpc" {
    cidr_block = "10.0.0.0/16"

    tags = {
    Name = "cli-vpc"
  }
}

#Subnets
resource "aws_subnet" "cli-subnet-public-1" {
    vpc_id = "${aws_vpc.cli-vpc.id}"
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = "true" //it makes this a public subnet
    availability_zone = "us-east-1c"

    tags = {
    Name = "cli-subnet-public-1"
  }
   
}

resource "aws_subnet" "cli-subnet-public-2" {
    vpc_id = "${aws_vpc.cli-vpc.id}"
    cidr_block = "10.0.2.0/24"
    map_public_ip_on_launch = "true" //it makes this a public subnet
    availability_zone = "us-east-1e"
    
    tags = {
    Name = "cli-subnet-public-2"
  }
}

resource "aws_subnet" "cli-subnet-private-1" {
    vpc_id = "${aws_vpc.cli-vpc.id}"
    cidr_block = "10.0.3.0/24"
    availability_zone = "us-east-1c"

    tags = {
    Name = "cli-subnet-private-1"
  }
}

resource "aws_subnet" "cli-subnet-private-2" {
    vpc_id = "${aws_vpc.cli-vpc.id}"
    cidr_block = "10.0.4.0/24"
    availability_zone = "us-east-1e"

    tags = {
    Name = "cli-subnet-private-2"
  }
}

#Security Group
resource "aws_security_group" "cli-sg-1" {
  name        = "cli-sg-1"
  description = "Allow 22 and 80 from all internet inbound traffic"
  vpc_id     = "${aws_vpc.cli-vpc.id}"

  ingress {
    from_port = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
      from_port = 22
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
    Name = "cli-sg-1"
  }
}

#Internet Gateway
resource "aws_internet_gateway" "cli-igw-1" {
  vpc_id     = "${aws_vpc.cli-vpc.id}"

  tags = {
    Name = "cli-igw-1"
  }

}

#RT 
resource "aws_route_table" "public-RT-1" {
  vpc_id     = "${aws_vpc.cli-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.cli-igw-1.id}"
  }

  tags = {
    Name = "public-RT-1"
  }
}

resource "aws_route_table" "private-RT-1" {
  vpc_id     = "${aws_vpc.cli-vpc.id}"

  tags = {
    Name = "private-RT-1"
  }
}


#Associations
resource "aws_route_table_association" "public-rt-association-1" {
  subnet_id = "${aws_subnet.cli-subnet-public-1.id}"
  route_table_id = "${aws_route_table.public-RT-1.id}"
}

resource "aws_route_table_association" "public-rt-association-2" {
  subnet_id = "${aws_subnet.cli-subnet-public-2.id}"
  route_table_id = "${aws_route_table.public-RT-1.id}"
}

resource "aws_route_table_association" "private-rt-association-1" {
  subnet_id = "${aws_subnet.cli-subnet-private-1.id}"
  route_table_id = "${aws_route_table.private-RT-1.id}"
}
resource "aws_route_table_association" "private-rt-association-2" {
  subnet_id = "${aws_subnet.cli-subnet-private-2.id}"
  route_table_id = "${aws_route_table.private-RT-1.id}"
}


#----Keypair
resource "aws_key_pair" "cli-key-1" {
  key_name   = "cli-key-1"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDTm7KjSDG+STDUIprQ54GGTAxM8EY7LY+WcY1I+q5KFmNSqW+2GUuyyV2IbxlV4x5paNl/aJvN02TQxAbNjUVcnH/2fGpY8cWuThocsQQzAv1sg3ApNwyEaeKIKYM0wDJmsRv6ccNnXGx4GUVQNboytCWPXwvOyP/o8mcFrhXUi/QIbow5FRRP8jLJpKMFrJCmhC5g42k63b2Lv5htRHbagosZ+gARG6ZxUS4dh38MbHsaeGYaXRHOKDnX+0yGOp5p8lYvGqwk5xwFEd12rNmknJlVzO4boaRxpSaFqzbOf8+u7ONIU1OlZzCDV+9wRw5XqZu0y/erYhTHJxYg06wB"
}


#----Launch template
resource "aws_launch_template" "cli-template-1" {
  name = "cli-template-1"

  image_id = "ami-0323c3dd2da7fb37d"
  instance_type = "t2.micro"
  key_name = "cli-key-1"

  vpc_security_group_ids = ["${aws_security_group.cli-sg-1.id}"]

   user_data = "${base64encode(file("./data.sh"))}"
}

#Target Group 
resource "aws_lb_target_group" "cli-tg-1" {
  name     = "cli-tg-1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.cli-vpc.id}"
}

#Autoscaling group
resource "aws_autoscaling_group" "cli-asg-1" {
  desired_capacity   = 2
  max_size           = 2
  min_size           = 1
  vpc_zone_identifier = ["${aws_subnet.cli-subnet-private-1.id}", "${aws_subnet.cli-subnet-private-2.id}"]
  target_group_arns = ["${aws_lb_target_group.cli-tg-1.arn}"]

  launch_template {
    id      = "${aws_launch_template.cli-template-1.id}"
    version = "$Latest"
  }
}

# Load Balancer
resource "aws_lb" "cli-lb-1" {
  name               = "task-4-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.cli-sg-1.id}"]
  subnets            = ["${aws_subnet.cli-subnet-public-1.id}", "${aws_subnet.cli-subnet-public-2.id}"]

  tags = {
    Name = "cli-lb-1"
  }
}

#AWS Load Balancer Listner
resource "aws_lb_listener" "cli-lb-listner-1" {
  load_balancer_arn = "${aws_lb.cli-lb-1.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.cli-tg-1.arn}"
  }
}

#AWS SG for NAT instance
resource "aws_security_group" "cli-sg-nat" {
  name        = "cli-sg-nat"
  description = "cli-sg-nat"
  vpc_id     = "${aws_vpc.cli-vpc.id}"

  ingress {
    from_port = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 420
    to_port     = 420
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
    Name = "cli-sg-nat"
  }
}

#NAT
resource "aws_instance" "cli-nat" {
  ami           = "ami-00a9d4a05375b2763"
  instance_type = "t2.micro"
  source_dest_check=false
  vpc_security_group_ids = ["${aws_security_group.cli-sg-nat.id}"]
  subnet_id = "${aws_subnet.cli-subnet-public-1.id}"
  associate_public_ip_address = true

  tags = {
    Name = "cli-nat"
  }
}