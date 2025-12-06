
data "kubernetes_service" "nginx_gateway" {
  metadata {
    name      = "nginx-gateway-nginx"
    namespace = "nginx-gateway"
  }
}

data "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_route53_record" "cluster_wildcard" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "*.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [data.kubernetes_service.nginx_gateway.status[0].load_balancer[0].ingress[0].hostname]
}