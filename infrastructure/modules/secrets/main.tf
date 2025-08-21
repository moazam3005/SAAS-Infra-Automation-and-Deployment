# Placeholders; values must be set by operators (outside TF state) or via rotation Lambda
resource "aws_secretsmanager_secret" "staging" {
  name = "${var.project_name}/app/staging/config"
  tags = var.tags
}

resource "aws_secretsmanager_secret" "prod" {
  name = "${var.project_name}/app/prod/config"
  tags = var.tags
}

output "staging_secret_arn" { value = aws_secretsmanager_secret.staging.arn }
output "prod_secret_arn"    { value = aws_secretsmanager_secret.prod.arn }
