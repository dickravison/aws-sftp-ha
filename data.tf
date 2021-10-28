#Get available AZs
data "aws_availability_zones" "available" {}

#Get latest Amazon Linux 2 AMI ID
data "aws_ami" "amazon-linux-2-ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]

  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

#Get default tags
data "aws_default_tags" "current" {}
