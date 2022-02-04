provider "aws" {
  region = "eu-west-1"
}

locals {
  user_name = "demo-redis-user"
}

resource "aws_cloudformation_stack" "redis_user" {
  name = "redis-user"
  template_body = file("${path.module}/user.yaml")
  parameters = {
    UserName = local.user_name
  }
}

resource "aws_elasticache_user" "disabled_default_user" {
  access_string = "off ~* -@all"
  engine = "REDIS"
  no_password_required = true
  user_id = "disabled-default-user"
  user_name = "default"
}

resource "aws_elasticache_user_group" "redis_user_group" {
  engine = "REDIS"
  user_group_id = "demo-user-group"
  user_ids = [
    lookup(aws_cloudformation_stack.redis_user.outputs, "DemoRedisUserId", "default"),
    aws_elasticache_user.disabled_default_user.id
  ]
}

resource "aws_security_group" "demo-security-group" {
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 6379
    to_port = 6379
    protocol = "tcp"
  }
}

resource "aws_elasticache_replication_group" "demo-replication-group" {
  replication_group_description = "Demo Replication Group"
  replication_group_id = "demo-replication-group"
  engine = "redis"
  engine_version = "6.x"
  node_type = "cache.t3.micro"
  number_cache_clusters = 2
  automatic_failover_enabled = true
  transit_encryption_enabled = true
  security_group_ids = [aws_security_group.demo-security-group.id]
  user_group_ids = [aws_elasticache_user_group.redis_user_group.id]
}

module "lambda" {
  source = "./lambda"
  redis_user_name = local.user_name
  secret_arn = lookup(aws_cloudformation_stack.redis_user.outputs, "DemoRedisUserPasswordArn", "default")
  redis_url = aws_elasticache_replication_group.demo-replication-group.primary_endpoint_address
  redis_port = aws_elasticache_replication_group.demo-replication-group.port
}