/*** submodule: web_service ***/
# ALB (HTTP :80) -> EC2 (nginx) with ALB access logs in S3, an IAM instance role
# and a generated DB password stored in SSM Parameter Store.
#
# AWS naming limits that matter here:
#   ALB name / target group name : max 32 chars, letters, digits, hyphens
#   S3 bucket name               : 3-63 chars, lowercase letters, digits, hyphens, dots

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

resource "random_string" "suffix" {
  length      = 6
  upper       = false
  min_special = 1
}

locals {
  suffix      = random_string.suffix.result
  alb_name    = "${var.name}-alb-${local.suffix}"      # e.g. dev-app-alb-k3x9p2
  tg_name     = "${var.name}-tg-${local.suffix}"       # e.g. dev-app-tg-k3x9p2
  bucket_name = "${var.name}-alb-logs-${local.suffix}" # e.g. dev-app-alb-logs-k3x9p2
}

# ---------------- Secrets ----------------

resource "random_password" "db" {
  length           = 24
  override_special = "!#%*-_=+"
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.name}/db-password"
  description = "Database password for ${var.name}"
  type        = "SecureString"
  value       = random_password.db.result
}

# ---------------- IAM ----------------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "read_db_password" {
  statement {
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.db_password.arn]
  }
}

resource "aws_iam_role_policy" "read_db_password" {
  name   = "read-db-password"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.read_db_password.json
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.app.name
}

# ---------------- Security groups ----------------

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "HTTP from allowed CIDRs to the ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-alb-sg"
  }
}

resource "aws_security_group" "app" {
  name        = "${var.name}-ec2-sg"
  description = "HTTP from the ALB to the app instance"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-ec2-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = toset(var.allowed_http_cidrs)

  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------------- App instance ----------------

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name

  metadata_options {
    http_tokens = "required"
  }

  user_data                   = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    echo "<h1>${var.name}</h1><p>Served by $(hostname -f)</p>" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOF
  user_data_replace_on_change = true

  tags = {
    Name = "${var.name}-ec2"
  }

  lifecycle {
    ignore_changes = [ami] # a newer AMI must not replace the instance on every plan
  }
}

# ---------------- ALB access logs bucket ----------------

resource "aws_s3_bucket" "alb_logs" {
  bucket        = local.bucket_name
  force_destroy = true # logs are disposable in this lab
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.log_retention_days
    }
  }
}

# Regional ELB account that writes the logs (valid for regions older than Aug 2022, e.g. eu-west-1)
data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "alb_logs" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.alb_logs.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json
}

# ---------------- Load balancer ----------------

resource "aws_lb" "app" {
  name               = local.alb_name
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }

  # AWS checks the bucket policy when the ALB is created
  depends_on = [aws_s3_bucket_policy.alb_logs]
}

resource "aws_lb_target_group" "app" {
  name        = local.tg_name
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path    = "/"
    matcher = "200"
  }
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = 80
}

# ---------------- Listener ----------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
