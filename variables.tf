variable "region" {
  type        = string
  description = "AWS region to deploy in"
}

variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "creator" {
  type        = string
  description = "The name of the creator of this project"
}

variable "hostname" {
  type        = string
  description = "The hostname to use for this project"
}

variable "route53_zone_id" {
  type        = string
  description = "ID of existing Route53 zone"
}

variable "azs" {
  type        = number
  description = "Number of AZ's to create"
}

variable "Stage" {
  type        = string
  description = "Development stage"
  validation {
    condition     = contains(["latest", "test", "beta", "prod"], var.Stage)
    error_message = "Stage must be one of; latest, test, beta, prod."
  }
}

variable "existing_bucket_name" {
  type        = string
  description = "Optionally provide an existing bucket name otherwise one will be created"
  default     = null
}

variable "HardDiskSize" {
  type        = string
  description = "Size of volume for EC2 instance"
  validation {
    condition     = contains(["small", "medium", "large"], var.HardDiskSize)
    error_message = "HardDiskSize must be one of; small, medium, large."
  }
}

variable "sftp_security_group" {
  type        = list(string)
  description = "List of IPs to allow access to"
}

variable "asg_desired" {
  type        = number
  description = "Desired number of instances in ASG"
}

variable "asg_min" {
  type        = number
  description = "Minimum number of instances in ASG"
}

variable "asg_max" {
  type        = number
  description = "Maximum number of instances in ASG"
}

variable "asg_instance_type" {
  type        = string
  description = "Instance type for ASG"
}

