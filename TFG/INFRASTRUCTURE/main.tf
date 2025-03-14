// ---------------------------- NETWORK -------------------------------------------------------

resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block

  tags = {
    Name        = "SUIT-${var.project_name}-VPC-${var.environment}"
    Environment = var.environment
    Owner       = var.owner
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
    Owner       = var.owner
  }
}

resource "aws_internet_gateway" "IGW" {
  tags = {
    Name        = "SUIT-${var.project_name}-IGW-${var.environment}"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_internet_gateway_attachment" "IGW_att" {
  internet_gateway_id = aws_internet_gateway.IGW.id
  vpc_id              = aws_vpc.vpc.id
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
    Owner       = var.owner
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
    Owner       = var.owner
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
    Owner       = var.owner
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
    Owner       = var.owner
  }

}

/* - ECS Task Role Policy:
Es una política de IAM que define los permisos específicos para el ecs_task_role. 
Esta política contiene las acciones permitidas y los recursos a los que el rol puede acceder. */
resource "aws_iam_policy" "ecs_task_role_policy" {
  name = "SUIT-${var.project_name}-ECSTaskRole-Policy"
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
          "arn:aws:s3:::${var.test_output_bucket}/*",
          "arn:aws:s3:::${var.test_output_bucket}",
          "arn:aws:s3:::${var.code_pipeline_artifact}/*",
          "arn:aws:s3:::${var.code_pipeline_artifact}",
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
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.status_table}"
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
    Owner       = var.owner
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
    Owner       = var.owner
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
          "arn:aws:s3:::${var.test_output_bucket}/*",
          "arn:aws:s3:::${var.test_output_bucket}",
          "arn:aws:s3:::${var.code_pipeline_artifact}/*",
          "arn:aws:s3:::${var.code_pipeline_artifact}",
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
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.status_table}"
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
    Owner       = var.owner
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
    Owner       = var.owner
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
      Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.modules_table}"
    }]
  })

  tags = {
    Name        = "SUIT-${var.project_name}-UpdateModulesLambdaRole-Policy-${var.environment}"
    Environment = var.environment
    Owner       = var.owner
  }

}

resource "aws_iam_role_policy_attachment" "update_modules_lambda_role_policy_attachment" {
  role       = aws_iam_role.update_modules_lambda_role.name
  policy_arn = aws_iam_policy.update_modules_lambda_role_policy.arn
}

// ---------------------------- STEP FUNCTIONS EXECUTION ROLE -------------------------------------------------------

resource "aws_iam_role" "step_functions_role" {
  name = "SUIT-${var.project_name}-SfnExecutionRole"

  assume_role_policy = jsondecode({
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
    Owner       = var.owner
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
          aws_ecs_task_definition.serverless_firefox_ecs_task.arn,
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.modules_table}",
          "${aws_lambda_function.serverless_chrome_stable.arn}:*",
          "${aws_lambda_function.serverless_chrome_beta.arn}:*",
          "${aws_lambda_function.serverless_chrome_video.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.ecs_task_role.arn,
          aws_iam_role.ecs_task_execution_role.arn
        ]
      }
    ]
  })

  tags = {
    Name        = "SUIT-${var.project_name}-SfnExecutionRole-Policy-${var.environment}"
    Environment = var.environment
    Owner       = var.owner
  }

}

// ---------------------------- UPDATE MODULES LAMBDA FUNCTION -------------------------------------------------------

data "archive_file" "lambda" {
  type = "zip"
  source_file = "lambda_function_payload.py"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "update_modules_lambda" {
  filename         = "lambda_function_payload.zip"
  function_name    = "SUIT-${var.project_name}-UpdateModules"
  role             = aws_iam_role.update_modules_lambda_role.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.8"
  timeout          = 90

  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = var.modules_table
    }
  }

  tags = {
    Name        = "SUIT-${var.project_name}-UpdateModules-${var.environment}"
    Environment = var.environment
    Owner       = var.owner
  }

}

// ---------------------------- UPDATE MODULES -------------------------------------------------------

resource "null_resource" "update_modules" {
  triggers = {
    service_token = aws_lambda_function.update_modules_lambda.arn
    table         = aws_dynamodb_table.modules_table.name
    modules       = jsonencode([
      {
        ModId     = "mod1"
        TestCases = ["tc0001", "tc0003", "tc0005", "tc0007"]
      },
      {
        ModId     = "mod2"
        TestCases = ["tc0002", "tc0004", "tc0006"]
      },
      {
        ModId     = "mod3"
        TestCases = ["tc0003", "tc0006"]
      },
      {
        ModId     = "mod4"
        TestCases = ["tc0001", "tc0002", "tc0003", "tc0005"]
      },
      {
        ModId     = "mod5"
        TestCases = ["tc0002", "tc0003", "tc0005", "tc0007"]
      }
    ])
  }

  provisioner "local-exec" {
    command = <<EOT
      aws lambda invoke --function-name ${self.triggers.service_token} --payload '{
        "Table": "${self.triggers.table}",
        "Modules": ${self.triggers.modules}
      }' response.json
    EOT
  }
}

// ---------------------------- SERVERLESS FIREFOX (FARGATE & LOG GROUP) -------------------------------------------------------

resource "aws_cloudwatch_log_group" "serverless_firefox_log_group" {
  name = "/${var.project_name}/ServerlessFirefox"
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
      image     = var.container_name
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
          value = "https://master.${var.test_app_domain}"
        },
        {
          name  = "StatusTable"
          value = var.status_table
        },
        {
          name  = "s3buck"
          value = var.test_output_bucket
        },
        {
          name  = "s3prefix"
          value = "${var.stack_name}/"
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]
    }
  ])

  tags = {
    Application = var.stack_id
    Name        = "SUIT-${var.project_name}-ServerlessFirefoxECSTask-${var.environment}"
    Environment = var.environment
    Owner       = var.owner
  }
}

// ---------------------------- EXECUTION SECURITY GROUP -------------------------------------------------------

resource "aws_security_group" "execution_sg" {
  description = "Allow outbound access"
  vpc_id = aws_vpc.vpc.id

  egress {
    protocol = "-1"
    cidr_blocks = "0.0.0.0/0"
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

  image_uri = var.container_name

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
    Application = var.stack_id
    Name        = "SUIT-${var.project_name}-ChromeStable-${var.environment}"
    Environment = var.environment
    Owner       = var.owner
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

  image_uri = var.container_name

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
    Application = var.stack_id
    Name        = "SUIT-${var.project_name}-ChromeBeta-${var.environment}"
    Environment = var.environment
    Owner       = var.owner
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

  image_uri = var.container_name

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
      DISPLAY = ":25"
    }
  }

  tags = {
    Application = var.stack_id
    Name        = "SUIT-${var.project_name}-ChromeVideo-${var.environment}"
    Environment = var.environment
    Owner       = var.owner
  }
}

// ---------------------------- AUTOMATED TESTING STATE MACHINE -------------------------------------------------------
