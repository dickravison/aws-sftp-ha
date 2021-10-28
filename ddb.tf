resource "aws_dynamodb_table" "users" {
  name         = "${var.project_name}-${var.Stage}-Users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "UserName"

  attribute {
    name = "UserName"
    type = "S"
  }

}
