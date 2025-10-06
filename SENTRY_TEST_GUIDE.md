# 🧪 Sentry Test Guide

## ✅ Current Status:

- ✅ Sentry account created
- ✅ Project "pluginreporter" created
- ✅ Code added to all 3 apps (macOS, iOS, iPad)
- ⏳ Waiting for SDK package in Xcode
- ⏳ Waiting for first event

---

## 🎯 Complete Setup (5 minutes):

### **Step 1: Add Sentry SDK Package in Xcode**

1. Open **Xcode**
2. Open your **PluginReporter.xcodeproj**
3. Click on **"PluginReporter"** (blue icon at top of left sidebar)
4. Select **any target** (e.g., "PR MAC")
5. Go to **"Package Dependencies"** tab (or "General" → scroll down)
6. Click the **"+"** button at the bottom
7. In the search field, paste:
   ```
   https://github.com/getsentry/sentry-cocoa
   ```
8. Click **"Add Package"**
9. When asked which targets, **SELECT ALL**:
   - ✅ PR MAC
   - ✅ PR iPHONE
   - ✅ iPad (if shown)
10. Click **"Add Package"**

Xcode will download the SDK (~30 seconds).

---

### **Step 2: Build the Project**

1. Press **Cmd+B** (or Product → Build)
2. Wait for build to complete
3. **If build succeeds:** ✅ Sentry is integrated!
4. **If build fails:** See troubleshooting below

---

### **Step 3: Run and Test**

#### **Option A: Just Run (Automatic Event)**

1. Press **Cmd+R** to run
2. The app will automatically send a session event to Sentry
3. Check your dashboard: https://sentry.io/organizations/cell-division/projects/pluginreporter/

#### **Option B: Send Test Message (Instant Verification)**

Add this button temporarily to any view (e.g., ContentView.swift):

```swift
Button("Test Sentry") {
    SentrySDK.capture(message: "🚀 Hello from Plugin Reporter!")
}
```

Run the app, click the button, refresh Sentry dashboard - you'll see the message!

#### **Option C: Test Crash Reporting**

Add this button temporarily:

```swift
Button("Test Crash") {
    fatalError("Testing Sentry crash reporting")
}
```

Click it → App crashes → Relaunch app → Check Sentry dashboard for crash report!

---

## 📊 What You'll See in Sentry:

Once working, your dashboard will show:

### **Crash Reports:**
- Exact file and line number where crash occurred
- Full stack trace
- Device/OS information
- Number of users affected

### **Performance Monitoring:**
- App startup time
- Screen load times
- API call performance
- Slow transactions

### **Session Tracking:**
- How many users are active
- Session duration
- Crash-free rate
- User adoption metrics

---

## 🆘 Troubleshooting:

### **Build Error: "Cannot find 'SentrySDK' in scope"**

**Problem:** Sentry package not added to Xcode project

**Solution:**
1. Go back to Step 1 above
2. Make sure you add the package
3. Make sure you select ALL targets

---

### **Build Error: "No such module 'Sentry'"**

**Problem:** Package not added to specific target

**Solution:**
1. Click on project → Select each target individually
2. Go to "Frameworks, Libraries, and Embedded Content"
3. Click "+" and add "Sentry"

---

### **No Events Showing in Sentry**

**Problem:** App isn't sending events

**Checklist:**
- [ ] Did you build successfully?
- [ ] Did you run the app?
- [ ] Is your internet connected?
- [ ] Try the test button from Option B above

**Debug Mode:**
Change this line in your app code:
```swift
options.debug = true  // Shows Sentry logs in console
```

Rebuild and check Xcode console for Sentry messages.

---

## 🎓 Advanced Features (Optional):

### **Track Custom Events:**

```swift
SentrySDK.capture(message: "User exported report")
```

### **Track Errors:**

```swift
do {
    try riskyOperation()
} catch {
    SentrySDK.capture(error: error)
}
```

### **Add User Context:**

```swift
let user = User(userId: "user123")
user.email = "user@example.com"
SentrySDK.setUser(user)
```

### **Add Breadcrumbs (See What Led to Crash):**

```swift
let crumb = Breadcrumb()
crumb.message = "User clicked export button"
crumb.category = "action"
SentrySDK.addBreadcrumb(crumb)
```

---

## 🔐 Security Note:

Your DSN is in the code:
```
https://2e4766b1965fd54a27939749c41484e0@o4510140548055040.ingest.us.sentry.io/4510140566929408
```

This is **safe to commit** - DSN is meant to be public (it only allows SENDING errors, not reading them).

However, if you want to be extra secure, you can:

1. Create a config file (add to .gitignore):
```swift
// SentryConfig.swift
struct SentryConfig {
    static let dsn = "YOUR_DSN_HERE"
}
```

2. Use it:
```swift
options.dsn = SentryConfig.dsn
```

---

## ✅ Verification Checklist:

After completing all steps:

- [ ] Sentry SDK package added in Xcode
- [ ] Project builds without errors (Cmd+B)
- [ ] App runs successfully (Cmd+R)
- [ ] Test message sent and appears in Sentry dashboard
- [ ] Dashboard shows "Number of Errors" > 0 (from test)

---

## 📚 Your Sentry Links:

- **Dashboard:** https://sentry.io/organizations/cell-division/projects/pluginreporter/
- **Issues:** https://sentry.io/organizations/cell-division/issues/
- **Performance:** https://sentry.io/organizations/cell-division/performance/
- **Releases:** https://sentry.io/organizations/cell-division/releases/

---

## 🎉 Once Working:

You'll have:
- ✅ Real-time crash notifications
- ✅ Performance monitoring
- ✅ Error tracking with full context
- ✅ Session analytics
- ✅ Production-ready error monitoring

**All for FREE** (5,000 errors/month)!

---

## 🚀 Next Steps After Sentry Works:

1. Remove test buttons
2. Set `options.debug = false`
3. Commit changes to git
4. Push to GitHub
5. Your CI/CD will now build with Sentry included!

---

**Go add the package in Xcode and let me know when you've built the project!** 🎯
