# DevOps Midterm - Infrastructure

[![Integration Tests](https://github.com/jsrahoi-dev/devops-spring26-midterm-infra/actions/workflows/integration-tests.yml/badge.svg)](https://github.com/jsrahoi-dev/devops-spring26-midterm-infra/actions/workflows/integration-tests.yml)

Infrastructure automation and CI/CD workflows for Color Perception SPA deployment to AWS.

## Overview

This repository contains GitHub Actions workflows, deployment scripts, and infrastructure documentation for deploying the Color Perception SPA to AWS EC2.

## Architecture

- **Source Repo:** Application code (separate repository)
- **Infra Repo:** This repository - deployment automation
- **AWS Resources:**
  - RDS MySQL (manually created)
  - QA EC2 (pre-allocated, always running)
  - ECR (container registry)
  - Route53 (domain and DNS)
  - Temporary EC2 (nightly builds only)

## Workflows

### Integration Tests (`integration-tests.yml`)
- **Trigger:** Pull requests to main or manual dispatch
- **Steps:**
  1. Create temporary security group
  2. Launch temporary EC2 instance
  3. Deploy full application stack (app + MySQL)
  4. Run unit and comprehensive API tests
  5. Collect logs
  6. Cleanup all temporary resources
- **Features:**
  - Tests against real infrastructure
  - Full stack deployment validation
  - Automatic PR comments with results
  - Complete resource cleanup (always runs)

### Nightly Build (`nightly-build.yml`)
- **Trigger:** Scheduled (2 AM daily) or manual dispatch
- **Steps:**
  1. Launch temporary EC2
  2. Build and test container image
  3. Run smoke tests
  4. Push to ECR if tests pass
  5. Deploy to QA EC2
  6. Terminate temporary EC2

### RC Promotion (`rc-promotion.yml`) - BONUS
- **Trigger:** Git tag matching `v*.*.*-rc*`
- **Steps:**
  1. Build image with semantic version tag
  2. Push to ECR
  3. Deploy to RC EC2

## Scripts

- `setup-ec2.sh` - Initial EC2 instance setup
- `deploy.sh` - Pull image from ECR and deploy
- `smoke-test.sh` - Health check and basic tests
- `setup-ssl.sh` - Let's Encrypt SSL configuration

## Security

- GitHub OIDC for AWS authentication (no long-lived credentials)
- Secrets stored in GitHub Secrets
- Security groups with least privilege access
- SSL/TLS enabled on all domains

## Documentation

See `docs/` folder for detailed setup guides:
- RDS setup
- EC2 configuration
- Route53 and domain setup
- SSL certificate installation
