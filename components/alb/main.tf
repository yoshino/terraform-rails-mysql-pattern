# SecurityGroup
# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group" "alb" {
    name        = "${var.prefix}-alb"
    description = "${var.prefix} alb"
    vpc_id      = var.vpc_id

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.prefix}-alb"
    }
}

# SecurityGroup Rule
# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group_rule" "alb_http" {
    security_group_id = aws_security_group.alb.id

    type = "ingress"

    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_https" {
    security_group_id = aws_security_group.alb.id

    type = "ingress"

    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
}

# ALB
# https://www.terraform.io/docs/providers/aws/d/lb.html
resource "aws_lb" "main" {
    load_balancer_type = "application"
    name               = var.prefix

    security_groups = [aws_security_group.alb.id]
    subnets         = var.public_subnet_ids
}

# ELB Target Group
# https://www.terraform.io/docs/providers/aws/r/lb_target_group.html
resource "aws_lb_target_group" "main" {
	name = var.prefix

	vpc_id = var.vpc_id

	port        = 8080
	protocol    = "HTTP"
	target_type = "ip"

	health_check {
		port = 8080
		path = "/"
	}
}

# Listener
# https://www.terraform.io/docs/providers/aws/r/lb_listener.html
resource "aws_lb_listener" "main" {
    port              = "80"
    protocol          = "HTTP"

    load_balancer_arn = aws_lb.main.arn

    default_action {
        type             = "fixed-response"

        fixed_response {
            content_type = "text/plain"
            status_code  = "200"
            message_body = "ok"
        }
    }
}

resource "aws_lb_listener" "https" {
    load_balancer_arn = aws_lb.main.arn

    certificate_arn = var.acm_certificate_main_arn

    port     = "443"
    protocol = "HTTPS"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.main.id
    }
}

# ALB Listener Rule
# https://www.terraform.io/docs/providers/aws/r/lb_listener_rule.html
resource "aws_lb_listener_rule" "main" {
	listener_arn = aws_lb_listener.main.arn

	action {
		type             = "forward"
		target_group_arn = aws_lb_target_group.main.id
	}

	condition {
		path_pattern {
		  values = ["*"]
        }
	}
}

resource "aws_lb_listener_rule" "http_to_https" {
    listener_arn = aws_lb_listener.main.arn

    priority = 99

    action {
        type = "redirect"

        redirect {
            port        = "443"
            protocol    = "HTTPS"
            status_code = "HTTP_301"
        }
    }

    condition {
        field  = "host-header"
        values = [var.domain]
    }
}
