# Route53 Hosted Zone
# https://www.terraform.io/docs/providers/aws/d/route53_zone.html
# 【解説】data で始まっていますが、これは読み取り専用のリソースであることを示します。
# すでにクラウド上に存在するリソースの値を参照するために使用します。
data "aws_route53_zone" "main" {
    name         = var.domain
    private_zone = false
}

# ACM
# https://www.terraform.io/docs/providers/aws/r/acm_certificate.html
# 【解説】resource は作成するリソースを定義する場所です。
resource "aws_acm_certificate" "main" {
    domain_name = var.domain

    validation_method = "DNS"

    lifecycle {
        create_before_destroy = true
    }
}

# Route53 record
# ACMによる検証用レコード
# https://www.terraform.io/docs/providers/aws/r/route53_record.html
resource "aws_route53_record" "validation" {
    depends_on = ["aws_acm_certificate.main"]

    zone_id = data.aws_route53_zone.main.id

    ttl = 60

    name    = aws_acm_certificate.main.domain_validation_options.0.resource_record_name
    type    = aws_acm_certificate.main.domain_validation_options.0.resource_record_type
    records = [aws_acm_certificate.main.domain_validation_options.0.resource_record_value]
}

# ACM Validate
# https://www.terraform.io/docs/providers/aws/r/acm_certificate_validation.html
// apply 時に SSL 証明書の検証が完了するまで待ってくれる(実際になにかのリソースを作るわけではない)
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [aws_route53_record.validation.fqdn]
}


# Route53 record
# https://www.terraform.io/docs/providers/aws/r/route53_record.html
resource "aws_route53_record" "main" {
    type = "A"

    name    = var.domain
    zone_id = data.aws_route53_zone.main.id

    alias {
        name                   = aws_lb.main.dns_name
        zone_id                = aws_lb.main.zone_id
        evaluate_target_health = true
    }
}

# ALB Listener
# https://www.terraform.io/docs/providers/aws/r/lb_listener.html
resource "aws_lb_listener" "https" {
    load_balancer_arn = aws_lb.main.arn

    certificate_arn = aws_acm_certificate.main.arn

    port     = "443"
    protocol = "HTTPS"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.main.id
    }
}

# ALB Listener Rule
# https://www.terraform.io/docs/providers/aws/r/lb_listener_rule.html
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

# Security Group Rule
# https://www.terraform.io/docs/providers/aws/r/security_group_rule.html
resource "aws_security_group_rule" "alb_https" {
    security_group_id = aws_security_group.alb.id

    type = "ingress"

    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
}
