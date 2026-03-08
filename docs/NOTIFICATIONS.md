# Notification Setup Guide

This workflow includes multiple notification methods for build failures.

## Notification Methods

### 1. GitHub Issues (✅ Already Working)

**How it works:**
- Automatically creates a GitHub issue when the build fails
- Includes detailed information about which stage failed
- Adds comments to existing issues if multiple failures occur on the same day
- Labels: `build-failure`, `automated`

**Notification recipients:**
- Repository owner (you'll see it in your GitHub notifications)
- Anyone watching the repository
- Anyone subscribed to issue notifications

**No setup required!** This works out of the box.

**Where to see:**
- Issues tab: https://github.com/jsrahoi-dev/devops-spring26-midterm-infra/issues
- GitHub notifications: https://github.com/notifications

---

### 2. GitHub Email Notifications (✅ Already Working)

**How it works:**
- GitHub automatically sends email when workflows fail
- Sent to the repository owner's email address

**To ensure you receive these:**
1. Go to: https://github.com/settings/notifications
2. Under "Actions" → Check ✅ **"Send notifications for failed workflows only"**
3. Verify your email address is set and verified

**No additional setup required!**

---

### 3. Email Notifications (Optional - Requires Setup)

For more detailed email notifications via SMTP:

**Setup Steps:**

1. **Create an app-specific password:**
   - If using Gmail: https://myaccount.google.com/apppasswords
   - Other providers: Check your email provider's documentation

2. **Add GitHub Secrets:**
   Go to: https://github.com/jsrahoi-dev/devops-spring26-midterm-infra/settings/secrets/actions

   Add these secrets:
   - `NOTIFICATION_EMAIL`: Your email address (e.g., `you@gmail.com`)
   - `NOTIFICATION_EMAIL_PASSWORD`: Your app-specific password

3. **That's it!** Emails will be sent on failure.

**Email includes:**
- Workflow run number
- Direct link to logs
- QA environment link
- Failure details

**Note:** If you don't add these secrets, the step is safely ignored (`ignore_missing_if: true`).

---

### 4. Slack Notifications (Optional)

To add Slack notifications, you can add this step to the workflow:

```yaml
- name: Send Slack notification
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "❌ Nightly Build Failed",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*Nightly Build Failed*\n\nRun: #${{ github.run_number }}\n<${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View Logs>"
            }
          }
        ]
      }
```

**Setup:**
1. Create a Slack webhook: https://api.slack.com/messaging/webhooks
2. Add secret `SLACK_WEBHOOK_URL` in GitHub

---

## What You Get with Each Notification Method

### GitHub Issues
- ✅ **Persistent record** of failures
- ✅ **Detailed information** about failed stage
- ✅ **Automatic deduplication** (one issue per day)
- ✅ **Easy to track** and resolve
- ✅ **No setup required**

### GitHub Email
- ✅ **Immediate notification**
- ✅ **No setup required**
- ✅ **Standard GitHub format**
- ⚠️ Less detailed than custom emails

### Custom Email (SMTP)
- ✅ **More detailed** content
- ✅ **Customizable** format
- ⚠️ Requires setup (email credentials)

### Slack
- ✅ **Real-time** team notifications
- ✅ **Rich formatting**
- ⚠️ Requires Slack workspace setup

---

## Current Notification Setup (Out of the Box)

**Already Working:**
1. ✅ **GitHub Issues** - Creates issues automatically on failure
2. ✅ **GitHub Email** - Sends email to repo owner (if notifications enabled)
3. ✅ **Workflow Summary** - Shows detailed summary in GitHub Actions UI

**Optional (Requires Secrets):**
1. ⚪ **Custom Email** - Needs `NOTIFICATION_EMAIL` and `NOTIFICATION_EMAIL_PASSWORD`
2. ⚪ **Slack** - Needs `SLACK_WEBHOOK_URL`

---

## Testing Notifications

### Test by Triggering a Failure

1. **Temporarily break the build:**
   ```bash
   # In your source repo, add this to any file to force a failure
   echo "exit 1" >> backend/server.js
   ```

2. **Trigger the workflow manually:**
   - Go to Actions tab
   - Run "Nightly Build and Deploy to QA"

3. **Check for notifications:**
   - GitHub Issues: Check the Issues tab
   - Email: Check your email
   - GitHub Notifications: https://github.com/notifications

4. **Fix and verify:**
   - Remove the `exit 1` line
   - Re-run the workflow
   - Verify success notifications

---

## Notification Content Examples

### GitHub Issue (Automatic)
```
Title: ❌ Nightly Build Failed - Smoke Tests Stage

Body:
## Nightly Build Failure Report

**Failed Stage:** Smoke Tests
**Workflow Run:** #42
**Triggered by:** schedule
**Time:** 2026-03-08T02:00:00Z

### Stage Outcomes:
- Build: success
- Smoke Tests: failure
- Push to ECR: skipped
- Deploy to QA: skipped

### Quick Links:
- View Workflow Run
- QA Environment
- View Logs

### Recommended Actions:
1. Check the workflow logs for detailed error messages
2. Verify AWS credentials and permissions
3. Check EC2 instance status
4. Review recent code changes
```

### Email (Custom - If Configured)
```
Subject: ❌ Nightly Build Failed - Run #42

Body:
Nightly Build Failed

Repository: jsrahoi-dev/devops-spring26-midterm-infra
Workflow: Nightly Build and Deploy to QA
Run Number: 42

View logs: [link]
QA Environment: https://qa.rahoi.dev
```

---

## Managing Notification Frequency

### Reduce Noise
If you get too many notifications:

1. **Change schedule** (less frequent builds):
   ```yaml
   schedule:
     - cron: '0 2 * * 1'  # Only Mondays
   ```

2. **Adjust GitHub notification settings:**
   - Settings → Notifications
   - Customize "Actions" notifications

3. **Add filters** to your email client:
   - Filter by: `[jsrahoi-dev/devops-spring26-midterm-infra]`
   - Auto-label or folder

### Increase Visibility
If you want more notifications:

1. **Add Discord webhook**
2. **Add Microsoft Teams webhook**
3. **Add PagerDuty integration** (for critical alerts)

---

## Troubleshooting

### Not Receiving GitHub Emails?
1. Check: https://github.com/settings/notifications
2. Verify your email is verified
3. Check spam folder
4. Enable "Actions" notifications

### GitHub Issues Not Created?
1. Verify workflow has `issues: write` permission (✅ already set)
2. Check Actions logs for errors
3. Verify the workflow ran to completion

### Custom Email Not Working?
1. Verify secrets are set: `NOTIFICATION_EMAIL` and `NOTIFICATION_EMAIL_PASSWORD`
2. Check that app-specific password is correct
3. Try with a different email provider
4. Check workflow logs for SMTP errors

---

## Security Notes

- ✅ Secrets are not exposed in logs or issues
- ✅ Email passwords use GitHub Secrets (encrypted)
- ✅ Issues only contain non-sensitive information
- ✅ Webhook URLs are stored as secrets

---

## Summary

**Immediate benefits (no setup):**
- GitHub Issues automatically created on failure
- Email notifications to repo owner
- Detailed workflow summaries

**Optional enhancements:**
- Custom SMTP emails for more control
- Slack for team notifications
- Other integrations as needed

**Recommended setup for this project:**
- Keep GitHub Issues (already working) ✅
- Enable GitHub email notifications in your settings ✅
- Optionally add custom email for detailed reports

You're all set! Notifications will alert you immediately if any nightly build fails.
