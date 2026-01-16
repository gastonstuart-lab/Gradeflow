# Security Guidelines - Gradeflow

**Last Updated:** January 16, 2026

## Critical: API Key Management

### ⚠️ API Key Exposure History
A production OpenAI API key was accidentally committed to git history on:
- Commits: `a6de36f`, `a272c14`
- Status: **REVOKED AND REGENERATED**
- Action: If you have access to git history, assume that key is compromised

### ✅ Current Security Status
- API keys are **NOT** stored in version control
- Environment variables are used for secrets
- `.env` file is in `.gitignore`
- Settings JSON contains no actual keys

### How to Set Up Secrets Safely

#### Option 1: PowerShell Environment Variable (Development)
```powershell
Set-Item -Path Env:OPENAI_PROXY_API_KEY -Value "sk-your-key-here"
Set-Item -Path Env:OPENAI_PROXY_ENDPOINT -Value "https://api.openai.com/v1"
flutter run -d chrome
```

#### Option 2: VS Code Launch Configuration
Edit `.vscode/launch.json` and add to the `Flutter (Chrome) + AI 🤖` configuration:
```json
"env": {
  "OPENAI_PROXY_API_KEY": "${env:OPENAI_PROXY_API_KEY}",
  "OPENAI_PROXY_ENDPOINT": "https://api.openai.com/v1"
}
```

#### Option 3: Firebase Cloud Build (Production)
Store secrets in Google Cloud Secret Manager and inject them during build.

### Secrets to Rotate/Check

- [ ] OpenAI API Key - **ROTATE NOW**
- [ ] Firebase Service Account Key
- [ ] Google Cloud API Keys  
- [ ] GitHub Personal Access Token (if used)

### Audit Checklist

- [ ] Remove all API keys from `.vscode/settings.json`
- [ ] Check `.env` file is in `.gitignore`
- [ ] Verify no keys in git history (search for `sk-`, `AIza`, `firebase_key`)
- [ ] Enable git hooks to prevent future commits of secrets (use `gitleaks` or similar)
- [ ] Rotate any keys that were exposed

### Best Practices Going Forward

1. **Never commit secrets** - Use environment variables
2. **Use .env files locally** - Copy `.env.example` to `.env`, add your keys
3. **Add to .gitignore** - Ensure `.env` is ignored
4. **Use secret managers** - Firebase, AWS Secrets Manager, Google Cloud Secret Manager for production
5. **Rotate regularly** - Change API keys every 90 days
6. **Monitor usage** - Check OpenAI dashboard for unexpected activity

### Detection

To find any remaining secrets in the codebase:
```bash
git log --all -p | grep -i "sk-\|AIza\|secret\|api.key" | head -20
```

Or use a tool like `gitleaks`:
```bash
gitleaks detect --source . -v
```

---

**If you suspect a key leak:**
1. Immediately revoke the key in the service provider
2. Generate a new key
3. Update environment variables
4. Redeploy
5. Check logs for unauthorized usage
