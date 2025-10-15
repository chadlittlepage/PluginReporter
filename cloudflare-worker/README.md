# Plugin Reporter Dashboard - Cloudflare Worker Setup

This is a **100% FREE** server setup for receiving daily dashboard reports from your Plugin Reporter app.

## What You Get

- ✅ Automated daily email reports with plugin statistics
- ✅ Beautiful HTML email formatting
- ✅ Offline queuing (reports sent when connection restored)
- ✅ Zero monthly costs
- ✅ Secure API key authentication

## Setup Instructions (15 minutes)

### Step 1: Create Cloudflare Worker (FREE)

1. Go to https://workers.cloudflare.com
2. Click "Sign Up" (completely free, no credit card required)
3. Verify your email
4. Click "Create Application" → "Create Worker"
5. Name it something like `plugin-reporter-dashboard`
6. Click "Deploy"

### Step 2: Setup Email Service (FREE)

1. Go to https://resend.com
2. Click "Sign Up" (free tier: 3,000 emails/month)
3. Verify your email
4. Go to "API Keys" and click "Create API Key"
5. Copy the API key (starts with `re_...`)

**Important:** By default, Resend only sends to your verified email. For production use:
- Add and verify your domain in Resend settings
- Or use the default `onboarding@resend.dev` sender (limited to verified recipient)

### Step 3: Configure Worker

1. In Cloudflare Workers dashboard, click on your worker
2. Go to "Settings" → "Variables"
3. Add these **environment variables**:

   | Variable Name | Value | Example |
   |--------------|-------|---------|
   | `RESEND_API_KEY` | Your Resend API key | `re_123abc...` |
   | `RECIPIENT_EMAIL` | Your email address | `you@example.com` |
   | `API_KEY` | (Optional) A secret key | `your-secret-key-123` |

4. Click "Save"

### Step 4: Deploy Worker Code

1. Click on "Quick Edit" in your Cloudflare Worker
2. Delete all existing code
3. Copy the entire contents of `worker.js` from this folder
4. Paste it into the editor
5. **Important:** Edit line 139 to use your verified email domain:
   ```javascript
   from: 'Plugin Reporter <noreply@yourdomain.com>'
   ```
   Or use the default (only sends to your verified email):
   ```javascript
   from: 'Plugin Reporter <onboarding@resend.dev>'
   ```
6. Click "Save and Deploy"

### Step 5: Get Worker URL

1. In Cloudflare Workers dashboard, find your worker
2. Copy the worker URL (looks like: `https://plugin-reporter-dashboard.your-account.workers.dev`)
3. This is your **Server Endpoint** for the app settings

### Step 6: Configure Plugin Reporter App

1. Open Plugin Reporter
2. Go to Settings
3. Find "Dashboard Reporting" section
4. Enter your configuration:
   - **Server Endpoint**: Paste your Cloudflare Worker URL
   - **API Key**: Enter the same key you set in Cloudflare (or leave blank if you didn't set one)
   - **Enable Daily Reports**: Toggle ON
   - **Schedule Time**: Choose when to receive reports (e.g., 9:00 AM)
5. Click **"Test Connection"** to verify it works
6. Click **"Send Now"** to send your first report

## Verification

After setup, you should:

1. ✅ See "Connected" status in the app
2. ✅ Receive a test email at your inbox
3. ✅ See "Next report: in X hours" in settings

## Email Sample

You'll receive beautifully formatted HTML emails with:

- 📊 **Device Info**: Model, OS, memory, screen
- 📱 **App Stats**: Version, launches, install date
- 🎵 **Plugin Stats**: Total count, formats, publishers, styles, sizes
- 📈 **Usage Metrics**: Scans, exports, AI requests, session duration
- ⚠️ **Error Logs**: Any issues from the last 24 hours

## Troubleshooting

### "Not Connected" in app

- Check that Server Endpoint URL is correct
- Verify RESEND_API_KEY is set in Cloudflare
- Check Cloudflare Worker logs for errors

### Not receiving emails

- Verify RECIPIENT_EMAIL matches your verified email in Resend
- Check your spam folder
- Verify the `from` email in worker.js line 139 is correct
- Check Resend dashboard logs at https://resend.com/emails

### "Server error 401: Unauthorized"

- Your API_KEY in the app doesn't match the one in Cloudflare
- Either update both to match, or remove API_KEY from both

### "Server error 500"

- Check Cloudflare Worker logs (click "Logs" in worker dashboard)
- Verify your Resend API key is valid
- Make sure all environment variables are set

## Cost Breakdown

| Service | Free Tier | Monthly Cost |
|---------|-----------|--------------|
| Cloudflare Workers | 100,000 requests/day | **$0** |
| Resend Email | 3,000 emails/month | **$0** |
| **TOTAL** | | **$0** ✅ |

With 1 email per day = 30 emails/month, you're well within free limits!

## Advanced: Customization

### Change Email Template

Edit the `formatReportHTML()` function in `worker.js` to customize:
- Colors and styling (CSS in the `<style>` tag)
- Which statistics to include/exclude
- Email layout and formatting

### Add Slack/Discord Notifications

Replace the `sendEmailReport()` function to post to a webhook instead:

```javascript
async function sendToSlack(report) {
  await fetch('YOUR_SLACK_WEBHOOK_URL', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      text: `📊 Daily Report: ${report.pluginStats.totalPlugins} plugins`
    })
  })
}
```

### Store Reports in Database

Add Cloudflare D1 (free tier) to store historical reports:

```javascript
// In handleRequest(), after sending email:
await env.DB.prepare(
  'INSERT INTO reports (date, data) VALUES (?, ?)'
).bind(new Date().toISOString(), JSON.stringify(report)).run()
```

## Security Notes

- ✅ Worker URL is public but requires API key (if configured)
- ✅ API keys stored securely in Cloudflare
- ✅ HTTPS enforced for all connections
- ✅ No user data stored (emails sent and deleted)

## Support

If you encounter issues:

1. Check Cloudflare Worker logs
2. Check Resend email logs
3. Click "Test Connection" in app to see detailed error
4. Review the troubleshooting section above

## Next Steps

Once working:
- **Preview Reports**: Click "Preview Report" in settings to see what data is sent
- **Manual Send**: Click "Send Now" anytime to trigger an immediate report
- **Queued Reports**: If offline, reports queue automatically and send when online

Enjoy your free, automated dashboard reports! 📊
