// ---------------------------- NETWORK -------------------------------------------------------

resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block

  tags = {
    Name        = "${var.project_name}-vpc-${var.environment}"
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
    Name        = "${var.project_name}-public-subnet-${count.index + 1}-${var.environment}"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_internet_gateway" "IGW" {
  tags = {
    Name        = "${var.project_name}-IGW-${var.environment}"
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
    Name        = "${var.project_name}-public-route-table-${var.environment}"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_route_table_association" "pub_route_table_assoc" {
  count          = 3
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet[count.index].id
}

// ---------------------------- ECS CLUSTER -------------------------------------------------------

resource "aws_ecs_cluster" "serverless_cluster" {
  name = "Serverless-Cluster-${var.project_name}"

  tags = {
    Name        = "${var.project_name}-ecs-cluster-${var.environment}"
    Environment = var.environment
    Owner       = var.owner
  }
}

/* - ECS_Task_Execution_Role: 
Este rol es utilizado por el agente de contenedor de ECS para ejecutar tareas. 
Permite que la tarea acceda a otros servicios de AWS necesarios para su ejecución, 
como Amazon Elastic Container Registry (ECR) para obtener imágenes de contenedor. */
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ECSTaskExecutionRole"

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
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

/* - ECS Task Role:
Este rol es utilizado por los contenedores dentro de la tarea para realizar llamadas a las APIs de AWS. 
Permite que los contenedores accedan a recursos de AWS como S3, DynamoDB, etc. */
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ECSTaskRole"

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
}

/* - ECS Task Role Policy:
Es una política de IAM que define los permisos específicos para el ecs_task_role. 
Esta política contiene las acciones permitidas y los recursos a los que el rol puede acceder. */
resource "aws_iam_policy" "ecs_task_role_policy" {
  name = "${var.project_name}-ECSTaskRole-Policy"

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
}

/* - ECS Task Role Policy Attachment:
Enlaza la política de IAM en la que se define los permisos específicos con el rol utilizado por los contenedores. */
resource "aws_iam_role_policy_attachment" "ecs_task_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_role_policy.arn
}