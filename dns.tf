resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name = "${local.cluster_name}-hosted-zone"
  }
}


resource "aws_route53domains_registered_domain" "despairdrivendevelopment" {
  domain_name = var.domain_name

  dynamic "name_server" {
    for_each = aws_route53_zone.main.name_servers
    content {
      name = name_server.value
    }
  }
}


resource "aws_route53_record" "rancher" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "rancher.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.rancher.public_ip]
}
