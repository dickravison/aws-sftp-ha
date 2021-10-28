#Set local mapping for hard disk size input var
locals {
  size = {
    small  = 50
    medium = 100
    large  = 200
  }
}

#Create SG to allow SSH inbound
resource "aws_security_group" "asg" {
  name        = "Allow SSH inbound for ${var.project_name}-${var.Stage}"
  description = "Allow inbound SSH traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = var.sftp_security_group
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

#Launch template using latest Amazon Linux 2 AMI
resource "aws_launch_template" "sftp" {
  name_prefix            = "${var.project_name}-${var.Stage}-lt"
  image_id               = data.aws_ami.amazon-linux-2-ami.id
  instance_type          = var.asg_instance_type
  vpc_security_group_ids = [aws_security_group.asg.id]

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = lookup(local.size, var.HardDiskSize)
      volume_type = "gp3"
    }
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.sftp_asg.arn
  }

  user_data = base64encode(templatefile("./scripts/userdata.sh", {
    scripts_bucket = aws_s3_bucket.scripts.id
    }
  ))

}

#Autoscaling group that attaches to sftp target group, this is associated with the NLB
resource "aws_autoscaling_group" "sftp" {
  name             = "${var.project_name}-${var.Stage}-asg"
  desired_capacity = var.asg_desired
  max_size         = var.asg_max
  min_size         = var.asg_min

  launch_template {
    id      = aws_launch_template.sftp.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = "300"

  target_group_arns = [aws_lb_target_group.sftp.arn]

  vpc_zone_identifier = toset(aws_subnet.private[*].id)

  dynamic "tag" {
    for_each = data.aws_default_tags.current.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

}

#ASG policy to scale out sftp ASG
resource "aws_autoscaling_policy" "scale-out" {
  name                   = "${var.project_name}-${var.Stage}-scale-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.sftp.name
}

#CloudWatch alarm to invoke scale in ASG policy
resource "aws_cloudwatch_metric_alarm" "high-cpu" {
  alarm_name          = "${var.project_name}-${var.Stage}-high-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.sftp.name
  }

  alarm_description = "This metric monitors EC2 CPU utilization"
  alarm_actions     = [aws_autoscaling_policy.scale-out.arn]
}

#ASG policy to scale in sftp ASG
resource "aws_autoscaling_policy" "scale-in" {
  name                   = "${var.project_name}-${var.Stage}-scale-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.sftp.name
}

#CloudWatch alarm to invoke scale in ASG policy 
resource "aws_cloudwatch_metric_alarm" "low-cpu" {
  alarm_name          = "${var.project_name}-${var.Stage}-low-cpu-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.sftp.name
  }

  alarm_description = "This metric monitors EC2 CPU utilization"
  alarm_actions     = [aws_autoscaling_policy.scale-in.arn]
}

#Instance profile for sftp ASG
resource "aws_iam_instance_profile" "sftp_asg" {
  name = "${var.project_name}-${var.Stage}-asg-profile"
  role = aws_iam_role.sftp_asg.name
}

#IAM role to attach to ASG instance profile
resource "aws_iam_role" "sftp_asg" {
  name               = "${var.project_name}-${var.Stage}-asg-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.asg-assume-role-policy.json
}

#IAM policy
resource "aws_iam_policy" "sftp_policy" {
  name   = "${var.project_name}-${var.Stage}-asg-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.sftp_asg_policy.json
}

#Attach AWS Managed SSM IAM policy to IAM role
resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore-policy-attach" {
  role       = aws_iam_role.sftp_asg.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}

#Attach our IAM policy to IAM role
resource "aws_iam_role_policy_attachment" "sftp_policy" {
  role       = aws_iam_role.sftp_asg.name
  policy_arn = aws_iam_policy.sftp_policy.arn
}

#Allow EC2 to assume role
data "aws_iam_policy_document" "asg-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

#Allow access to EC2, S3 and parameter store
data "aws_iam_policy_document" "sftp_asg_policy" {
  statement {
    effect    = "Allow"
    resources = [var.existing_bucket_name != null ? "arn:aws:s3:::${var.existing_bucket_name}" : aws_s3_bucket.backend[0].arn]
    actions = [
      "s3:ListBucket"
    ]
  }

  statement {
    effect    = "Allow"
    resources = [var.existing_bucket_name != null ? "arn:aws:s3:::${var.existing_bucket_name}/*" : "${aws_s3_bucket.backend[0].arn}/*"]
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetObject",
      "s3:GetObjectAcl",
    ]
  }

  statement {
    effect    = "Allow"
    resources = [aws_s3_bucket.scripts.arn]
    actions = [
      "s3:ListBucket"
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["${aws_s3_bucket.scripts.arn}/*"]
    actions = [
      "s3:GetObject",
      "s3:GetObjectAcl",
    ]
  }

  statement {
    effect    = "Allow"
    resources = [aws_dynamodb_table.users.arn]
    actions = [
      "dynamodb:Scan",
    ]
  }
}

#Amazon Managed SSM policy
data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

