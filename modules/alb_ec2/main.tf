resource "aws_lb" "this" {
  name               = "devops-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "gitlab" {
  name     = "gitlab-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group" "jenkins" {
  name     = "jenkins-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group_attachment" "gitlab" {
  target_group_arn = aws_lb_target_group.gitlab.arn
  target_id        = var.gitlab_instance_id
  port             = 80
}

resource "aws_lb_target_group_attachment" "jenkins" {
  target_group_arn = aws_lb_target_group.jenkins.arn
  target_id        = var.jenkins_instance_id
  port             = 8080
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type = "fixed-response"

    fixed_response {
      status_code  = "404"
      content_type = "text/plain"
      message_body = "Not Found"
    }
  }
}

resource "aws_lb_listener_rule" "gitlab" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  condition {
    host_header {
      values = ["gitlab.${var.domain_name}"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gitlab.arn
  }
}

resource "aws_lb_listener_rule" "jenkins" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  condition {
    host_header {
      values = ["jenkins.${var.domain_name}"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }
}


