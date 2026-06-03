# AWS Terraform Deployment

This folder deploys AgileKit to ECS Fargate behind an existing ALB. The public
route shape is:

```text
https://<domain>/scrum
https://<domain>/scrum/api
https://<domain>/scrum/site
```

Terraform creates the app-specific resources: ECR repositories, ECS cluster,
task definition, service, security groups, EFS storage, CloudWatch logs, ALB
target group, and ALB listener rule.

It assumes you already have:

- VPC and private subnets.
- An internet-facing ALB.
- An HTTPS listener with an ACM certificate.
- DNS pointing at that ALB.

## Why Caddy Has Its Own Image

Local Docker Compose mounts `./Caddyfile` into the public `caddy:2` image:

```yaml
./Caddyfile:/etc/caddy/Caddyfile:ro
```

ECS/Fargate does not have this repository folder available to mount. Instead,
`infra/aws-caddy/Dockerfile` starts from `caddy:2` and copies the AWS Caddyfile
into the image at build time:

```dockerfile
FROM caddy:2
COPY Caddyfile /etc/caddy/Caddyfile
```

That is what "baking in the Caddyfile" means.

## First Terraform Apply: Create ECR Repositories

Copy the example variables:

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

Fill in the existing VPC, subnet, ALB listener, ALB security group, and domain
values.

Initialize Terraform:

```bash
terraform init
```

For a first run, the image variables can be temporary placeholders only if you
do not apply the ECS service yet. The simplest approach is:

1. Create ECR repos with Terraform.
2. Push images.
3. Apply the full stack with real image tags.

If you want that split cleanly, temporarily comment out the ECS service/task
resources or use targeted apply:

```bash
terraform apply \
  -target=aws_ecr_repository.frontend \
  -target=aws_ecr_repository.caddy \
  -target=aws_ecr_repository.convex_backend
```

Targeted apply is operationally useful here, but avoid using it as your normal
workflow after bootstrapping.

## Build and Push Images

Authenticate Docker to ECR:

```bash
aws ecr get-login-password --region <region> \
  | docker login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com
```

Build and push the frontend. These URLs are build-time inputs for browser code:

```bash
docker build \
  --build-arg NEXT_PUBLIC_SITE_URL=https://<domain>/scrum \
  --build-arg NEXT_PUBLIC_CONVEX_URL=https://<domain>/scrum/api \
  --build-arg NEXT_PUBLIC_CONVEX_SITE_URL=https://<domain>/scrum/site \
  --build-arg NEXT_PUBLIC_AUTH_URL=https://<domain>/scrum/site/api/auth \
  -t scrum-frontend:<tag> ..

docker tag scrum-frontend:<tag> <frontend-ecr-url>:<tag>
docker push <frontend-ecr-url>:<tag>
```

Build and push Caddy:

```bash
docker build -t scrum-caddy:<tag> ./aws-caddy
docker tag scrum-caddy:<tag> <caddy-ecr-url>:<tag>
docker push <caddy-ecr-url>:<tag>
```

Mirror Convex backend to your ECR account:

```bash
docker pull ghcr.io/get-convex/convex-backend:latest
docker tag ghcr.io/get-convex/convex-backend:latest <convex-backend-ecr-url>:<tag>
docker push <convex-backend-ecr-url>:<tag>
```

Update `terraform.tfvars` with the pushed image URIs, then apply:

```bash
terraform plan
terraform apply
```

## Bootstrap Convex on AWS

After ECS starts, generate the admin key from the backend container:

```bash
aws ecs list-tasks --cluster <cluster-name> --service-name <service-name>
```

```bash
aws ecs execute-command \
  --cluster <cluster-name> \
  --task <task-arn> \
  --container backend \
  --interactive \
  --command "./generate_admin_key.sh"
```

ECS Exec requirements:

- Your AWS principal needs permission to call `ecs:ExecuteCommand`.
- The task role in `iam.tf` allows the container-side SSM message channels.
- Private subnets need NAT or VPC endpoints for SSM messages if there is no
  internet egress.

Then deploy functions from your workstation:

```bash
export CONVEX_SELF_HOSTED_URL=https://<domain>/scrum/api
export CONVEX_SELF_HOSTED_ADMIN_KEY=<generated-admin-key>

npx convex env set SITE_URL https://<domain>/scrum
npx convex env set BETTER_AUTH_SECRET <32+ character secret>
npx convex deploy
```

If `npx convex deploy` does not work through `/scrum/api`, add a temporary
admin ALB rule or hostname that forwards root-path traffic directly to backend
port `3210`, deploy through that URL, then remove the rule.

## Updating the App

Frontend or Caddy changes:

1. Build and push a new immutable image tag.
2. Update `terraform.tfvars`.
3. Run `terraform apply`.

Convex function changes:

1. Ensure the backend task is running.
2. Use the existing admin key if EFS data persisted.
3. Run `npx convex deploy`.

Because EFS persists `/convex/data`, task replacement should not require
re-running Convex env setup or function deploy.

## Useful Documentation

- ECS task definitions: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html
- ECS services with load balancing: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-load-balancing.html
- Fargate task networking: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-task-networking.html
- EFS with ECS: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/efs-volumes.html
- ECR push commands: https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html
- ALB listener rules: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-update-rules.html
- Convex self-hosting: https://github.com/get-convex/convex-backend/blob/main/self-hosted/README.md
