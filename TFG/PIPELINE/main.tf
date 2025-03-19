// ---------------------------- APPROVAL TOPIC -------------------------------------------------------

resource "aws_sns_topic" "approval_topic" {
  name              = "${var.stack_name}-approval-topic"
  kms_master_key_id = "alias/aws/sns"
  display_name      = "SUIT-Approval-Notification"

  /* subscription {
    endpoint = var.approval_email
    protocol = "email"
  } */

  tags = {
    Application = var.stack_id
    Name        = "${var.stack_name}-approval-topic"
  }
}

// ---------------------------- TEST OUTPUT BUCKET (S3 BUCKET) -------------------------------------------------------


data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "test_output_bucket" {
  bucket = "${var.stack_name}-test-output-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = {
    Application = var.stack_id
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_acl" "test_output_bucket_acl" {
  bucket = aws_s3_bucket.test_output_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "test_output_bucket_versioning" {
  bucket = aws_s3_bucket.test_output_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "test_output_bucket_encryption" {
  bucket = aws_s3_bucket.test_output_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

// ---------------------------- CODE PIPELINE ARTIFACT (S3 BUCKET) -------------------------------------------------------

resource "aws_s3_bucket" "codepipeline_artifact" {
  bucket = "${var.stack_name}-codepipeline-artifact-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = {
    Application = var.stack_id
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_acl" "codepipeline_artifact_acl" {
  bucket = aws_s3_bucket.codepipeline_artifact.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "codepipeline_artifact_versioning" {
  bucket = aws_s3_bucket.codepipeline_artifact.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codepipeline_artifact_encryption" {
  bucket = aws_s3_bucket.codepipeline_artifact.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

// ---------------------------- ECR REPOSITORY -------------------------------------------------------

resource "aws_ecr_repository" "suit_repo" {
  name = "suit-${var.stack_name}-repo"

  image_tag_mutability = "MUTABLE"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_repository_policy" "suit_repo_policy" {
  repository = aws_ecr_repository.suit_repo.name

  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Sid    = "LambdaECRImageRetrievalPolicy"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "ecr:BatchGetImage",
          "ecr:DeleteRepositoryPolicy",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:SetRepositoryPolicy"
        ]
      }
    ]
  })
}

// ---------------------------- MODULES TABLE (DynamoDB Table) -------------------------------------------------------

resource "aws_dynamodb_table" "modules_table" {
  name         = "ModulesTable-${var.stack_name}"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "ModId"
    type = "S"
  }

  hash_key = "ModId"

  tags = {
    Application = var.stack_id
    Name        = "ModulesTable-${var.stack_name}"
  }
}

// ---------------------------- PARAMETERS -------------------------------------------------------

resource "aws_ssm_parameter" "modules_table_parameter" {
  name        = "ModulesTable"
  type        = "String"
  value       = aws_dynamodb_table.modules_table.name
  description = "SSM Parameter for Modules Table"
}

resource "aws_ssm_parameter" "test_output_bucket_parameter" {
  name        = "TestOutputBucket"
  type        = "String"
  value       = aws_s3_bucket.test_output_bucket.bucket
  description = "SSM Parameter for Test Output Bucket"
}

resource "aws_ssm_parameter" "codepipeline_artifact_parameter" {
  name        = "CodePipelineArtifact"
  type        = "String"
  value       = aws_s3_bucket.codepipeline_artifact.bucket
  description = "SSM Parameter for CodePipeline Artifact Bucket"
}

resource "aws_ssm_parameter" "source_repo_parameter" {
  name        = "WebAppSourceRepo"
  type        = "String"
  value       = var.repository_name
  description = "SSM Parameter for Source Repository"
}

// ---------------------------- STATUS TABLE (DynamoDB Table) -------------------------------------------------------

resource "aws_dynamodb_table" "status_table" {
  name         = "StatusTable-${var.stack_name}"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "testrunid"
    type = "S"
  }

  attribute {
    name = "testcaseid"
    type = "S"
  }

  hash_key  = "testrunid"
  range_key = "testcaseid"

  tags = {
    Application = var.stack_id
    Name        = "StatusTable-${var.stack_name}"
  }
}