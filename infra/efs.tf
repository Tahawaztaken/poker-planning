# Convex's default self-hosted backend stores deployment state and data under
# /convex/data. EFS makes that state survive Fargate task replacement.

resource "aws_efs_file_system" "convex_data" {
  creation_token = "${local.name}-convex-data" # Idempotency token and readable identifier.

  # encrypted=true uses the AWS-managed EFS key by default. Alternative:
  # provide kms_key_id for a customer-managed KMS key.
  encrypted = true # Encrypts stored Convex data at rest.

  # General Purpose is the default and appropriate for small interactive apps.
  # Max I/O exists for very large/highly parallel workloads but has higher
  # latency and is not needed here.
  performance_mode = "generalPurpose" # Low-latency mode for normal workloads.

  # Bursting is simplest and cost-effective for small storage footprints.
  # Alternatives: provisioned or elastic throughput for predictable/heavy IO.
  throughput_mode = "bursting" # Throughput scales with stored data size.

  dynamic "lifecycle_policy" {
    for_each = var.efs_transition_to_ia == null ? [] : [var.efs_transition_to_ia] # Adds lifecycle policy only when configured.
    content {
      transition_to_ia = lifecycle_policy.value # Moves cold files to lower-cost Infrequent Access.
    }
  }
}

resource "aws_efs_mount_target" "convex_data" {
  for_each = toset(var.private_subnet_ids) # Creates one mount target per private subnet.

  file_system_id = aws_efs_file_system.convex_data.id # EFS filesystem to expose in this subnet.
  subnet_id       = each.value                         # Subnet where this mount target is created.
  security_groups = [aws_security_group.efs.id]        # Allows NFS only from ECS tasks.
}

resource "aws_efs_access_point" "convex_data" {
  file_system_id = aws_efs_file_system.convex_data.id # Filesystem this access point belongs to.

  # Force all task file operations through this POSIX identity. This avoids
  # permission mismatches between container users.
  posix_user {
    gid = 0 # Group ID used for files accessed through this access point.
    uid = 0 # User ID used for files accessed through this access point.
  }

  root_directory {
    path = "/convex-data" # EFS directory mounted into the backend container.

    creation_info {
      owner_gid   = 0      # Group owner for the directory if AWS creates it.
      owner_uid   = 0      # User owner for the directory if AWS creates it.
      permissions = "0755" # Directory permissions if AWS creates it.
    }
  }
}
