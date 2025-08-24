// ---------------------------- APPROVAL TOPIC -------------------------------------------------------

resource "aws_sns_topic" "approval_topic" {
  name              = "${var.project_name}-approval-topic"
  kms_master_key_id = "alias/aws/sns"
  display_name      = "SUIT-Approval-Notification"

  tags = {
    Name = "${var.project_name}-approval-topic"
  }
}

resource "aws_sns_topic_subscription" "approval_topic_subscription" {
  topic_arn = aws_sns_topic.approval_topic.arn
  protocol  = "email"
  endpoint  = var.approval_email
}

// ---------------------------- TEST OUTPUT BUCKET (S3 BUCKET) -------------------------------------------------------


data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "test_output_bucket" {
  bucket = "${var.project_name}-test-output-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = {
    Name = "${var.project_name}-test-output-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  }

  lifecycle {
    prevent_destroy = true
  }
}

/* NO NECESARIA A PARTIR DE 2023
resource "aws_s3_bucket_acl" "test_output_bucket_acl" {
  bucket = aws_s3_bucket.test_output_bucket.id
  acl    = "private"
}
*/

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
  bucket = "${var.project_name}-codepipeline-artifact-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = {
    Name = "${var.project_name}-codepipeline-artifact-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  }

  lifecycle {
    prevent_destroy = true
  }
}

/* NO NECESARIA A PARTIR DE 2023
resource "aws_s3_bucket_acl" "codepipeline_artifact_acl" {
  bucket = aws_s3_bucket.codepipeline_artifact.id
  acl    = "private"
}
*/

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
  name = "suit-${var.project_name}-repo"

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
  name         = "ModulesTable-${var.project_name}"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "ModId"
    type = "S"
  }

  hash_key = "ModId"

  tags = {
    Name = "ModulesTable-${var.project_name}"
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
  value       = var.GitHubRepo
  description = "SSM Parameter for Source Repository"
}

resource "aws_ssm_parameter" "status_table_parameter" {
  name        = "StatusTable"
  type        = "String"
  value       = aws_dynamodb_table.status_table.name
  description = "SSM Parameter for Status Table"
}

resource "aws_ssm_parameter" "TestAppDomainParameter" {
  name        = "TestAppDomain"
  type        = "String"
  value       = aws_amplify_app.TestApp.default_domain
  description = "SSM Parameter for Test App Domain"
}

resource "aws_ssm_parameter" "StatusPageDomainParameter" {
  name        = "StatusPageDomain"
  type        = "String"
  value       = aws_amplify_app.StatusPage.default_domain
  description = "SSM Parameter for Status Page Domain"
}

// ---------------------------- STATUS TABLE (DynamoDB Table) -------------------------------------------------------

resource "aws_dynamodb_table" "status_table" {
  name         = "StatusTable-${var.project_name}"
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
    Name = "StatusTable-${var.project_name}"
  }
}

// ---------------------------- COGNITO IDENTITY POOL & ROLES -------------------------------------------------------

resource "aws_cognito_identity_pool" "status_page_cognito_ip" {
  identity_pool_name               = "StatusPageCognitoIP_${var.project_name}"
  allow_unauthenticated_identities = true
}

resource "aws_iam_role" "status_page_unauth_role" {
  name = "StatusPageUnAuthRole-${var.project_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.status_page_cognito_ip.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "unauthenticated"
          }
        }
      }
    ]
  })

  path = "/"
}

resource "aws_iam_role_policy" "status_page_unauth_policy" {
  name = "StatusPageUnAuthRole-${var.project_name}-Policy"
  role = aws_iam_role.status_page_unauth_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.status_table.arn
      }
    ]
  })
}

resource "aws_cognito_identity_pool_roles_attachment" "attach_cognito_unauth_role" {
  identity_pool_id = aws_cognito_identity_pool.status_page_cognito_ip.id

  roles = {
    "unauthenticated" = aws_iam_role.status_page_unauth_role.arn
  }
}

// ---------------------------- AMPLIFY ROLES -------------------------------------------------------

resource "aws_iam_role" "AmplifyAccessRole" {
  name = "SUIT-${var.project_name}-AmplifyRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "amplify.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  path = "/"
}

resource "aws_iam_policy" "AmplifyAccessPolicy" {
  name = "SUIT-${var.project_name}-AmplifyRole-Policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/amplify/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmplifyAccessPolicyAttachment" {
  role       = aws_iam_role.AmplifyAccessRole.name
  policy_arn = aws_iam_policy.AmplifyAccessPolicy.arn
}

// ---------------------------- TEST APP (AMPLIFY) -------------------------------------------------------

resource "aws_amplify_app" "TestApp" {
  name       = "TestAppWebsite"
  repository = "https://github.com/${var.GitHubOwner}/${var.GitHubRepo}"
  oauth_token = jsondecode(data.aws_secretsmanager_secret_version.github_token.secret_string)["jcarraag_github_oauth_token"]
// data.aws_secretsmanager_secret_version.github_token.secret_string
  build_spec = jsonencode({
    version = 1
    applications = [
      {
        frontend = {
          phases = {
            build = {
              commands = []
            }
          }
          artifacts = {
            baseDirectory = "/"
            files         = ["**/*"]
          }
          cache = {
            paths = []
          }
          appRoot = "website"
        }
      }
    ]
  })
  iam_service_role_arn = aws_iam_role.AmplifyAccessRole.arn

  custom_rule {
    source = "/<*>"
    target = "/index.html"
    status = "404-200"
  }

  tags = {
    Name = "TestAppWebsite"
  }
}

resource "aws_amplify_branch" "TestAppBranch" {
  app_id            = aws_amplify_app.TestApp.id
  branch_name       = "master"
  description       = "Master branch for App"
  enable_auto_build = true
  stage             = "PRODUCTION"

  tags = {
    Name = "TestAppBranch"
  }
}



// ---------------------------- STATUS PAGE (AMPLIFY) -------------------------------------------------------

resource "aws_amplify_app" "StatusPage" {
  name       = "StatusPage"
  repository = "https://github.com/${var.GitHubOwner}/${var.GitHubRepo}"
  oauth_token = jsondecode(data.aws_secretsmanager_secret_version.github_token.secret_string)["jcarraag_github_oauth_token"]
// data.aws_secretsmanager_secret_version.github_token.secret_string
  build_spec = jsonencode({
    version = 1
    applications = [
      {
        frontend = {
          phases = {
            build = {
              commands = []
            }
          }
          artifacts = {
            baseDirectory = "/"
            files         = ["**/*"]
          }
          cache = {
            paths = []
          }
          appRoot = "status"
        }
      }
    ]
  })
  
  iam_service_role_arn = aws_iam_role.AmplifyAccessRole.arn

  custom_rule {
    source = "/<*>"
    target = "/index.html"
    status = "404-200"
  }

  tags = {
    Name = "StatusPage"
  }
}

resource "aws_amplify_branch" "StatusPageBranch" {
  app_id            = aws_amplify_app.StatusPage.id
  branch_name       = "master"
  description       = "Master branch for Status"
  enable_auto_build = true
  stage             = "PRODUCTION"

  tags = {
    Name = "StatusPageBranch"
  }
}

// ---------------------------- TERRAFORM DEPLOY ROLE -------------------------------------------------------

data "aws_region" "current" {}

resource "aws_iam_role" "TerraformDeployRole" {
  name = "${var.project_name}-TerraformDeployRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  path = "/"
}

resource "aws_iam_policy" "TerraformDeployPolicy" {
  name = "${var.project_name}-TerraformDeployRole-Policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:DeleteSubnet",
          "ec2:ReplaceRouteTableAssociation",
          "ec2:DeleteRoute",
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:DisassociateRouteTable",
          "ec2:AssociateRouteTable",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateRoute",
          "ec2:CreateInternetGateway",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateSubnet",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:ModifyVpcAttribute",
          "ec2:ModifySubnetAttribute",
          "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
          "ec2:UpdateSecurityGroupRuleDescriptionsIngress"
        ]
        Resource = "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetRole",
          "iam:GetPolicy",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:UpdateRoleDescription",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AddRoleToInstanceProfile",
          "iam:PassRole",
          "iam:CreateServiceLinkedRole",
          "iam:UpdateRole",
          "iam:DeleteServiceLinkedRole",
          "iam:GetRolePolicy",
          "iam:CreatePolicy",
          "iam:UpdateAssumeRolePolicy",
          "iam:DetachRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:DeletePolicy",
          "iam:AttachRolePolicy",
          "iam:PutRolePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:TagPolicy",
          "iam:UntagPolicy",
          "iam:TagInstanceProfile",
          "iam:UntagInstanceProfile"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:UpdateFunctionEventInvokeConfig",
          "lambda:TagResource",
          "lambda:InvokeFunction",
          "lambda:GetFunction",
          "lambda:UpdateFunctionConfiguration",
          "lambda:UntagResource",
          "lambda:UpdateFunctionCode",
          "lambda:AddPermission",
          "lambda:PutFunctionEventInvokeConfig",
          "lambda:DeleteFunctionEventInvokeConfig",
          "lambda:DeleteFunction",
          "lambda:DeleteEventSourceMapping",
          "lambda:RemovePermission",
          "lambda:GetFunctionConfiguration",
          "lambda:ListTags"
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:DeleteCluster",
          "ecs:TagResource",
          "ecs:UntagResource"
        ]
        Resource = "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/amplify/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:BatchCheckLayerAvailability",
          "ecr:TagResource",
          "ecr:UntagResource"
        ]
        Resource = aws_ecr_repository.suit_repo.arn
      },
      {
        Effect = "Allow"
        Action = [
          "states:DeleteStateMachine",
          "states:UntagResource",
          "states:TagResource",
          "states:CreateStateMachine",
          "states:UpdateStateMachine"
        ]
        Resource = "arn:aws:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "ssm:DeleteParameters",
          "ssm:AddTagsToResource",
          "ssm:RemoveTagsFromResource"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:CreateTopic",
          "sns:DeleteTopic",
          "sns:Subscribe",
          "sns:UnSubscribe",
          "sns:ListTopics"
        ]
        Resource = "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "amplify:UntagResource",
          "amplify:DeleteBranch",
          "amplify:CreateDeployment",
          "amplify:CreateBranch",
          "amplify:UpdateBranch",
          "amplify:DeleteApp",
          "amplify:ListBranches",
          "amplify:GetBranch",
          "amplify:StartDeployment",
          "amplify:CreateApp",
          "amplify:TagResource",
          "amplify:GetApp",
          "amplify:UpdateApp"
        ]
        Resource = "arn:aws:amplify:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DeleteInternetGateway",
          "ecs:CreateCluster",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupReferences",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ecs:DescribeClusters",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ssm:DescribeParameters"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "TerraformDeployRoleAttachment" {
  role       = aws_iam_role.TerraformDeployRole.name
  policy_arn = aws_iam_policy.TerraformDeployPolicy.arn
}

// ---------------------------- CODE BUILD CONTAINER ROLE -------------------------------------------------------

resource "aws_iam_role" "CodeBuildServiceRole" {
  name = "CodeBuildServiceRole-${var.project_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  path = "/"
}

resource "aws_iam_policy" "CodeBuildServicePolicy" {
  name = "CodeBuildServiceRole-${var.project_name}-Policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-test-output-${data.aws_caller_identity.current.account_id}-${var.aws_region}/*",
          "arn:aws:s3:::${var.project_name}-test-output-${data.aws_caller_identity.current.account_id}-${var.aws_region}",
          "arn:aws:s3:::${var.project_name}-codepipeline-artifact-${data.aws_caller_identity.current.account_id}-${var.aws_region}/*",
          "arn:aws:s3:::${var.project_name}-codepipeline-artifact-${data.aws_caller_identity.current.account_id}-${var.aws_region}",
          "arn:aws:s3:::codepipeline-${var.aws_region}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "amplify:StartJob"
        ]
        Resource = [
          "arn:aws:amplify:${var.aws_region}:${data.aws_caller_identity.current.account_id}:apps/${aws_amplify_app.TestApp.id}/branches/${aws_amplify_branch.TestAppBranch.branch_name}/jobs/*",
          "arn:aws:amplify:${var.aws_region}:${data.aws_caller_identity.current.account_id}:apps/${aws_amplify_app.StatusPage.id}/branches/${aws_amplify_branch.StatusPageBranch.branch_name}/jobs/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = aws_ecr_repository.suit_repo.arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole",
          "ecr:GetAuthorizationToken",
          "ssm:PutParameter"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "CodeBuildServicePolicyAttachment" {
  role       = aws_iam_role.CodeBuildServiceRole.name
  policy_arn = aws_iam_policy.CodeBuildServicePolicy.arn
}

// ---------------------------- CODE BUILD CONTAINER -------------------------------------------------------

resource "aws_codebuild_project" "BuildContainerProject" {
  name         = "SUIT-${var.project_name}-BuildContainerProject"
  description  = "Project to build containers and prepare the application"
  service_role = aws_iam_role.CodeBuildServiceRole.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    type            = "LINUX_CONTAINER"
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    privileged_mode = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.suit_repo.name
    }

    environment_variable {
      name  = "Cognito_IDP_ID"
      value = aws_cognito_identity_pool.status_page_cognito_ip.id
    }

    environment_variable {
      name  = "RepositoryName"
      value = var.GitHubRepo
    }

    environment_variable {
      name  = "DDB_STATUS_TABLE"
      value = aws_dynamodb_table.status_table.name
    }

    environment_variable {
      name  = "GITHUB_USERNAME"
      value = var.GitHubOwner
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  build_timeout = 15

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE"]
  }

  tags = {
    Name = "SUIT-${var.project_name}-BuildContainerProject"
  }
}

// ---------------------------- CODE BUILD TERRAFORM DEPLOY ROLE -----------------------------------------

resource "aws_iam_role" "TerraformCodeBuildRole" {
  name = "TerraformCodeBuildRole-${var.project_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  path = "/"
}

resource "aws_iam_policy" "TerraformCodeBuildPolicy" {
  name = "TerraformCodeBuildRole-${var.project_name}-Policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-test-output-${data.aws_caller_identity.current.account_id}-${var.aws_region}",
          "arn:aws:s3:::${var.project_name}-test-output-${data.aws_caller_identity.current.account_id}-${var.aws_region}/*",
          "arn:aws:s3:::${var.project_name}-codepipeline-artifact-${data.aws_caller_identity.current.account_id}-${var.aws_region}",
          "arn:aws:s3:::${var.project_name}-codepipeline-artifact-${data.aws_caller_identity.current.account_id}-${var.aws_region}/*",
          "arn:aws:s3:::codepipeline-${var.aws_region}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:PutParameter"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole",
          "iam:GetRole"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "TerraformCodeBuildPolicyAttachment" {
  role       = aws_iam_role.TerraformCodeBuildRole.name
  policy_arn = aws_iam_policy.TerraformCodeBuildPolicy.arn
}

// ---------------------------- CODE BUILD TERRAFORM DEPLOY ----------------------------------------------

resource "aws_codebuild_project" "TerraformDeployProject" {
  name          = "SUIT-${var.project_name}-TerraformDeploy"
  description   = "Ejecuta Terraform desde CodePipeline"
  service_role  = aws_iam_role.CodeBuildServiceRole.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "hashicorp/terraform:1.5.7" # o usa una imagen personalizada con Terraform
    type                        = "LINUX_CONTAINER"
    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "terraform-buildspec.yml"
  }

  tags = {
    Name = "SUIT-${var.project_name}-TerraformDeploy"
  }
}

// ---------------------------- CODE PIPELINE ROLE -------------------------------------------------------

resource "aws_iam_role" "CodePipelineRole" {
  name = "SUIT-CodePipelineRole-${var.project_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  path = "/"
}

resource "aws_iam_policy" "CodePipelinePolicy" {
  name = "SUIT-CodePipelineRole-${var.project_name}-Policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetBucketPolicy"
        ]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.codepipeline_artifact.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.codepipeline_artifact.bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ]
        Resource = [
          aws_codebuild_project.BuildContainerProject.arn,
          "${aws_codebuild_project.BuildContainerProject.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution",
          "states:DescribeActivity",
          "states:DescribeStateMachine",
          "states:DescribeExecution",
          "states:CreateActivity",
          "states:GetExecutionHistory",
          "states:StartExecution",
          "states:DeleteActivity",
          "states:StopExecution",
          "states:GetActivityTask"
        ]
        Resource = [
          "arn:aws:states:${var.aws_region}:${data.aws_caller_identity.current.account_id}:stateMachine:SUIT-*",
          "arn:aws:states:${var.aws_region}:${data.aws_caller_identity.current.account_id}:execution:SUIT-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.approval_topic.arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codeconnections:UseConnection"
        ]
        Resource = var.codeconnection_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "CodePipelinePolicyAttachment" {
  role       = aws_iam_role.CodePipelineRole.name
  policy_arn = aws_iam_policy.CodePipelinePolicy.arn
}

// ---------------------------- CODE PIPELINE -------------------------------------------------------

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = "jcarraag_GitHubOAuthToken"
}

resource "aws_codepipeline" "ServerlessUITestPipeline" {
  name     = "${var.project_name}-ServerlessUITestPipeline"
  role_arn = aws_iam_role.CodePipelineRole.arn

  stage {
    name = "Source"

    action {
      name             = "SUITestSource"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SUITestSourceOutput"]

      configuration = {
      ConnectionArn    = var.codeconnection_arn
      FullRepositoryId = "${var.GitHubOwner}/${var.GitHubRepo}"
      BranchName     = "master"
      DetectChanges  = "true"
      }

      run_order = 1
    }
  }

  stage {
    name = "Build"

    action {
      name             = "BuildContainer"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SUITestSourceOutput"]
      output_artifacts = ["BuildContainerArtifact"]

      configuration = {
        ProjectName = aws_codebuild_project.BuildContainerProject.name
      }

      run_order = 1
    }
  }

  stage {
    name = "Test"

    action {
      name             = "DeployTestEnv"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SUITestSourceOutput"]
      output_artifacts = ["TestEnvDeploy"]
      configuration = {
        ProjectName = aws_codebuild_project.TerraformDeployProject.name
      }

      run_order = 1
    }

    action {
      name             = "Run-Mod1-Test"
      category         = "Invoke"
      owner            = "AWS"
      provider         = "StepFunctions"
      version          = "1"
      input_artifacts  = ["TestEnvDeploy"]
      output_artifacts = ["Mod1TestOut"]

      configuration = {
        ExecutionNamePrefix = "suit"
        Input               = "{\"DDBKey\":{\"ModId\":{\"S\":\"mod1\"}}}"
        StateMachineArn     = "arn:aws:states:${var.aws_region}:${data.aws_caller_identity.current.account_id}:stateMachine:SUIT-StateMachine"
      }

      region    = var.aws_region
      run_order = 2
    }
  }

  stage {
    name = "Approval"

    action {
      name     = "DeployApproval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        NotificationArn    = aws_sns_topic.approval_topic.arn
        ExternalEntityLink = "https://${aws_amplify_branch.StatusPageBranch.branch_name}.${aws_amplify_app.StatusPage.default_domain}/?earn=#{TestVariables.ExecutionArn}"
        CustomData         = "Approve production deployment after validating the test status."
      }

      run_order = 1
    }
  }

  stage {
    name = "ProdDeploy"

    action {
      name             = "DeployProd"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "Terraform"
      version          = "1"
      input_artifacts  = ["SUITestSourceOutput"]
      output_artifacts = ["ProdDeploy"]

      configuration = {
        ActionMode   = "APPLY"
        RoleArn      = aws_iam_role.TerraformDeployRole.arn
        StackName    = "${var.project_name}-SUIT-Prod-Stack"
        TemplatePath = "SUITestSourceOutput::PROD_DEPLOY/main.tf"
      }

      region    = var.aws_region
      run_order = 1
    }
  }

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.codepipeline_artifact.bucket
  }
}