/**
 * Cloudflare Worker for Plugin Reporter Dashboard
 *
 * This worker receives daily dashboard reports from the Plugin Reporter app
 * and emails them to you using Resend (free tier: 3,000 emails/month).
 *
 * Setup Instructions:
 * 1. Create a free Cloudflare account at https://workers.cloudflare.com
 * 2. Create a new Worker
 * 3. Paste this code into the worker editor
 * 4. Sign up for Resend at https://resend.com (free tier)
 * 5. Get your Resend API key from https://resend.com/api-keys
 * 6. Add environment variables in Cloudflare Worker settings:
 *    - RESEND_API_KEY: Your Resend API key
 *    - RECIPIENT_EMAIL: Your email address
 *    - API_KEY: (Optional) A secret key for authentication
 * 7. Deploy the worker
 * 8. Copy the worker URL and paste it in the app settings
 */

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-API-Key',
  }

  // Handle OPTIONS request (CORS preflight)
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  // Only accept POST requests
  if (request.method !== 'POST') {
    return new Response('Method not allowed', {
      status: 405,
      headers: { 'Content-Type': 'text/plain' }
    })
  }

  try {
    // Optional: Verify API key
    if (API_KEY) {
      const authHeader = request.headers.get('Authorization') || request.headers.get('X-API-Key')
      const apiKey = authHeader?.replace('Bearer ', '')
      if (!apiKey || apiKey !== API_KEY) {
        return new Response('Unauthorized', {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'text/plain' }
        })
      }
    }

    // Get URL path to determine request type
    const url = new URL(request.url)
    const path = url.pathname

    // Parse the request body
    const data = await request.json()

    let emailSent

    // Route based on path
    if (path.endsWith('/dashboard-report') || path === '/') {
      // Daily analytics dashboard report
      emailSent = await sendEmailReport(data)
    } else if (path.endsWith('/bug-report')) {
      // User bug report
      emailSent = await sendBugReportEmail(data)
    } else if (path.endsWith('/feature-request')) {
      // User feature request
      emailSent = await sendFeatureRequestEmail(data)
    } else {
      return new Response(JSON.stringify({
        success: false,
        error: 'Unknown endpoint'
      }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (emailSent.success) {
      return new Response(JSON.stringify({
        success: true,
        message: 'Report received and emailed successfully',
        emailId: emailSent.id
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    } else {
      throw new Error(`Email failed: ${emailSent.error}`)
    }

  } catch (error) {
    console.error('Error processing report:', error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
}

async function sendEmailReport(report) {
  // Format the report as HTML email
  const emailHTML = formatReportHTML(report)
  const emailText = formatReportText(report)

  const emailData = {
    from: 'Plugin Reporter <noreply@yourdomain.com>', // Change this to your verified domain
    to: RECIPIENT_EMAIL,
    subject: `Plugin Reporter Dashboard - ${new Date(report.timestamp).toLocaleDateString()}`,
    html: emailHTML,
    text: emailText,
  }

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(emailData),
    })

    const result = await response.json()

    if (response.ok) {
      return { success: true, id: result.id }
    } else {
      return { success: false, error: result.message || 'Unknown error' }
    }
  } catch (error) {
    return { success: false, error: error.message }
  }
}

function formatReportHTML(report) {
  const stats = report.pluginStats
  const usage = report.usageMetrics
  const device = report.deviceInfo
  const app = report.appInfo

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 800px; margin: 0 auto; padding: 20px; }
    h1 { color: #007AFF; border-bottom: 2px solid #007AFF; padding-bottom: 10px; }
    h2 { color: #555; margin-top: 30px; border-bottom: 1px solid #ddd; padding-bottom: 5px; }
    .section { background: #f9f9f9; padding: 15px; margin: 15px 0; border-radius: 8px; }
    .stat { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #eee; }
    .stat:last-child { border-bottom: none; }
    .label { font-weight: 600; color: #666; }
    .value { color: #333; }
    table { width: 100%; border-collapse: collapse; margin: 10px 0; }
    th { background: #007AFF; color: white; padding: 10px; text-align: left; }
    td { padding: 8px; border-bottom: 1px solid #eee; }
    .badge { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 12px; font-weight: 600; }
    .badge-error { background: #ff3b30; color: white; }
    .badge-warning { background: #ff9500; color: white; }
    .badge-info { background: #007AFF; color: white; }
  </style>
</head>
<body>
  <h1>📊 Plugin Reporter Dashboard</h1>
  <p><strong>Report Date:</strong> ${new Date(report.timestamp).toLocaleString()}</p>

  <div class="section">
    <h2>🖥️ Device Information</h2>
    <div class="stat"><span class="label">Device:</span><span class="value">${device.deviceModel}</span></div>
    <div class="stat"><span class="label">OS:</span><span class="value">${device.osVersion}</span></div>
    <div class="stat"><span class="label">Architecture:</span><span class="value">${device.architecture}</span></div>
    <div class="stat"><span class="label">Memory:</span><span class="value">${device.memory}</span></div>
    ${device.screenResolution ? `<div class="stat"><span class="label">Screen:</span><span class="value">${device.screenResolution}</span></div>` : ''}
  </div>

  <div class="section">
    <h2>📱 App Information</h2>
    <div class="stat"><span class="label">Version:</span><span class="value">${app.version} (${app.build})</span></div>
    <div class="stat"><span class="label">Total Launches:</span><span class="value">${app.totalLaunches}</span></div>
    ${app.installDate ? `<div class="stat"><span class="label">Installed:</span><span class="value">${new Date(app.installDate).toLocaleDateString()}</span></div>` : ''}
  </div>

  <div class="section">
    <h2>🎵 Plugin Statistics</h2>
    <div class="stat"><span class="label">Total Plugins:</span><span class="value">${stats.totalPlugins}</span></div>
    <div class="stat"><span class="label">Obsolete Plugins:</span><span class="value">${stats.obsoletePlugins}</span></div>
    <div class="stat"><span class="label">Total Size:</span><span class="value">${formatBytes(stats.totalSizeBytes)}</span></div>
    <div class="stat"><span class="label">Average Size:</span><span class="value">${formatBytes(stats.averageSizeBytes)}</span></div>

    ${Object.keys(stats.pluginsByFormat).length > 0 ? `
    <h3>By Format</h3>
    <table>
      <tr><th>Format</th><th>Count</th></tr>
      ${Object.entries(stats.pluginsByFormat).sort((a, b) => b[1] - a[1]).map(([format, count]) => `
        <tr><td>${format}</td><td>${count}</td></tr>
      `).join('')}
    </table>
    ` : ''}

    ${Object.keys(stats.pluginsByPublisher).length > 0 ? `
    <h3>Top Publishers</h3>
    <table>
      <tr><th>Publisher</th><th>Plugins</th></tr>
      ${Object.entries(stats.pluginsByPublisher).sort((a, b) => b[1] - a[1]).slice(0, 10).map(([publisher, count]) => `
        <tr><td>${publisher}</td><td>${count}</td></tr>
      `).join('')}
    </table>
    ` : ''}

    ${Object.keys(stats.pluginsByStyle).length > 0 ? `
    <h3>Top Styles</h3>
    <table>
      <tr><th>Style</th><th>Count</th></tr>
      ${Object.entries(stats.pluginsByStyle).sort((a, b) => b[1] - a[1]).slice(0, 10).map(([style, count]) => `
        <tr><td>${style}</td><td>${count}</td></tr>
      `).join('')}
    </table>
    ` : ''}
  </div>

  <div class="section">
    <h2>📈 Usage Metrics</h2>
    <div class="stat"><span class="label">Scans Performed:</span><span class="value">${usage.scansPerformed}</span></div>
    <div class="stat"><span class="label">Exports Performed:</span><span class="value">${usage.exportsPerformed}</span></div>
    <div class="stat"><span class="label">AI Requests:</span><span class="value">${usage.aiSuggestionsRequested}</span></div>
    <div class="stat"><span class="label">Avg Session Duration:</span><span class="value">${formatDuration(usage.averageSessionDuration)}</span></div>
    ${usage.lastScanDate ? `<div class="stat"><span class="label">Last Scan:</span><span class="value">${new Date(usage.lastScanDate).toLocaleString()}</span></div>` : ''}
    ${usage.lastExportDate ? `<div class="stat"><span class="label">Last Export:</span><span class="value">${new Date(usage.lastExportDate).toLocaleString()}</span></div>` : ''}
  </div>

  ${report.errorLogs && report.errorLogs.length > 0 ? `
  <div class="section">
    <h2>⚠️ Error Logs (Last 24h)</h2>
    <p><strong>${report.errorLogs.length} errors logged</strong></p>
    <table>
      <tr><th>Time</th><th>Severity</th><th>Message</th></tr>
      ${report.errorLogs.slice(0, 10).map(log => `
        <tr>
          <td>${new Date(log.timestamp).toLocaleTimeString()}</td>
          <td><span class="badge badge-${log.severity}">${log.severity.toUpperCase()}</span></td>
          <td>${log.message}</td>
        </tr>
      `).join('')}
    </table>
    ${report.errorLogs.length > 10 ? `<p><em>+ ${report.errorLogs.length - 10} more errors</em></p>` : ''}
  </div>
  ` : ''}

  <hr style="margin: 30px 0;">
  <p style="color: #999; font-size: 12px;">
    This is an automated report from Plugin Reporter.
    <br>Generated at ${new Date().toLocaleString()}
  </p>
</body>
</html>
  `
}

function formatReportText(report) {
  const stats = report.pluginStats
  const usage = report.usageMetrics
  const device = report.deviceInfo
  const app = report.appInfo

  return `
Plugin Reporter Dashboard
Report Date: ${new Date(report.timestamp).toLocaleString()}

=== DEVICE INFORMATION ===
Device: ${device.deviceModel}
OS: ${device.osVersion}
Architecture: ${device.architecture}
Memory: ${device.memory}
${device.screenResolution ? `Screen: ${device.screenResolution}` : ''}

=== APP INFORMATION ===
Version: ${app.version} (${app.build})
Total Launches: ${app.totalLaunches}
${app.installDate ? `Installed: ${new Date(app.installDate).toLocaleDateString()}` : ''}

=== PLUGIN STATISTICS ===
Total Plugins: ${stats.totalPlugins}
Obsolete Plugins: ${stats.obsoletePlugins}
Total Size: ${formatBytes(stats.totalSizeBytes)}
Average Size: ${formatBytes(stats.averageSizeBytes)}

=== USAGE METRICS ===
Scans Performed: ${usage.scansPerformed}
Exports Performed: ${usage.exportsPerformed}
AI Requests: ${usage.aiSuggestionsRequested}
${usage.lastScanDate ? `Last Scan: ${new Date(usage.lastScanDate).toLocaleString()}` : ''}

${report.errorLogs && report.errorLogs.length > 0 ? `
=== ERROR LOGS ===
${report.errorLogs.length} errors in last 24 hours
` : ''}

---
Generated at ${new Date().toLocaleString()}
  `.trim()
}

function formatBytes(bytes) {
  if (bytes === 0) return '0 Bytes'
  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i]
}

function formatDuration(seconds) {
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${minutes} min`
  const hours = Math.floor(minutes / 60)
  const remainingMinutes = minutes % 60
  return `${hours}h ${remainingMinutes}m`
}

// MARK: - Bug Report Email

async function sendBugReportEmail(bugReport) {
  const emailHTML = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 800px; margin: 0 auto; padding: 20px; }
    h1 { color: #ff3b30; border-bottom: 2px solid #ff3b30; padding-bottom: 10px; }
    h2 { color: #555; margin-top: 25px; border-bottom: 1px solid #ddd; padding-bottom: 5px; }
    .section { background: #f9f9f9; padding: 15px; margin: 15px 0; border-radius: 8px; }
    .field { margin: 10px 0; }
    .label { font-weight: 600; color: #666; display: block; margin-bottom: 3px; }
    .value { color: #333; white-space: pre-wrap; }
    .severity { display: inline-block; padding: 4px 12px; border-radius: 12px; font-weight: 600; color: white; }
    .severity-low { background: #34c759; }
    .severity-medium { background: #ff9500; }
    .severity-high { background: #ff3b30; }
    .severity-critical { background: #8b0000; }
    code { background: #f0f0f0; padding: 2px 6px; border-radius: 3px; font-family: 'Monaco', monospace; font-size: 13px; }
  </style>
</head>
<body>
  <h1>🐛 Bug Report</h1>
  <p><strong>Submitted:</strong> ${new Date(bugReport.timestamp).toLocaleString()}</p>

  <div class="section">
    <h2>Bug Details</h2>
    <div class="field">
      <span class="label">Title:</span>
      <div class="value"><strong>${bugReport.title}</strong></div>
    </div>
    <div class="field">
      <span class="label">Severity:</span>
      <div><span class="severity severity-${bugReport.severity.toLowerCase().split(' ')[0]}">${bugReport.severity}</span></div>
    </div>
    <div class="field">
      <span class="label">Description:</span>
      <div class="value">${bugReport.description}</div>
    </div>
  </div>

  ${bugReport.stepsToReproduce ? `
  <div class="section">
    <h2>Steps to Reproduce</h2>
    <div class="value">${bugReport.stepsToReproduce}</div>
  </div>
  ` : ''}

  ${bugReport.expectedBehavior || bugReport.actualBehavior ? `
  <div class="section">
    <h2>Behavior</h2>
    ${bugReport.expectedBehavior ? `
    <div class="field">
      <span class="label">Expected:</span>
      <div class="value">${bugReport.expectedBehavior}</div>
    </div>
    ` : ''}
    ${bugReport.actualBehavior ? `
    <div class="field">
      <span class="label">Actual:</span>
      <div class="value">${bugReport.actualBehavior}</div>
    </div>
    ` : ''}
  </div>
  ` : ''}

  ${bugReport.systemInfo ? `
  <div class="section">
    <h2>System Information</h2>
    <div class="field"><span class="label">App Version:</span> ${bugReport.systemInfo.appVersion} (${bugReport.systemInfo.appBuild})</div>
    <div class="field"><span class="label">OS:</span> ${bugReport.systemInfo.osVersion}</div>
    <div class="field"><span class="label">Device:</span> ${bugReport.systemInfo.deviceModel}</div>
  </div>
  ` : ''}

  ${bugReport.crashLog ? `
  <div class="section">
    <h2>Recent Error Logs</h2>
    <pre style="background: #2d2d2d; color: #f8f8f8; padding: 15px; border-radius: 5px; overflow-x: auto; font-size: 12px;">${bugReport.crashLog}</pre>
  </div>
  ` : ''}

  ${bugReport.email ? `
  <div class="section">
    <h2>Contact</h2>
    <p>User email: <a href="mailto:${bugReport.email}">${bugReport.email}</a></p>
  </div>
  ` : ''}

  <hr style="margin: 30px 0;">
  <p style="color: #999; font-size: 12px;">
    Bug report from Plugin Reporter
    <br>Received at ${new Date().toLocaleString()}
  </p>
</body>
</html>
  `

  const emailData = {
    from: 'Plugin Reporter <noreply@yourdomain.com>',
    to: RECIPIENT_EMAIL,
    subject: `🐛 Bug Report: ${bugReport.title}`,
    html: emailHTML,
    replyTo: bugReport.email || undefined,
  }

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(emailData),
    })

    const result = await response.json()
    return response.ok ? { success: true, id: result.id } : { success: false, error: result.message }
  } catch (error) {
    return { success: false, error: error.message }
  }
}

// MARK: - Feature Request Email

async function sendFeatureRequestEmail(featureRequest) {
  const emailHTML = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 800px; margin: 0 auto; padding: 20px; }
    h1 { color: #007AFF; border-bottom: 2px solid #007AFF; padding-bottom: 10px; }
    h2 { color: #555; margin-top: 25px; border-bottom: 1px solid #ddd; padding-bottom: 5px; }
    .section { background: #f9f9f9; padding: 15px; margin: 15px 0; border-radius: 8px; }
    .field { margin: 10px 0; }
    .label { font-weight: 600; color: #666; display: block; margin-bottom: 3px; }
    .value { color: #333; white-space: pre-wrap; }
    .badge { display: inline-block; padding: 4px 12px; border-radius: 12px; font-weight: 600; font-size: 13px; }
    .badge-category { background: #007AFF; color: white; }
    .badge-priority { background: #ff9500; color: white; }
  </style>
</head>
<body>
  <h1>💡 Feature Request</h1>
  <p><strong>Submitted:</strong> ${new Date(featureRequest.timestamp).toLocaleString()}</p>

  <div class="section">
    <h2>Request Details</h2>
    <div class="field">
      <span class="label">Title:</span>
      <div class="value"><strong>${featureRequest.title}</strong></div>
    </div>
    <div class="field">
      <span class="label">Category:</span>
      <span class="badge badge-category">${featureRequest.category}</span>
    </div>
    <div class="field">
      <span class="label">Priority:</span>
      <span class="badge badge-priority">${featureRequest.priority}</span>
    </div>
    <div class="field">
      <span class="label">Description:</span>
      <div class="value">${featureRequest.description}</div>
    </div>
  </div>

  ${featureRequest.useCase ? `
  <div class="section">
    <h2>Use Case / Why This is Needed</h2>
    <div class="value">${featureRequest.useCase}</div>
  </div>
  ` : ''}

  ${featureRequest.email ? `
  <div class="section">
    <h2>Contact</h2>
    <p>User email: <a href="mailto:${featureRequest.email}">${featureRequest.email}</a></p>
    <p><em>This user would like to be notified when this feature is implemented.</em></p>
  </div>
  ` : ''}

  <hr style="margin: 30px 0;">
  <p style="color: #999; font-size: 12px;">
    Feature request from Plugin Reporter
    <br>Received at ${new Date().toLocaleString()}
  </p>
</body>
</html>
  `

  const emailData = {
    from: 'Plugin Reporter <noreply@yourdomain.com>',
    to: RECIPIENT_EMAIL,
    subject: `💡 Feature Request: ${featureRequest.title}`,
    html: emailHTML,
    replyTo: featureRequest.email || undefined,
  }

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(emailData),
    })

    const result = await response.json()
    return response.ok ? { success: true, id: result.id } : { success: false, error: result.message }
  } catch (error) {
    return { success: false, error: error.message }
  }
}
