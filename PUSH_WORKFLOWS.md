# 🔐 How to Push GitHub Workflows

## Issue
GitHub requires a Personal Access Token (PAT) with `workflow` scope to push `.github/workflows/` files.

## ✅ Solution (2 Options):

---

## **Option 1: Update Your GitHub Token (Recommended)**

### Step 1: Create New Token
1. Go to: https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Name it: "PluginReporter Workflow Access"
4. Select scopes:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `workflow` (Update GitHub Action workflows) ← **IMPORTANT!**
5. Set expiration: 90 days (or longer)
6. Click "Generate token"
7. **Copy the token immediately** (you won't see it again!)

### Step 2: Update Git Credentials
```bash
# On macOS, update Keychain
git credential-osxkeychain erase
# Then type:
host=github.com
protocol=https
# Press Enter twice

# Next push will ask for credentials
# Use your GitHub username and the NEW token as password
```

### Step 3: Push Again
```bash
git push origin main
```

---

## **Option 2: Push via GitHub Web Interface (Quick & Easy)**

### Step 1: Create Workflows Manually

1. Go to: https://github.com/chadlittlepage/PluginReporter
2. Click "Add file" → "Create new file"
3. Name: `.github/workflows/quick-check.yml`
4. Copy content from your local file
5. Commit directly to main

Repeat for `.github/workflows/build.yml`

### Step 2: Push Other Files
```bash
# Remove workflow files from this commit
git reset HEAD .github/

# Commit just the documentation
git commit -m "Add CI/CD documentation and skills assessment"
git push origin main
```

---

## **Option 3: GitHub CLI (Easiest)**

### Install GitHub CLI:
```bash
brew install gh
```

### Authenticate:
```bash
gh auth login
# Follow prompts, select HTTPS, authenticate via browser
```

### Push:
```bash
git push origin main
```

The gh CLI automatically has workflow permissions!

---

## 📋 Files Ready to Push:

- ✅ `.github/workflows/quick-check.yml` - Quick build verification
- ✅ `.github/workflows/build.yml` - Full release automation
- ✅ `CI_CD_SETUP_GUIDE.md` - Complete documentation
- ✅ `SKILLS_ASSESSMENT.md` - Developer skills report

---

## 🎯 Recommended Approach:

**Use Option 3 (GitHub CLI)** - It's the easiest!

```bash
# Install
brew install gh

# Login (opens browser)
gh auth login

# Push
git push origin main
```

---

## ✅ Once Pushed:

Your CI/CD will activate automatically! View at:
https://github.com/chadlittlepage/PluginReporter/actions

First build will trigger within seconds! 🚀
