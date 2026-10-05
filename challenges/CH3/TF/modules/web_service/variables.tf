variable "name" {
  type        = string
  description = "Service name, prefix for every resource. Max 16 chars: ALB and target group names are limited to 32 chars by AWS."

  validation {
    condition     = length(var.name) <= 16 && can(regex("^[a-z0-9-]+$", var.name))
    error_message = "name must be at most 16 chars: lowercase letters, digits, hyphens."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC to deploy into."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Public subnets for the ALB. The app instance goes into the first one."

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "An Application Load Balancer needs at least 2 subnets in different AZs."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type."
  default     = "t3.micro"
}

variable "allowed_http_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the ALB on HTTP port 80."
  default     = ["0.0.0.0/0"]
}

variable "log_retention_days" {
  type        = number
  description = "Days before ALB access logs expire."
  default     = 30

  validation {
    condition     = var.log_retention_days >= 1
    error_message = "log_retention_days must be at least 1."
  }
}
