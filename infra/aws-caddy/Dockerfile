FROM caddy:2

# ECS/Fargate cannot bind-mount this repository's local Caddyfile the way
# docker-compose.yml does. Copy the AWS-specific config into the image instead.
COPY Caddyfile /etc/caddy/Caddyfile
