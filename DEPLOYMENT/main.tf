// ---------------------------- GET SSM PARAMETERS -------------------------------------------------------

data "aws_ssm_parameter" "test_output_bucket" {
  name = "TestOutputBucket"
}

data "aws_ssm_parameter" "status_table" {
  name = "StatusTable"
}

data "aws_ssm_parameter" "test_app_domain" {
  name = "TestAppDomain"
}

data "aws_ssm_parameter" "modules_table" {
  name = "ModulesTable"
}

data "aws_ssm_parameter" "code_pipeline_artifact" {
  name = "CodePipelineArtifact"
}

data "aws_ssm_parameter" "container_image" {
  name            = "suit-container-image"
  with_decryption = false
}

data "aws_caller_identity" "current" {}

// ---------------------------- NETWORK -------------------------------------------------------

resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block

  tags = {
    Name        = "SUIT-${var.project_name}-VPC-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public_subnet" {
  count                   = 3
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "SUIT-${var.project_name}-Public-Subnet-${count.index + 1}-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }
}

resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "SUIT-${var.project_name}-IGW-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }

  tags = {
    Name        = "SUIT-${var.project_name}-Public-Route-Table-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }
}

resource "aws_route_table_association" "pub_route_table_assoc" {
  count          = 3
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet[count.index].id
}

// ---------------------------- ECS CLUSTER & IAM ROLES -------------------------------------------------------

resource "aws_ecs_cluster" "serverless_cluster" {
  name = "SUIT-${var.project_name}-Serverless-Cluster"

  tags = {
    Name        = "SUIT-${var.project_name}-Serverless-Cluster-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }
}

/* - ECS_Task_Execution_Role: 
Este rol es utilizado por el agente de contenedor de ECS para ejecutar tareas. 
Permite que la tarea acceda a otros servicios de AWS necesarios para su ejecución, 
como Amazon Elastic Container Registry (ECR) para obtener imágenes de contenedor. */
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "SUIT-${var.project_name}-ECSTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  path = "/"

  tags = {
    Name        = "SUIT-${var.project_name}-ECSTaskExecutionRole-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }

}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

/* - ECS Task Role:
Este rol es utilizado por los contenedores dentro de la tarea para realizar llamadas a las APIs de AWS. 
Permite que los contenedores accedan a recursos de AWS como S3, DynamoDB, etc. */
resource "aws_iam_role" "ecs_task_role" {
  name = "SUIT-${var.project_name}-ECSTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  path = "/"

  tags = {
    Name        = "SUIT-${var.project_name}-ECSTaskRole-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }

}

/* - ECS Task Role Policy:
Es una política de IAM que define los permisos específicos para el ecs_task_role. 
Esta política contiene las acciones permitidas y los recursos a los que el rol puede acceder. */
resource "aws_iam_policy" "ecs_task_role_policy" {
  name        = "SUIT-${var.project_name}-ECSTaskRole-Policy"
  description = "Policy for ECS Task Role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${data.aws_ssm_parameter.test_output_bucket.value}/*",
          "arn:aws:s3:::${data.aws_ssm_parameter.test_output_bucket.value}",
          "arn:aws:s3:::${data.aws_ssm_parameter.code_pipeline_artifact.value}/*",
          "arn:aws:s3:::${data.aws_ssm_parameter.code_pipeline_artifact.value}",
          "arn:aws:s3:::codepipeline-${var.aws_region}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${data.aws_ssm_parameter.status_table.value}"
      },
      {
        Effect   = "Allow"
        Action   = "states:SendTaskSuccess"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "SUIT-${var.project_name}-ECSTaskRole-Policy-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }

}

/* - ECS Task Role Policy Attachment:
Enlaza la política de IAM en la que se define los permisos específicos con el rol utilizado por los contenedores. */
resource "aws_iam_role_policy_attachment" "ecs_task_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_role_policy.arn
}

// ---------------------------- LAMBDA EXECUTION ROLES -------------------------------------------------------

resource "aws_iam_role" "lambda_execution_role" {
  name = "SUIT-${var.project_name}-LambdaExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
  path = "/"

  tags = {
    Name        = "SUIT-${var.project_name}-LambdaExecutionRole-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }

}

resource "aws_iam_role_policy_attachment" "lambda_execution_role_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_execution_role_policy" {
  name        = "SUIT-${var.project_name}-LambdaExecutionRole-Policy"
  description = "Policy for Lambda Execution Role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${data.aws_ssm_parameter.test_output_bucket.value}/*",
          "arn:aws:s3:::${data.aws_ssm_parameter.test_output_bucket.value}",
          "arn:aws:s3:::${data.aws_ssm_parameter.code_pipeline_artifact.value}/*",
          "arn:aws:s3:::${data.aws_ssm_parameter.code_pipeline_artifact.value}",
          "arn:aws:s3:::codepipeline-${var.aws_region}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${data.aws_ssm_parameter.status_table.value}"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetRepositoryPolicy",
          "ecr:SetRepositoryPolicy",
          "ecr:DeleteRepositoryPolicy",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })

  tags = {
    Name        = "SUIT-${var.project_name}-LambdaExecutionRole-Policy-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }

}

resource "aws_iam_role_policy_attachment" "lambda_execution_role_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_execution_role_policy.arn
}

// ---------------------------- UPDATE MODULES LAMBDA ROLES -------------------------------------------------------

resource "aws_iam_role" "update_modules_lambda_role" {
  name = "SUIT-${var.project_name}-UpdateModulesLambdaRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  path = "/"

  tags = {
    Name        = "SUIT-${var.project_name}-UpdateModulesLambdaRole-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }

}

resource "aws_iam_role_policy_attachment" "update_modules_lambda_role_attachment" {
  role       = aws_iam_role.update_modules_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "update_modules_lambda_role_policy" {
  name        = "SUIT-${var.project_name}-UpdateModulesLambdaRole-Policy"
  description = "Policy for UpdateModulesLambdaRole"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ]
      Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${data.aws_ssm_parameter.modules_table.value}"
    }]
  })

  tags = {
    Name        = "SUIT-${var.project_name}-UpdateModulesLambdaRole-Policy-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }

}

resource "aws_iam_role_policy_attachment" "update_modules_lambda_role_policy_attachment" {
  role       = aws_iam_role.update_modules_lambda_role.name
  policy_arn = aws_iam_policy.update_modules_lambda_role_policy.arn
}

// ---------------------------- STEP FUNCTIONS EXECUTION ROLE -------------------------------------------------------

resource "aws_iam_role" "step_functions_role" {
  name = "SUIT-${var.project_name}-SfnExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  path = "/"

  tags = {
    Name        = "SUIT-${var.project_name}-SfnExecutionRole-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }

}

resource "aws_iam_policy" "step_functions_role_policy" {
  name = "SUIT-${var.project_name}-SfnExecutionRole-Policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "lambda:InvokeFunction",
          "dynamodb:GetItem"
        ]
        Resource = [
          "${aws_ecs_task_definition.serverless_firefox_ecs_task.arn}",
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${data.aws_ssm_parameter.modules_table.value}",
          "${aws_lambda_function.serverless_chrome_stable.arn}:*",
          "${aws_lambda_function.serverless_chrome_beta.arn}:*",
          "${aws_lambda_function.serverless_chrome_video.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          "${aws_iam_role.ecs_task_role.arn}",
          "${aws_iam_role.ecs_task_execution_role.arn}"
        ]
      }
    ]
  })

  tags = {
    Name        = "SUIT-${var.project_name}-SfnExecutionRole-Policy-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }

}

resource "aws_iam_role_policy_attachment" "step_functions_policy_attachment" {
  role       = aws_iam_role.step_functions_role.name
  policy_arn = aws_iam_policy.step_functions_role_policy.arn
}

// ---------------------------- UPDATE MODULES LAMBDA FUNCTION -------------------------------------------------------

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda_function_payload_dynamodb.py"
  output_path = "lambda_function_payload_dynamodb.zip"
}

resource "aws_lambda_function" "update_modules_lambda" {
  filename      = "lambda_function_payload_dynamodb.zip"
  function_name = "SUIT-${var.project_name}-UpdateModules"
  role          = aws_iam_role.update_modules_lambda_role.arn
  handler       = "lambda_function_payload_dynamodb.lambda_handler"
  runtime       = "python3.8"
  timeout       = 90

  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = data.aws_ssm_parameter.modules_table.value
    }
  }

  tags = {
    Name        = "SUIT-${var.project_name}-UpdateModules-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }

}

// ---------------------------- UPDATE MODULES -------------------------------------------------------

locals {
  modules_payload = jsonencode({
    RequestType = "Create"
    ResourceProperties = {
      Table = data.aws_ssm_parameter.modules_table.value
      Modules = [
        {
          ModId     = { S = "mod1" }
          TestCases = { L = [{ S = "tc0001" }, { S = "tc0003" }, { S = "tc0005" }, { S = "tc0007" }] }
        },
        {
          ModId     = { S = "mod2" }
          TestCases = { L = [{ S = "tc0002" }, { S = "tc0004" }, { S = "tc0006" }] }
        },
        {
          ModId     = { S = "mod3" }
          TestCases = { L = [{ S = "tc0003" }, { S = "tc0006" }] }
        },
        {
          ModId     = { S = "mod4" }
          TestCases = { L = [{ S = "tc0001" }, { S = "tc0002" }, { S = "tc0003" }, { S = "tc0005" }] }
        },
        {
          ModId     = { S = "mod5" }
          TestCases = { L = [{ S = "tc0002" }, { S = "tc0003" }, { S = "tc0005" }, { S = "tc0007" }] }
        }
      ]
    }
  })
}

resource "null_resource" "update_modules" {
  provisioner "local-exec" {
    command     = "aws lambda invoke --function-name ${aws_lambda_function.update_modules_lambda.function_name} --payload '${local.modules_payload}' --cli-binary-format raw-in-base64-out response.json"
    interpreter = ["sh", "-c"]
  }

  triggers = {
    lambda_function = aws_lambda_function.update_modules_lambda.arn
    table_name      = data.aws_ssm_parameter.modules_table.value
  }
}


// ---------------------------- SERVERLESS FIREFOX (FARGATE & LOG GROUP) -------------------------------------------------------

resource "aws_cloudwatch_log_group" "serverless_firefox_log_group" {
  name              = "/${var.project_name}/ServerlessFirefox"
  retention_in_days = 3
}

resource "aws_ecs_task_definition" "serverless_firefox_ecs_task" {
  family                   = "suit-serverless-firefox"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "suit-serverless-firefox"
      image     = data.aws_ssm_parameter.container_image.value
      essential = true
      entryPoint = [
        "/var/lang/bin/python",
        "-c",
        "from app import container_handler; container_handler()"
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-region"        = var.aws_region
          "awslogs-group"         = aws_cloudwatch_log_group.serverless_firefox_log_group.name
          "awslogs-stream-prefix" = "suit"
        }
      }
      environment = [
        {
          name  = "BROWSER"
          value = "Firefox"
        },
        {
          name  = "WebURL"
          value = "https://master.${data.aws_ssm_parameter.test_app_domain.value}"
        },
        {
          name  = "StatusTable"
          value = data.aws_ssm_parameter.status_table.value
        },
        {
          name  = "s3buck"
          value = data.aws_ssm_parameter.test_output_bucket.value
        },
        {
          name  = "s3prefix"
          value = "${var.project_name}/"
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]
    }
  ])

  tags = {
    Name        = "SUIT-${var.project_name}-ServerlessFirefoxECSTask-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }
}

// ---------------------------- EXECUTION SECURITY GROUP -------------------------------------------------------

resource "aws_security_group" "execution_sg" {
  description = "Allow outbound access"
  vpc_id      = aws_vpc.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "SUIT-${var.project_name}-execution-sg"
    Stage = var.stage
  }

}

// ---------------------------- SERVERLESS CHROME STABLE -------------------------------------------------------

resource "aws_lambda_function" "serverless_chrome_stable" {
  function_name = "SUIT-${var.project_name}-ChromeStable"
  description   = "Lambda function to run Chrome Browser Stable and UI Tests"
  memory_size   = 1024
  package_type  = "Image"
  role          = aws_iam_role.lambda_execution_role.arn
  timeout       = 303

  image_uri = data.aws_ssm_parameter.container_image.value

  image_config {
    entry_point = [
      "/var/lang/bin/python",
      "-m",
      "awslambdaric"
    ]
    command = ["app.lambda_handler"]
  }

  environment {
    variables = {
      BROWSER         = "Chrome"
      BROWSER_VERSION = "88.0.4324.150"
      DRIVER_VERSION  = "88.0.4324.96"
    }
  }

  tags = {
    Name        = "SUIT-${var.project_name}-ChromeStable-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }
}

// ---------------------------- SERVERLESS CHROME BETA -------------------------------------------------------

resource "aws_lambda_function" "serverless_chrome_beta" {
  function_name = "SUIT-${var.project_name}-ChromeBeta"
  description   = "Lambda function to run Chrome Browser Beta and UI Tests"
  memory_size   = 1024
  package_type  = "Image"
  role          = aws_iam_role.lambda_execution_role.arn
  timeout       = 303

  image_uri = data.aws_ssm_parameter.container_image.value

  image_config {
    entry_point = [
      "/var/lang/bin/python",
      "-m",
      "awslambdaric"
    ]
    command = ["app.lambda_handler"]
  }

  environment {
    variables = {
      BROWSER         = "Chrome"
      BROWSER_VERSION = "89.0.4389.47"
      DRIVER_VERSION  = "89.0.4389.23"
    }
  }

  tags = {
    Name        = "SUIT-${var.project_name}-ChromeBeta-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }
}

// ---------------------------- SERVERLESS CHROME VIDEO -------------------------------------------------------

resource "aws_lambda_function" "serverless_chrome_video" {
  function_name = "SUIT-${var.project_name}-ChromeVideo"
  description   = "Lambda function to run Chrome Browser Stable and UI Tests and record a video"
  memory_size   = 2048
  package_type  = "Image"
  role          = aws_iam_role.lambda_execution_role.arn
  timeout       = 303

  image_uri = data.aws_ssm_parameter.container_image.value

  image_config {
    entry_point = [
      "/var/lang/bin/python",
      "-m",
      "awslambdaric"
    ]
    command = ["app.lambda_handler"]
  }

  environment {
    variables = {
      BROWSER         = "Chrome"
      BROWSER_VERSION = "88.0.4324.150"
      DRIVER_VERSION  = "88.0.4324.96"
      DISPLAY         = ":25"
    }
  }

  tags = {
    Name        = "SUIT-${var.project_name}-ChromeVideo-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }
}

// ---------------------------- AUTOMATED TESTING STATE MACHINE -------------------------------------------------------

resource "aws_sfn_state_machine" "automated_testing_state_machine" {
  name     = "SUIT-${var.project_name}-StateMachine"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = jsonencode({
    "Comment" : "SUIT State Machine",
    "StartAt" : "Get Test Cases",
    "States" : {
      "Get Test Cases" : {
        "Type" : "Task",
        "Resource" : "arn:aws:states:::dynamodb:getItem",
        "Parameters" : {
          "TableName" : "${data.aws_ssm_parameter.modules_table.value}",
          "Key.$" : "$.DDBKey"
        },
        "Next" : "Run Tests"
      },
      "Run Tests" : {
        "Type" : "Parallel",
        "Branches" : [
          {
            "StartAt" : "Test Chrome Stable",
            "States" : {
              "Test Chrome Stable" : {
                "Type" : "Map",
                "MaxConcurrency" : 0,
                "ItemsPath" : "$.Item.TestCases.L",
                "Iterator" : {
                  "StartAt" : "Chrome Stable",
                  "States" : {
                    "Chrome Stable" : {
                      "Type" : "Task",
                      "Resource" : "arn:aws:states:::lambda:invoke",
                      "Parameters" : {
                        "FunctionName" : "${aws_lambda_function.serverless_chrome_stable.arn}:$LATEST",
                        "Payload" : {
                          "tcname.$" : "$.S",
                          "module.$" : "$$.Execution.Input.DDBKey.ModId.S",
                          "testrun.$" : "$$.Execution.Id",
                          "s3buck" : "${data.aws_ssm_parameter.test_output_bucket.value}",
                          "s3prefix" : "${var.project_name}/",
                          "WebURL" : "https://master.${data.aws_ssm_parameter.test_app_domain.value}",
                          "StatusTable" : "${data.aws_ssm_parameter.status_table.value}"
                        }
                      },
                      "End" : true
                    }
                  }
                },
                "End" : true
              }
            }
          },
          {
            "StartAt" : "Test Chrome Beta",
            "States" : {
              "Test Chrome Beta" : {
                "Type" : "Map",
                "MaxConcurrency" : 0,
                "ItemsPath" : "$.Item.TestCases.L",
                "Iterator" : {
                  "StartAt" : "Chrome Beta",
                  "States" : {
                    "Chrome Beta" : {
                      "Type" : "Task",
                      "Resource" : "arn:aws:states:::lambda:invoke",
                      "Parameters" : {
                        "FunctionName" : "${aws_lambda_function.serverless_chrome_beta.arn}:$LATEST",
                        "Payload" : {
                          "tcname.$" : "$.S",
                          "module.$" : "$$.Execution.Input.DDBKey.ModId.S",
                          "testrun.$" : "$$.Execution.Id",
                          "s3buck" : "${data.aws_ssm_parameter.test_output_bucket.value}",
                          "s3prefix" : "${var.project_name}/",
                          "WebURL" : "https://master.${data.aws_ssm_parameter.test_app_domain.value}",
                          "StatusTable" : "${data.aws_ssm_parameter.status_table.value}"
                        }
                      },
                      "End" : true
                    }
                  }
                },
                "End" : true
              }
            }
          },
          {
            "StartAt" : "Chrome Video",
            "States" : {
              "Chrome Video" : {
                "Type" : "Task",
                "Resource" : "arn:aws:states:::lambda:invoke",
                "Parameters" : {
                  "FunctionName" : "${aws_lambda_function.serverless_chrome_video.arn}:$LATEST",
                  "Payload" : {
                    "tcname" : "tc0011",
                    "module" : "mod7",
                    "testrun.$" : "$$.Execution.Id",
                    "s3buck" : "${data.aws_ssm_parameter.test_output_bucket.value}",
                    "s3prefix" : "${var.project_name}/",
                    "WebURL" : "https://master.${data.aws_ssm_parameter.test_app_domain.value}",
                    "StatusTable" : "${data.aws_ssm_parameter.status_table.value}"
                  }
                },
                "End" : true
              }
            }
          },
          {
            "StartAt" : "Test Firefox Stable",
            "States" : {
              "Test Firefox Stable" : {
                "Type" : "Map",
                "MaxConcurrency" : 0,
                "ItemsPath" : "$.Item.TestCases.L",
                "Iterator" : {
                  "StartAt" : "Firefox Stable",
                  "States" : {
                    "Firefox Stable" : {
                      "Type" : "Task",
                      "Resource" : "arn:aws:states:::ecs:runTask.waitForTaskToken",
                      "Parameters" : {
                        "LaunchType" : "FARGATE",
                        "Cluster" : "${aws_ecs_cluster.serverless_cluster.arn}",
                        "TaskDefinition" : "${aws_ecs_task_definition.serverless_firefox_ecs_task.arn}",
                        "PlatformVersion" : "1.4.0",
                        "NetworkConfiguration" : {
                          "AwsvpcConfiguration" : {
                            "Subnets" : [
                              "${aws_subnet.public_subnet[0].id}",
                              "${aws_subnet.public_subnet[1].id}",
                              "${aws_subnet.public_subnet[2].id}"
                            ],
                            "AssignPublicIp" : "ENABLED"
                          }
                        },
                        "Overrides" : {
                          "ContainerOverrides" : [
                            {
                              "Name" : "suit-serverless-firefox",
                              "Environment" : [
                                {
                                  "Name" : "TASK_TOKEN_ENV_VARIABLE",
                                  "Value.$" : "$$.Task.Token"
                                },
                                {
                                  "Name" : "BROWSER_VERSION",
                                  "Value" : "86.0"
                                },
                                {
                                  "Name" : "DRIVER_VERSION",
                                  "Value" : "0.36.0"
                                },
                                {
                                  "Name" : "module",
                                  "Value.$" : "$$.Execution.Input.DDBKey.ModId.S"
                                },
                                {
                                  "Name" : "tcname",
                                  "Value.$" : "$.S"
                                },
                                {
                                  "Name" : "testrun",
                                  "Value.$" : "$$.Execution.Id"
                                }
                              ]
                            }
                          ]
                        }
                      },
                      "End" : true
                    }
                  }
                },
                "End" : true
              }
            }
          },
          {
            "StartAt" : "Test Firefox Beta",
            "States" : {
              "Test Firefox Beta" : {
                "Type" : "Map",
                "MaxConcurrency" : 0,
                "ItemsPath" : "$.Item.TestCases.L",
                "Iterator" : {
                  "StartAt" : "Firefox Beta",
                  "States" : {
                    "Firefox Beta" : {
                      "Type" : "Task",
                      "Resource" : "arn:aws:states:::ecs:runTask.waitForTaskToken",
                      "Parameters" : {
                        "LaunchType" : "FARGATE",
                        "Cluster" : "${aws_ecs_cluster.serverless_cluster.arn}",
                        "TaskDefinition" : "${aws_ecs_task_definition.serverless_firefox_ecs_task.arn}",
                        "PlatformVersion" : "1.4.0",
                        "NetworkConfiguration" : {
                          "AwsvpcConfiguration" : {
                            "Subnets" : [
                              "${aws_subnet.public_subnet[0].id}",
                              "${aws_subnet.public_subnet[1].id}",
                              "${aws_subnet.public_subnet[2].id}"
                            ]
                            "AssignPublicIp" : "ENABLED"
                          }
                        },
                        "Overrides" : {
                          "ContainerOverrides" : [
                            {
                              "Name" : "suit-serverless-firefox",
                              "Environment" : [
                                {
                                  "Name" : "TASK_TOKEN_ENV_VARIABLE",
                                  "Value.$" : "$$.Task.Token"
                                },
                                {
                                  "Name" : "BROWSER_VERSION",
                                  "Value" : "87.0b3"
                                },
                                {
                                  "Name" : "DRIVER_VERSION",
                                  "Value" : "0.36.0"
                                },
                                {
                                  "Name" : "module",
                                  "Value.$" : "$$.Execution.Input.DDBKey.ModId.S"
                                },
                                {
                                  "Name" : "tcname",
                                  "Value.$" : "$.S"
                                },
                                {
                                  "Name" : "testrun",
                                  "Value.$" : "$$.Execution.Id"
                                }
                              ]
                            }
                          ]
                        }
                      },
                      "End" : true
                    }
                  }
                },
                "End" : true
              }
            }
          },
          {
            "StartAt" : "Firefox Video",
            "States" : {
              "Firefox Video" : {
                "Type" : "Task",
                "Resource" : "arn:aws:states:::ecs:runTask.waitForTaskToken",
                "Parameters" : {
                  "LaunchType" : "FARGATE",
                  "Cluster" : "${aws_ecs_cluster.serverless_cluster.arn}",
                  "TaskDefinition" : "${aws_ecs_task_definition.serverless_firefox_ecs_task.arn}",
                  "PlatformVersion" : "1.4.0",
                  "NetworkConfiguration" : {
                    "AwsvpcConfiguration" : {
                      "Subnets" : [
                        "${aws_subnet.public_subnet[0].id}",
                        "${aws_subnet.public_subnet[1].id}",
                        "${aws_subnet.public_subnet[2].id}"
                      ]
                      "AssignPublicIp" : "ENABLED"
                    }
                  },
                  "Overrides" : {
                    "ContainerOverrides" : [
                      {
                        "Name" : "suit-serverless-firefox",
                        "Environment" : [
                          {
                            "Name" : "TASK_TOKEN_ENV_VARIABLE",
                            "Value.$" : "$$.Task.Token"
                          },
                          {
                            "Name" : "BROWSER_VERSION",
                            "Value" : "86.0"
                          },
                          {
                            "Name" : "DRIVER_VERSION",
                            "Value" : "0.36.0"
                          },
                          {
                            "Name" : "module",
                            "Value" : "mod7"
                          },
                          {
                            "Name" : "DISPLAY",
                            "Value" : ":25"
                          },
                          {
                            "Name" : "tcname",
                            "Value" : "tc0011"
                          },
                          {
                            "Name" : "testrun",
                            "Value.$" : "$$.Execution.Id"
                          }
                        ]
                      }
                    ]
                  }
                },
                "End" : true
              }
            }
          }
        ],
        "End" : true
      }
    }
  })

  tags = {
    Name        = "SUIT-${var.project_name}-StateMachine-${var.environment}"
    Environment = var.environment
    Stage       = var.stage
  }
}