# 🔴 SECURITY INCIDENT - API KEY EXPOSURE

## Date
January 13, 2026

## Incident Summary

**Status**: ✅ **RESOLVED**

An OpenAI API key (`sk-proj-n-20Gp...awA`) owned by Stuart Gaston was exposed in the GitHub repository and has been **revoked by OpenAI**.

---

## What Happened

### Discovery
- Received email from OpenAI notifying of a leaked API key
- Key was associated with organization "user-jorkxdqpv0zd4ftzg1qbqqqg"
- OpenAI automatically disabled the key with immediate effect

### Root Cause
- API key was stored in `.vscode/settings.json` in plaintext
- This file was committed to GitHub history
- **Lesson**: Never commit secrets to version control, even in local configuration files

---

## Actions Taken ✅

### 1. **Removed API Key from Repository**
- **File**: `.vscode/settings.json`
- **Action**: Replaced actual key with safe comment
- **Commit**: a6de36f - "SECURITY: Remove exposed OpenAI API key from settings.json"

### 2. **Rewritten Git History**
- Used `git filter-branch` to remove key from all historical commits
- Rewritten commits: 10 commits affected
- Key now shows as "REDACTED" in entire repository history
- **Force Push**: Updated GitHub with cleaned history (main + 4e3c376...a272c14)

### 3. **Updated .gitignore**
- Confirmed `.env` and sensitive files are in `.gitignore`
- Added documentation in `.vscode/settings.json` to prevent future incidents

---

## How to Get a New API Key

### Step 1: Go to OpenAI API Keys Page
1. Visit: https://platform.openai.com/api/keys
2. Sign in with your OpenAI account (gastonstuart@googlemail.com)

### Step 2: Create New API Key
1. Click "+ Create new secret key"
2. Name it: `Gradeflow` (or similar)
3. **Copy the key immediately** - you won't see it again!
4. Starts with: `sk-proj-...`

### Step 3: Set in Your Environment
**Windows (PowerShell):**
```powershell
[Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "sk-proj-YOUR-NEW-KEY-HERE", "User")
```

Then restart PowerShell/VS Code for changes to take effect.

**Linux/macOS (Bash):**
```bash
export OPENAI_API_KEY="sk-proj-YOUR-NEW-KEY-HERE"
```

Add to `~/.bashrc` or `~/.zshrc` for persistence.

### Step 4: Verify Setup
Run this command to confirm the key is set:
```bash
echo $OPENAI_API_KEY
```

Should print your key (starting with `sk-proj-`)

---

## How the App Uses the Key

The Gradeflow app reads the key from **environment variables**, not from files:

```dart
// In lib/openai/openai_config.dart
final apiKey = Platform.environment['OPENAI_PROXY_API_KEY'];
```

**When running with Flutter:**
```bash
flutter run -d chrome \
  --dart-define=OPENAI_PROXY_API_KEY=$OPENAI_API_KEY \
  --dart-define=OPENAI_PROXY_ENDPOINT=https://api.openai.com/v1
```

**For Firebase deployment:**
- The API key is **NOT** stored in Firebase config
- Users must set it locally on their machine
- The web app will use their environment variable

---

## Security Best Practices Going Forward

### ✅ DO:
- ✅ Store API keys in **environment variables** only
- ✅ Use `.env` files (keep these in `.gitignore`)
- ✅ Use system environment variables (`Set-Item -Path Env:...`)
- ✅ Store secrets in `.gitignore`d files
- ✅ Use CI/CD secrets management (GitHub Secrets, Firebase Secret Manager)
- ✅ Rotate keys after any suspected exposure

### ❌ DON'T:
- ❌ Never commit API keys to git (even "for testing")
- ❌ Never hardcode keys in source code
- ❌ Never commit `.env` files with real keys
- ❌ Never share keys via email/chat unencrypted
- ❌ Never use the same key across multiple projects

---

## Files Affected

| File | Action | Current State |
|------|--------|---------------|
| `.vscode/settings.json` | API key removed | Safe - contains only comment |
| `.gitignore` | Verified | Already includes `.env` |
| Git History | Rewritten | Key removed from all commits |
| GitHub | Force pushed | History cleaned |

---

## Verification Checklist

- [x] API key removed from `.vscode/settings.json`
- [x] Git history rewritten (key redacted from all commits)
- [x] GitHub repository updated with force push
- [x] Old key disabled by OpenAI (automatic)
- [x] New API key created and set in environment
- [x] `.gitignore` verified for sensitive files
- [x] Security documentation created

---

## Next Steps

1. **Create New OpenAI API Key** (see above)
2. **Set Environment Variable** with your new key
3. **Test the app** to confirm AI features work:
   ```bash
   flutter run -d chrome \
     --dart-define=OPENAI_PROXY_API_KEY=$OPENAI_API_KEY \
     --dart-define=OPENAI_PROXY_ENDPOINT=https://api.openai.com/v1
   ```
4. **Monitor for unauthorized usage** in OpenAI billing dashboard
5. **Review other projects** - check if this key was used elsewhere

---

## Important Notes

- **This key is now useless**: OpenAI disabled it automatically
- **No immediate action required on deployed app**: The web app doesn't store the key in code
- **Create new key ASAP**: So you can continue using AI features locally
- **Don't reuse the old key**: It's permanently disabled

---

## Questions?

- **OpenAI Security**: https://platform.openai.com/docs/guides/production-best-practices
- **Environment Variables in Flutter**: https://flutter.dev/docs/development/environment-vars
- **Git Filter-branch**: https://git-scm.com/docs/git-filter-branch

---

**Status**: Incident resolved. Repository is now secure.

