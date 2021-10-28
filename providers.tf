provider "aws" {
  profile = "default"
  region  = var.region
  default_tags {
    tags = {
      "Project Name" = var.project_name
      "Creator"      = var.creator
      "Hostname"     = var.hostname
      "Environment"  = var.Stage
    }
  }
}
