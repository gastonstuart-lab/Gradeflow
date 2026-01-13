# 🚀 Quick Start: Enable AI Features

## Super Easy Setup (2 Options!)

### ⭐ EASIEST: Option 1 - VS Code Settings (Recommended)

1. **Get your OpenAI API key**:
   - Go to https://platform.openai.com/api-keys
   - Sign in or create account
   - Click "Create new secret key"
   - Copy the key (starts with `sk-...`)

2. **Add to VS Code settings**:
   - Open `.vscode/settings.json` (it's already in your workspace)
   - Find the commented section at the bottom
   - Uncomment and replace `sk-your-actual-api-key-here` with your real key:
   ```json
   "terminal.integrated.env.windows": {
     "OPENAI_API_KEY": "sk-proj-abc123xyz..."
   }
   ```
   - Save the file

3. **Run with AI**:
   - Press **F5**
   - Select **"Flutter (Chrome) + AI 🤖"** from dropdown
   - Done! AI features now work

### 🔒 Option 2 - .env File (More Secure)

1. **Get your API key** (same as Option 1)

2. **Edit `.env` file**:
   - Open `.env` in the project root
   - Replace `your_openai_api_key_here` with your real key
   - Save

3. **Set Windows environment variable**:
   ```powershell
   # In PowerShell (run as yourself, not admin):
   [Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "sk-your-key-here", "User")
   ```

4. **Restart VS Code** completely (close all windows)

5. **Run**: Press F5 → Select "Flutter (Chrome) + AI 🤖"

---

## 🎯 Using AI Features

Once running with the AI config, you'll see AI options in:

### 📊 Exam Score Import ✅ (Already Integrated)
- Upload exam file
- Click "Try AI" if format unclear
- AI extracts scores automatically

### 📅 Calendar Import ✅ (Already Integrated)
- Import schedule file  
- "Try AI" appears on parsing errors
- AI interprets calendar events

---

## ✅ How to Verify It's Working

**AI is Enabled when**:
- Launch dropdown shows: `Flutter (Chrome) + AI 🤖`
- Console shows OpenAI configuration loaded
- Import screens show "Try AI" buttons

**AI is NOT enabled when**:
- Using regular "Flutter (Chrome)" config
- No AI buttons in import dialogs
- That's fine! App works great without AI

---

## 💰 Costs

- **Pay per use**: ~$0.01-$0.05 per import
- **Free tier**: $5 credit for new OpenAI accounts
- **Optional**: App has smart local parsers that work without AI

---

## 🔧 Troubleshooting

### "AI is not configured" error
1. Check you selected the AI launch config (with 🤖 emoji)
2. Verify API key is in `.vscode/settings.json` or environment variable
3. Restart VS Code completely
4. Check OpenAI account has credits: https://platform.openai.com/usage

### Environment variable not loading
**Quick fix**:
Just use Option 1 (VS Code settings) - it's simpler!

---

## 🔐 Security

✅ `.env` file is gitignored (safe)  
✅ API key only on your machine  
⚠️ **Don't** commit API keys to git  
⚠️ **Don't** share your key  

**Best Practice**: Use Option 1 (settings.json) for local dev, or set Windows User environment variable for better security.

