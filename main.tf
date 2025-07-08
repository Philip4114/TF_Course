data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "dev"
  cidr = "10.0.0.0/16"
  azs             = ["us-east-1a","us-east-1b","us-east-1c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_launch_configuration" "blog" {
  name_prefix                 = "Trial_TF_Course"
  image_id                    = data.aws_ami.app_ami.id
  instance_type               = var.instance_type

  subnet_id                   = module.blog_vpc.public_subnets[0]
  security_groups             = [module.blog_sg.security_group_id]
  
  lifecycle {
    create_before_destroy     = true
  }
}

resource "aws_lb_target_group" "blog-asg" {
  name = "my-alb"
  port = 80
  protocol = "HTTP"
  vpc_id = module.blog_vpc.vpc_id
}

resource "aws_autoscaling_attachment" "blog-asg" {
  autoscaling_group_name = aws_autoscaling_group.blog-asg.id
  aws_lb_target_group_arn = aws_lb_target_group.blog-asg.arn
}

resource "aws_autoscaling_group" "blog" {
  mis_size = 1
  max_size = 3
  launch_configuration = aws_launch_configuration.blog.name
  vpc_zone_identifier = module.blog_vpc.public_subnets
}

resource "aws_lb" "blog-alb" {
  name    = "my-alb"
  internal = false
  load_balancer_type = "application"
  security_groups = [module.blog_sg.security_group_id]
  subnets = module.blog_vpc.public_subnets
}

resource "aws_lb_listener" "blog" {
  load_balancer__arn = aws_lb.blog-alb.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.blog-asg.arn
  }
}

module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.13.0"

  vpc_id              = module.blog_vpc.vpc_id
  name                = "blog"
  ingress_rules       = ["https-443-tcp","http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
}