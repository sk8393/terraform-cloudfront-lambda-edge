provider "aws" {
  region = "us-east-1"
}

resource "random_pet" "my_s3_bucket_name" {
  length    = 3
  separator = "-"
}

resource "random_pet" "my_iam_role_name" {
  length    = 3
  separator = "-"
}

resource "random_pet" "my_iam_role_policy_name" {
  length    = 3
  separator = "-"
}

resource "random_pet" "my_lambda_function_name" {
  length    = 3
  separator = "-"
}

resource "random_pet" "my_cloudfront_origin_access_control_name" {
  length    = 3
  separator = "-"
}

resource "aws_s3_bucket" "my_s3_bucket" {
  bucket = random_pet.my_s3_bucket_name.id
}

resource "aws_s3_bucket_public_access_block" "my_s3_bucket_public_access_block" {
  bucket = aws_s3_bucket.my_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "my_s3_object_index" {
  bucket       = aws_s3_bucket.my_s3_bucket.id
  content      = "Hello"
  content_type = "text/html"
  key          = "index.html"
}
resource "aws_s3_object" "my_s3_object_de_index" {
  bucket       = aws_s3_bucket.my_s3_bucket.id
  content      = "Guten Tag"
  content_type = "text/html"
  key          = "de/index.html"
}

resource "aws_s3_object" "my_s3_object_ie_index" {
  bucket       = aws_s3_bucket.my_s3_bucket.id
  content      = "La maith"
  content_type = "text/html"
  key          = "ie/index.html"
}

resource "aws_cloudfront_distribution" "my_distribution" {
  comment             = "My CloudFront Distribution"
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    forwarded_values {
      cookies {
        forward = "none"
      }
      query_string = false
    }
    target_origin_id = "S3BucketOrigin"
    viewer_protocol_policy = "redirect-to-https"
  }
  default_root_object = "index.html"
  enabled             = true
  is_ipv6_enabled     = true
  ordered_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    forwarded_values {
      cookies {
        forward = "none"
      }
      headers = ["CloudFront-Viewer-Country"]
      query_string = false
    }
    lambda_function_association {
      event_type   = "origin-request"
      include_body = false
      lambda_arn   = "${aws_lambda_function.my_lambda_function.qualified_arn}"
    }
    path_pattern     = "/index.html"
    target_origin_id = "S3BucketOrigin"
    viewer_protocol_policy = "redirect-to-https"
  }
  origin {
    domain_name              = aws_s3_bucket.my_s3_bucket.bucket_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.my_cloudfront_origin_access_control.id
    origin_id                = "S3BucketOrigin"
  }
  price_class         = "PriceClass_All"
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_s3_bucket_policy" "demo_website_bucket_policy" {
  bucket = aws_s3_bucket.my_s3_bucket.id
  policy = <<EOF
{
    "Version": "2008-10-17",
    "Id": "PolicyForCloudFrontPrivateContent",
    "Statement": [
        {
            "Sid": "AllowCloudFrontServicePrincipal",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudfront.amazonaws.com"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.my_s3_bucket.id}/*",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceArn": "${aws_cloudfront_distribution.my_distribution.arn}"
                }
            }
        }
    ]
}
EOF
}

resource "aws_cloudfront_origin_access_control" "my_cloudfront_origin_access_control" {
  name                              = random_pet.my_cloudfront_origin_access_control_name.id
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_iam_role" "my_iam_role" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
  name = random_pet.my_iam_role_name.id
}

resource "aws_iam_role_policy" "my_iam_role_policy" {
  name = random_pet.my_iam_role_policy_name.id
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
    }
  ]
}
EOF
  role = "${aws_iam_role.my_iam_role.id}"
}

data "archive_file" "lambda" {
  output_path = "index.zip"
  source_file = "index.py"
  type        = "zip"
}

resource "aws_lambda_function" "my_lambda_function" {
  filename      = "./index.zip"
  function_name = random_pet.my_lambda_function_name.id
  handler       = "index.lambda_handler"
  publish       = true
  role          = "${aws_iam_role.my_iam_role.arn}"
  runtime       = "python3.11"
  timeout       = 3
}

resource "aws_lambda_permission" "my_lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.my_lambda_function.function_name}"
  principal     = "edgelambda.amazonaws.com"
  qualifier     = "${aws_lambda_function.my_lambda_function.version}"
  statement_id  = "AllowExecutionFromCloudFront"
}
