data "aws_ami" "most_recent_ecs_optimized_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRoleSandBox"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile"
  path = "/ecs/instance/"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_security_group" "ecs_instance_sg" {
  name_prefix = "ecs-instance-sg-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 32768
    to_port   = 60999
    protocol  = "tcp"
    security_groups = [aws_security_group.nginx_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "ecs_instance" {
  ami                         = data.aws_ami.most_recent_ecs_optimized_amazon_linux.image_id
  instance_type               = "m5.large"
  subnet_id                   = aws_subnet.sub.id
  vpc_security_group_ids      = [aws_security_group.ecs_instance_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ecs_instance_profile.name
  associate_public_ip_address = false
  user_data                   = <<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
    yum install -y amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
  EOF
  tags = {
    Name = "ecs_instance"
  }
}
