output "Environment" {
  value = var.Stage
}

output "ProjectName" {
  value = var.project_name
}

output "Creator" {
  value = var.creator
}

output "Hostname" {
  value = var.hostname
}

output "SFTPEndpoint" {
  value = aws_route53_record.sftp.fqdn
}

output "NLBHostname" {
  value = aws_lb.nlb.dns_name
}
