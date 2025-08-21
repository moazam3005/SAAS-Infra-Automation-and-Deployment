data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh.tmpl")
  vars     = var.user_data_vars
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.instance_sg_id]
  iam_instance_profile        = var.iam_instance_profile
  user_data                   = data.template_file.user_data.rendered

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.env_name}-ec2"
    Environment = var.env_name
  })
}

resource "aws_lb_target_group_attachment" "attach" {
  target_group_arn = var.target_group_arn
  target_id        = aws_instance.this.id
  port             = 8080
}

output "instance_id" {
  value = aws_instance.this.id
}
