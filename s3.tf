#S3 bucket where scripts will be kept for creating users and syncing S3, EC2 instances will pull from here.
resource "aws_s3_bucket" "scripts" {
  bucket = "${var.project_name}-${var.Stage}-scripts"
  acl    = "private"
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_object" "sync-storage" {
  bucket  = aws_s3_bucket.scripts.id
  key     = "sync-storage.sh"
  content = templatefile("./scripts/sync-storage.sh", { backend = aws_s3_bucket.backend[0].id })
  # etag makes the file update on every apply
  etag = filemd5("./scripts/sync-storage.sh")
}

resource "aws_s3_bucket_object" "create-users" {
  bucket  = aws_s3_bucket.scripts.id
  key     = "create-users.sh"
  content = templatefile("./scripts/create-users.sh", { table = aws_dynamodb_table.users.id })
  # etag makes the file update on every apply
  etag = filemd5("./scripts/create-users.sh")
}

resource "aws_s3_bucket_object" "crontab" {
  bucket = aws_s3_bucket.scripts.id
  key    = "crontab"
  source = "./scripts/crontab"
  # etag makes the file update on every apply
  etag = filemd5("./scripts/create-users.sh")
}

#S3 bucket for data transfer to be synced to
resource "aws_s3_bucket" "backend" {
  count  = var.existing_bucket_name != null ? 0 : 1
  bucket = "${var.project_name}-${var.Stage}-backend-storage"
  acl    = "private"
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
