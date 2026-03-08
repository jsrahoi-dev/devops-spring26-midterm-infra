# RC (Release Candidate) Deployment Guide

This guide explains the bonus semantic release and RC deployment system.

## Overview

The system provides automated release candidate deployments with semantic versioning:

1. **Developers commit** with conventional commit messages
2. **Semantic Release** automatically creates version tags (e.g., `v1.0.0-rc1`)
3. **RC workflow** builds Docker image with the version tag
4. **Image pushed to ECR** with semantic version (not UUID)
5. **RC deployed** to separate EC2 instance
6. **Accessible** at https://rc.rahoi.dev with SSL

---

## Architecture

```
Source Repo (main/rc branch)
    ↓
Conventional Commits
    ↓
Semantic Release Workflow
    ↓
Creates Git Tag (v1.0.0-rc1)
    ↓
RC Release Workflow (triggered by tag)
    ↓
Build Docker Image
    ↓
Tag Image: 1.0.0-rc1
    ↓
Push to ECR
    ↓
Trigger Infra Repo (repository_dispatch)
    ↓
RC Deployment Workflow
    ↓
Deploy to RC EC2
    ↓
Available at https://rc.rahoi.dev
```

---

## Environments

### QA Environment
- **URL:** https://qa.rahoi.dev
- **Purpose:** Nightly builds, latest code
- **Update:** Automatic (nightly at 2 AM UTC)
- **EC2:** `i-0db4adb06f60fb867`
- **Image:** Always `latest` tag

### RC Environment
- **URL:** https://rc.rahoi.dev
- **Purpose:** Release candidates, versioned releases
- **Update:** Manual (when RC tag is created)
- **EC2:** `i-07a954986160dee32`
- **Image:** Semantic version tags (e.g., `1.0.0-rc1`)

---

## Creating Release Candidates

### Method 1: Using Conventional Commits (Recommended)

Semantic Release analyzes your commit messages and automatically creates versions.

**Commit Message Format:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types that trigger releases:**
- `feat:` → Minor version bump (e.g., 1.0.0 → 1.1.0)
- `fix:` → Patch version bump (e.g., 1.0.0 → 1.0.1)
- `BREAKING CHANGE:` → Major version bump (e.g., 1.0.0 → 2.0.0)

**Example commits:**
```bash
# Feature (triggers v1.1.0-rc1 if current is v1.0.0)
git commit -m "feat(frontend): add color classification filters"

# Bug fix (triggers v1.0.1-rc1)
git commit -m "fix(api): resolve database connection timeout"

# Breaking change (triggers v2.0.0-rc1)
git commit -m "feat(api)!: redesign color response structure

BREAKING CHANGE: The color API now returns nested objects instead of flat structure"
```

**Create RC from rc branch:**
```bash
# Create rc branch if it doesn't exist
git checkout -b rc

# Make your commits with conventional format
git commit -m "feat: add new feature"
git commit -m "fix: resolve bug"

# Push to trigger semantic release
git push origin rc

# Semantic release will:
# 1. Analyze commits
# 2. Determine version (e.g., v1.0.0-rc1)
# 3. Create tag and release
# 4. Trigger RC build and deployment
```

### Method 2: Manual Tag Creation

You can also create tags manually:

```bash
# Tag the commit
git tag -a v1.0.0-rc1 -m "Release candidate 1.0.0-rc1"

# Push the tag
git push origin v1.0.0-rc1

# This triggers:
# 1. RC release workflow (builds image)
# 2. RC deployment workflow (deploys to RC EC2)
```

**Version format:** `v{major}.{minor}.{patch}-rc{number}`

Examples:
- `v1.0.0-rc1` - First release candidate for 1.0.0
- `v1.0.0-rc2` - Second release candidate for 1.0.0
- `v2.0.0-rc1` - First release candidate for 2.0.0

---

## Workflow Sequence

### 1. Semantic Release Workflow
**Trigger:** Push to `main` or `rc` branch
**Location:** Source repo `.github/workflows/release.yml`

**What it does:**
- Analyzes commit messages
- Determines next version
- Creates Git tag
- Updates CHANGELOG.md
- Creates GitHub release

### 2. RC Release Workflow
**Trigger:** Git tag matching `v*.*.*-rc*`
**Location:** Source repo `.github/workflows/rc-release.yml`

**What it does:**
- Extracts version from tag
- Builds Docker image with semantic version tag
- Runs smoke tests
- Pushes image to ECR (tagged with version)
- Triggers RC deployment in infra repo

### 3. RC Deployment Workflow
**Trigger:** `repository_dispatch` from source repo
**Location:** Infra repo `.github/workflows/rc-deployment.yml`

**What it does:**
- Pulls versioned image from ECR
- Deploys to RC EC2 instance
- Verifies deployment
- Creates summary

---

## GitHub Secrets Required

### Source Repo Secrets
Add these to `devops-spring26-midterm-source`:

| Secret Name | Value | Purpose |
|-------------|-------|---------|
| `INFRA_REPO_TOKEN` | GitHub Personal Access Token | Trigger infra repo workflow |

**Create token:**
1. Go to: https://github.com/settings/tokens/new
2. Name: "Source to Infra Workflow Trigger"
3. Scopes: `repo` (full control of private repositories)
4. Click "Generate token"
5. Copy token
6. Add to source repo secrets as `INFRA_REPO_TOKEN`

### Infra Repo Secrets
All existing secrets are already configured ✓

---

## Conventional Commit Examples

### Features
```bash
git commit -m "feat(frontend): add dark mode support"
git commit -m "feat(api): implement color search endpoint"
git commit -m "feat: add user preferences persistence"
```

### Bug Fixes
```bash
git commit -m "fix(frontend): resolve color picker contrast issue"
git commit -m "fix(api): handle null color values"
git commit -m "fix: correct session timeout behavior"
```

### Breaking Changes
```bash
git commit -m "feat(api)!: change color format from RGB to HSL

BREAKING CHANGE: Color objects now use HSL instead of RGB.
Update your frontend to handle the new format."
```

### Other Types (don't trigger releases)
```bash
git commit -m "docs: update README with new API examples"
git commit -m "chore: upgrade dependencies"
git commit -m "style: format code with prettier"
git commit -m "refactor: simplify color conversion logic"
git commit -m "test: add unit tests for color service"
git commit -m "ci: update GitHub Actions workflow"
```

---

## Testing RC Deployments

### Create Your First RC

**Quick test:**
```bash
cd /path/to/devops-spring26-midterm-source

# Make a feature change
git checkout rc
echo "# New feature" >> README.md
git add README.md
git commit -m "feat: add documentation section"
git push origin rc

# Wait for workflows:
# 1. Semantic release creates tag (e.g., v1.0.0-rc1)
# 2. RC release builds and pushes image
# 3. RC deployment deploys to https://rc.rahoi.dev
```

**Monitor workflows:**
- Source repo: https://github.com/jsrahoi-dev/devops-spring26-midterm-source/actions
- Infra repo: https://github.com/jsrahoi-dev/devops-spring26-midterm-infra/actions

**Verify:**
```bash
# Check RC deployment
curl https://rc.rahoi.dev/api/health

# Check ECR for versioned image
aws ecr list-images --repository-name color-perception-spa --region us-east-2
```

---

## Version Incrementing

Semantic Release follows these rules:

| Commit Type | Version Change | Example |
|-------------|----------------|---------|
| `fix:` | Patch | 1.0.0 → 1.0.1 |
| `feat:` | Minor | 1.0.0 → 1.1.0 |
| `BREAKING CHANGE:` | Major | 1.0.0 → 2.0.0 |
| Other types | No release | No change |

**RC versioning:**
- First RC: `v1.0.0-rc1`
- Second RC: `v1.0.0-rc2`
- Production: `v1.0.0` (remove `-rc` suffix)

---

## Promoting RC to Production

When an RC is tested and ready:

```bash
# Option 1: Create production tag from RC
git tag -a v1.0.0 -m "Production release 1.0.0"
git push origin v1.0.0

# Option 2: Merge rc to main and let semantic release handle it
git checkout main
git merge rc
git push origin main
```

---

## ECR Image Tags

### QA Environment
- `latest` - Always the most recent build
- `nightly-{run_number}` - Each nightly build

### RC Environment
- `1.0.0-rc1` - Semantic version
- `v1.0.0-rc1` - Semantic version with 'v' prefix
- `1.0.0-rc2` - Next RC iteration

**List all tags:**
```bash
aws ecr describe-images \
  --repository-name color-perception-spa \
  --region us-east-2 \
  --query 'imageDetails[*].imageTags' \
  --output table
```

---

## Rollback

If an RC deployment fails, deploy a previous version:

**Manual rollback:**
```bash
# Go to infra repo Actions
# Run "RC Deployment" workflow manually
# Enter previous version: v1.0.0-rc1
```

**Via GitHub CLI:**
```bash
gh workflow run rc-deployment.yml \
  --repo jsrahoi-dev/devops-spring26-midterm-infra \
  --ref main \
  --field version=v1.0.0-rc1
```

---

## Monitoring

### Check RC Status
```bash
# Health check
curl https://rc.rahoi.dev/api/health

# Check running container
ssh ec2-user@52.14.53.114 "sudo docker ps | grep color-app"

# Check container version
ssh ec2-user@52.14.53.114 "sudo docker inspect color-app | grep 'version'"
```

### View Logs
```bash
# Application logs
ssh ec2-user@52.14.53.114 "sudo docker logs color-app --tail 100"

# Nginx logs
ssh ec2-user@52.14.53.114 "sudo tail -f /var/log/nginx/error.log"
```

---

## Troubleshooting

### Semantic Release Not Creating Tags
**Check:**
1. Commits use conventional format
2. Pushed to `main` or `rc` branch
3. GitHub token has correct permissions
4. No `[skip ci]` in commit messages

### RC Workflow Not Triggered
**Check:**
1. Tag matches pattern `v*.*.*-rc*`
2. Tag pushed to repository
3. Workflow file exists in source repo

### Deployment Fails
**Check:**
1. ECR image exists with correct tag
2. EC2 instance is running
3. Security groups allow SSH
4. Secrets are configured correctly

### Wrong Version Number
**Fix:**
```bash
# Delete incorrect tag locally and remotely
git tag -d v1.0.0-rc1
git push origin :refs/tags/v1.0.0-rc1

# Create correct tag
git tag -a v1.0.0-rc1 -m "Corrected RC tag"
git push origin v1.0.0-rc1
```

---

## Best Practices

1. **Use conventional commits** - Enables automatic versioning
2. **Test locally first** - Verify changes before pushing RC
3. **Increment RC numbers** - v1.0.0-rc1, rc2, rc3... for iterations
4. **Document breaking changes** - Use BREAKING CHANGE footer
5. **Keep RC branch clean** - Only include tested features
6. **Monitor deployments** - Check workflow runs and RC health
7. **Version bump strategy:**
   - Patch for bug fixes
   - Minor for new features
   - Major for breaking changes

---

## Quick Reference

**Create RC:**
```bash
git commit -m "feat: new feature"
git push origin rc
```

**Manual tag:**
```bash
git tag v1.0.0-rc1
git push origin v1.0.0-rc1
```

**Check RC:**
```bash
curl https://rc.rahoi.dev/api/health
```

**View workflows:**
- Source: https://github.com/jsrahoi-dev/devops-spring26-midterm-source/actions
- Infra: https://github.com/jsrahoi-dev/devops-spring26-midterm-infra/actions

**RC Resources:**
- **URL:** https://rc.rahoi.dev
- **Instance:** i-07a954986160dee32
- **IP:** 52.14.53.114
- **ECR:** 899088266694.dkr.ecr.us-east-2.amazonaws.com/color-perception-spa

---

## Summary

You now have a complete semantic release and RC deployment pipeline:

✅ Conventional commits → Automatic versioning
✅ Semantic version tags (not UUIDs)
✅ Separate RC environment
✅ RC domain with SSL (https://rc.rahoi.dev)
✅ Automated build and deployment
✅ GitHub releases and changelogs
✅ Notification on failures

Ready to create your first RC! 🚀
