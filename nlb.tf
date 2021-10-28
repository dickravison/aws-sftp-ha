#Create NLB in public subnet
resource "aws_lb" "nlb" {
  name               = "${var.project_name}-${var.Stage}-nlb"
  load_balancer_type = "network"
  subnets            = aws_subnet.public.*.id
}

#LB Listener on port 22 for sftp forwarding to sftp target group
resource "aws_lb_listener" "sftp" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "22"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sftp.arn
  }
}

#Target group for EC2 instances in sftp ASG to register to with sticky sessions using source_ip
resource "aws_lb_target_group" "sftp" {
  name     = "${var.project_name}-${var.Stage}-tg"
  port     = 22
  protocol = "TCP"
  stickiness {
    type = "source_ip"
  }
  vpc_id = aws_vpc.main.id
}

