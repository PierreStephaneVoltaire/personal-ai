data "aws_lb" "nginx_gateway" {
  name = "nginx-gateway-nlb" 
}

resource "aws_route53_record" "wildcard" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "*.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [data.aws_lb.nginx_gateway.dns_name]
}


data "aws_route53_zone" "main" {
  name = var.domain_name
}
