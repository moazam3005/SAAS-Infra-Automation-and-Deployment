resource "aws_lb" "this" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [var.alb_sg_id]
  tags = merge(var.tags, { Name = "${var.project_name}-alb" })
}

# Target groups for staging and prod
resource "aws_lb_target_group" "staging" {
  name        = "${var.project_name}-tg-staging"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/staging/health"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
  }
}

resource "aws_lb_target_group" "prod" {
  name        = "${var.project_name}-tg-prod"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/prod/health"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# Path-based routing
resource "aws_lb_listener_rule" "staging_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.staging.arn
  }

  condition {
    path_pattern {
      values = ["/staging/*"]
    }
  }
}

resource "aws_lb_listener_rule" "prod_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod.arn
  }

  condition {
    path_pattern {
      values = ["/prod/*"]
    }
  }
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "tg_staging_arn" {
  value = aws_lb_target_group.staging.arn
}

output "tg_prod_arn" {
  value = aws_lb_target_group.prod.arn
}
