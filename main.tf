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

# AutoScaling
module "blog_as" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "9.0.1"

  name     = "blog-asg"
  min_size = 1
  max_size = 2

  vpc_zone_identifier = module.blog_vpc.public_subnets
  security_groups     = [module.blog_sg.security_group_id]

  image_id      = data.aws_ami.app_ami.id
  instance_type = var.instance_type

  traffic_source_attachments = {
    asg_to_alb = {
      traffic_source_identifier = module.blog_alb.target_groups["asg_tg"].arn
    }
  }
}

# Application Load Balancer
module "blog_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.17.0"

  name    = "blog-alb"
  vpc_id  = module.blog_vpc.vpc_id
  subnets = module.blog_vpc.public_subnets

  # Security Group
  security_groups = [module.blog_sg.security_group_id]

  access_logs = {
    bucket = "blog-alb-logs"
  }

  target_groups = {
    asg_tg = {
      name_prefix       = "blog-"
      protocol          = "HTTP"
      port              = 80
      target_type       = "instance"
      create_attachment = false # Important for ASG attachment
    }
  }

  listeners = [
    {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "asg_tg"
      }
    }
  ]

  tags = {
    Environment = "dev"
  }
}

# Virtual Private Cloud
module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs            = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Security Group
module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"
  name    = "blog_new"

  vpc_id = module.blog_vpc.vpc_id

  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}
