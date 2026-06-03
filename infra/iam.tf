data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"] # Allows the ECS service to assume these roles.

    principals {
      type        = "Service"                 # AWS service principal type.
      identifiers = ["ecs-tasks.amazonaws.com"] # ECS task service principal.
    }
  }
}

# Execution role: used by the ECS agent to pull images and write logs.
resource "aws_iam_role" "task_execution" {
  name               = "${local.name}-task-execution"                         # IAM role name.
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json # Trust policy for ECS tasks.
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name # Role receiving the managed policy.
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" # Allows ECR pulls and CloudWatch logging.
}

# Runtime task role: credentials available inside containers. This app does not
# need AWS APIs during normal request handling, but ECS Exec uses SSM channels.
resource "aws_iam_role" "task" {
  name               = "${local.name}-task"                                   # Runtime IAM role name.
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json # Trust policy for ECS tasks.
}

data "aws_iam_policy_document" "task_runtime" {
  statement {
    sid = "AllowEfsMount" # Statement identifier.
    actions = [
      "elasticfilesystem:ClientMount", # Lets the task mount EFS.
      "elasticfilesystem:ClientWrite", # Lets the task write Convex data to EFS.
    ]
    resources = [aws_efs_file_system.convex_data.arn] # Scope EFS permissions to this filesystem.
  }

  statement {
    sid = "AllowEcsExecChannels" # Statement identifier.
    actions = [
      "ssmmessages:CreateControlChannel", # ECS Exec control channel setup.
      "ssmmessages:CreateDataChannel",    # ECS Exec data channel setup.
      "ssmmessages:OpenControlChannel",   # ECS Exec control channel connection.
      "ssmmessages:OpenDataChannel",      # ECS Exec data channel connection.
    ]
    resources = ["*"] # SSM message channel APIs do not support narrow resource ARNs here.
  }
}

resource "aws_iam_role_policy" "task_runtime" {
  name   = "${local.name}-runtime"                         # Inline policy name.
  role   = aws_iam_role.task.id                            # Runtime role receiving this policy.
  policy = data.aws_iam_policy_document.task_runtime.json   # JSON policy document above.
}
