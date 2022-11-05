terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
#   region = "us-west-2"
  region = "us-east-1"
}

locals {
  region = "${data.aws_region.current.name}"
}


resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_perm" {
  name        = "ddb_access"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    },
    {
        "Action":["dynamodb:GetItem"],
        "Resource":"arn:aws:dynamodb:*:*:table/CrossRegionLatency",
        "Effect":"Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_perm.arn
}

# same region lambda
resource "aws_lambda_function" "lambda" {
  filename      = "lambda.zip"
  function_name = "same_region_lambda"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda.handler"

  source_code_hash = filebase64sha256("lambda.zip")

  runtime = "nodejs16.x"
 
  environment {
    variables = {
      DDB_REGION = "${local.region}"
    }
  }
}

resource "aws_lambda_function_url" "test_latest" {
  function_name      = aws_lambda_function.lambda.function_name
  authorization_type = "NONE"
}


#cross region lambda
resource "aws_lambda_function" "lambda_cross" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "lambda.zip"
  function_name = "cross_region_lambda"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda.handler"

  source_code_hash = filebase64sha256("lambda.zip")

  runtime = "nodejs16.x"
 
  environment {
    variables = {
      DDB_REGION = "us-east-1"
    }
  }
}

resource "aws_lambda_function_url" "cross_region_url" {
  function_name      = aws_lambda_function.lambda_cross.function_name
  authorization_type = "NONE"
}



resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name         = "CrossRegionLatency"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ID"

  attribute {
    name = "ID"
    type = "S"
  }  
}


resource "aws_cloudfront_distribution" "dist" {
  origin {
    domain_name              =  "6j4jcoo4h7op4t5ndnvblh2hrq0tjjcg.lambda-url.us-east-1.on.aws" #dont want to try to parse aws_lambda_function_url.test_latest.function_url
    custom_origin_config  {
        http_port = 80
        https_port = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols = ["TLSv1.2"]
    }
   origin_id = "default"
  }

  enabled             = true
 
  comment             = "from ${local.region} stack"
  default_root_object = "index.html"

 


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "default"

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }


  price_class = "PriceClass_100"

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  restrictions{
    geo_restriction {
      restriction_type = "blacklist"
      locations = [ "AF","GB","ZW" ]
    }
  }
}