# SaaS Infrastructure Automation & Deployment Pipeline (AWS + Terraform + GitHub Actions)

This repository implements a secure, automated, and repeatable infrastructure and deployment process for a legacy SaaS app that previously ran on manually-provisioned EC2 instances and jump-box–driven scripts.

Highlights
- AWS VPC with public/private subnets, NAT, Internet GW
- Application Load Balancer with path-based routing to two EC2 instances (staging, production) in private subnets
- Strict security groups (ALB exposes HTTP/HTTPS; instances only accept from ALB)
- S3 bucket for build artifacts and static assets
- AWS Secrets Manager for secrets (no plaintext in repo)
- GitHub Actions CI/CD
  - Run tests on push/PR
  - Auto-deploy to staging on merge to `develop`
  - Deploy to production on GitHub Release (from `main`), with approvals
  - Store build artifacts in S3
  - Rollback workflow: redeploy the last known-good artifact
- Instances managed by SSM (no SSH). Deploys are done via SSM RunCommand.

> Time-boxed deliverable: this skeleton is intentionally lean, modular, and ready to extend. Apply/validate in ~4–6 hours.

---

1) Prerequisites

- Terraform >= 1.6
- AWS account + IAM permissions to create VPC, EC2, ALB, IAM, S3, Secrets Manager, SSM, OIDC provider
- GitHub repository (for OIDC), with org/repo names available
- (Optional) Domain/DNS if you want pretty host-based routing; this demo uses path-based routing `/staging/*` and `/prod/*`.

---

2) Deploy the Infrastructure

```bash
cd infrastructure
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your values
terraform init
terraform apply -auto-approve
```

##What this creates
- VPC with 2 AZs, public/private subnets, IGW, NAT
- ALB + target groups + listeners for path rules:
  - `/staging/*` → staging instance target group
  - `/prod/*` → production instance target group
- EC2 (Amazon Linux 2023) instances (one per env) in private subnets with SSM agent + systemd service for the app
- S3 bucket for artifacts/static assets
- IAM roles:
  - EC2 instance role: read from S3 + read `SecretsManager:GetSecretValue`
  - GitHub Actions deploy role with OIDC trust (no long-lived keys!)
- Secrets Manager placeholders for `app/<env>/config`

##Outputs
- `alb_dns_name` – access via `http://{alb_dns_name}/staging/health` and `/prod/health`


3) How the Pipeline Works

GitHub Actions workflows live in `.github/workflows/`.

 `ci-cd.yml`
- On push/PR: run `pytest`
- On merge to `develop`: build & package app, upload artifact to S3 under `artifacts/staging/<sha>.zip`, deploy to staging via SSM RunCommand. Health-check via ALB path `/staging/health`. If health fails, attempt rollback to `artifacts/staging/latest.zip`.
- On Release (published) from main: same flow, deploy to production (`/prod/health`).

Artifacts:
- We keep a rolling `latest.zip` for each environment. Only updated after health-check passes.

 `rollback.yml`
- Manual workflow (workflow_dispatch). Provide `environment` and optional `s3_key` (defaults to `artifacts/<env>/latest.zip`). This sends an SSM command to redeploy the given artifact key.


4) Rollback

Two safe ways:
1. Manual workflow: Run Rollback workflow, pick `staging` or `production`. Uses `latest.zip` by default (last known-good). Or provide a specific S3 key.
2. Automatic on failed deploy: The `ci-cd.yml` staging job attempts rollback to `latest.zip` if the post-deploy health check fails.


5) Security Considerations

- No plaintext secrets in repo. App reads from AWS Secrets Manager at runtime with the instance role.
- No SSH. Use SSM RunCommand for remote actions. Instance SG has no inbound from the Internet; only ALB can reach the app port.
- OIDC for CI: GitHub Actions assumes an AWS role via OIDC (short-lived creds). No long-lived AWS keys in GitHub.
- Least privilege IAM polices (scoped to S3 artifact bucket, SecretsManager ARNs, SSM limited actions).
- NACLs left permissive by default; security primarily via SGs. Tighten if required.
- ALB HTTPS: For demo simplicity, HTTP is enabled; add an ACM cert + 443 listener for prod use.
- Patching: AMI is the latest Amazon Linux 2023; consider SSM Patch Manager.


6) Example App

A tiny Flask app (`/app`) with a `/health` endpoint and a `/secret` endpoint that fetches a secret from Secrets Manager (`app/<env>/config`). The systemd service runs Gunicorn on port 8080.

Deploy happens by SSM running `deploy/install_app.sh` on the instances. The script downloads the S3 artifact, unpacks into `/opt/myapp`, installs deps, and restarts the systemd service. It sets `APP_ENV` (`staging` or `prod`) so the app knows which secret to read.

---

7) Variables to Set

See `infrastructure/terraform.tfvars.example`:

- `project_name`, `aws_region`
- `github_org`, `github_repo` – to scope OIDC trust
- `artifact_bucket_name` – S3 bucket name must be globally unique
- (Optional) CIDR ranges, instance types, key tags


8) Clean Up

###bash
cd infrastructure
terraform destroy

