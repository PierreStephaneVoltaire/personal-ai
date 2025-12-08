
data "aws_lb" "nlb" {
  tags = {
    "kubernetes.io/cluster/${data.terraform_remote_state.base.outputs.cluster_name}" = "owned"
    "kubernetes.io/service-name"           = "nginx-gateway/nginx-gateway-nginx"
  }
}

resource "aws_route53_record" "wildcard" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "*.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [data.aws_lb.nlb.dns_name]
}


data "aws_route53_zone" "main" {
  name = var.domain_name
}
