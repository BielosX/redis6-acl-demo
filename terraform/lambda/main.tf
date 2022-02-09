data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "allow-secrets-manager-get-value" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    effect = "Allow"
    resources = [var.secret_arn]
  }
}

resource "aws_iam_role" "lambda_role" {
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  inline_policy {
    name = "allow-secrets-manager-get-value" // Name required
    policy = data.aws_iam_policy_document.allow-secrets-manager-get-value.json
  }
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"]
}

data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

// Lambda is not able to get public IP, needs to be placed in private network with route to NAT Gateway
resource "aws_subnet" "private_subnet" {
  cidr_block = cidrsubnet(data.aws_vpc.default.cidr_block, 4, 3)
  vpc_id = data.aws_vpc.default.id
  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_eip" "nat_gateway_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id = tolist(data.aws_subnet_ids.default.ids)[0]
}

resource "aws_route_table" "private_subnet_route_table" {
  vpc_id = data.aws_vpc.default.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "private_subnet_assoc" {
  route_table_id = aws_route_table.private_subnet_route_table.id
  subnet_id = aws_subnet.private_subnet.id
}

resource "aws_security_group" "lambda_security_group" {
  vpc_id = data.aws_vpc.default.id
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port   = 0
    protocol  = "-1"
  }
}

data "aws_ecr_repository" "lambda_repo" {
  name = "redis-lambda-images"
}

resource "aws_lambda_function" "demo_function" {
  function_name = "redis-demo-lambda"
  role = aws_iam_role.lambda_role.arn
  handler = "main.handle"
  runtime = "python3.9"
  image_uri = "${data.aws_ecr_repository.lambda_repo.repository_url}:latest"
  package_type = "Image"
  timeout = 60
  memory_size = 512
  vpc_config {
    security_group_ids = [aws_security_group.lambda_security_group.id]
    subnet_ids = [aws_subnet.private_subnet.id]
  }
  environment {
    variables = {
      REDIS_URL: var.redis_url,
      REDIS_PORT: var.redis_port,
      USER_NAME: var.redis_user_name,
      SECRET_ARN: var.secret_arn
    }
  }
}