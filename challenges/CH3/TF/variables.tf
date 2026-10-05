###############################################################################
# Challenge 3-  root module: app – network + web service
###############################################################################

variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "eu-west-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment."
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block of the VPC."
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "One public subnet per AZ. Used by the load balancer and the app instance."
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the app server."
  default     = "t3.micro"
}

variable "allowed_http_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the load balancer on HTTP port 80."
  default     = ["0.0.0.0/0"]
}
###############################################################################
