#Create A record pointing to NLB
resource "aws_route53_record" "sftp" {
  zone_id = var.route53_zone_id
  name    = "${var.Stage}.${var.hostname}"
  type    = "A"

  alias {
    name                   = aws_lb.nlb.dns_name
    zone_id                = aws_lb.nlb.zone_id
    evaluate_target_health = true
  }
}
