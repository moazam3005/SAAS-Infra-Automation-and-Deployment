# Instance role (read S3 artifacts + Secrets Manager + SSM)
data "aws_iam_policy_document" "instance_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.instance_trust.json
  tags = var.tags
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

data "aws_iam_policy_document" "instance_policy" {
  statement {
    sid = "S3ReadArtifacts"
    actions = ["s3:GetObject","s3:ListBucket"]
    resources = [
      var.artifact_bucket_arn,
      "${var.artifact_bucket_arn}/*"
    ]
  }
  statement {
    sid = "SecretsRead"
    actions = ["secretsmanager:GetSecretValue"]
    resources = ["*"]
  }
  statement {
    sid = "SSM"
    actions = [
      "ssm:UpdateInstanceInformation",
      "ssmmessages:*",
      "ec2messages:*",
      "cloudwatch:PutMetricData"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "instance_policy" {
  name   = "${var.project_name}-ec2-policy"
  policy = data.aws_iam_policy_document.instance_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_instance_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.instance_policy.arn
}

# GitHub OIDC provider (if not existing in account)
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Deploy role assumed by GitHub Actions
data "aws_iam_policy_document" "deploy_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [
        "repo:${var.github_org}/${var.github_repo}:*"
      ]
    }
  }
}

resource "aws_iam_role" "deploy_role" {
  name               = "${var.project_name}-github-deploy-role"
  assume_role_policy = data.aws_iam_policy_document.deploy_trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "deploy_policy" {
  statement {
    sid = "SSMRunCommand"
    actions = ["ssm:SendCommand"]
    resources = ["*"]
  }
  statement {
    sid = "S3Artifacts"
    actions = ["s3:PutObject","s3:GetObject","s3:ListBucket","s3:CopyObject"]
    resources = [
      var.artifact_bucket_arn,
      "${var.artifact_bucket_arn}/*"
    ]
  }
  statement {
    sid = "Describe"
    actions = ["ec2:DescribeInstances","elasticloadbalancing:DescribeLoadBalancers","elasticloadbalancing:DescribeTargetGroups"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deploy_policy" {
  name   = "${var.project_name}-github-deploy-policy"
  policy = data.aws_iam_policy_document.deploy_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_deploy_policy" {
  role       = aws_iam_role.deploy_role.name
  policy_arn = aws_iam_policy.deploy_policy.arn
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.ec2_profile.name
}

output "deploy_role_arn" {
  value = aws_iam_role.deploy_role.arn
}
