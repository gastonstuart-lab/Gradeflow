# ✨ AI Features - Start Here

## 🎯 What's Set Up

Your VS Code workspace is **ready for AI integration**! Here's what's configured:

### ✅ Launch Configurations
- **Flutter (Chrome)** - Normal mode (no AI)
- **Flutter (Chrome) + AI 🤖** - With AI features enabled

### ✅ Files Created
- `.vscode/launch.json` - Run configurations
- `.vscode/settings.json` - Environment setup (you'll edit this)
- `.vscode/tasks.json` - Helper tasks
- `.env` - Alternative configuration file
- `load-env.ps1` - PowerShell helper script
- `test-ai-config.ps1` - Test if AI is working

### ✅ Documentation
- `AI_SETUP_QUICK.md` ⭐ **Quick 2-minute guide**
- `SETUP_AI.md` - Complete setup guide
- `AI_INTEGRATION_GUIDE.md` - Technical details

---

## 🚀 Quick Start (Choose One Method)

### Method 1: VS Code Settings (Easiest!)

1. **Get OpenAI API Key**:
   - Visit: https://platform.openai.com/api-keys
   - Create account if needed
   - Click "Create new secret key"
   - Copy the entire key (starts with `sk-`)

2. **Add to VS Code**:
   - Open `.vscode/settings.json`
   - Scroll to the bottom
   - Find the commented AI section
   - Uncomment and paste your key:
   ```json
   "terminal.integrated.env.windows": {
     "OPENAI_API_KEY": "sk-your-actual-key-here"
   }
   ```
   - **Save the file** (Ctrl+S)

3. **Restart VS Code** completely:
   - Close all VS Code windows
   - Reopen your project

4. **Run with AI**:
   - Press **F5**
   - In the dropdown, select: **"Flutter (Chrome) + AI 🤖"**
   - Click the green play button

5. **Test it works**:
   ```powershell
   # In VS Code terminal:
   .\test-ai-config.ps1
   ```

### Method 2: Windows Environment Variable

```powershell
# In PowerShell (not as admin):
[Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "sk-your-key", "User")

# Restart VS Code completely
# Then press F5 and select the AI config
```

---

## 🎮 How to Use AI Features

Once running with the AI configuration:

### In Exam Input Screen
1. Upload exam scores (Excel/CSV/PDF)
2. If format is unclear → Click **"Try AI"** button
3. AI analyzes and extracts scores automatically

### In Calendar/Schedule Import
1. Import calendar file
2. On parsing errors → Click **"Try AI"**
3. AI interprets dates and events

---

## 🔍 Verify It's Working

### ✅ AI is Enabled:
- Launch config dropdown shows: `Flutter (Chrome) + AI 🤖`
- Import screens show "Try AI" buttons
- No "AI not configured" error messages

### ❌ AI is Disabled:
- Using regular "Flutter (Chrome)" config
- No AI buttons visible
- This is fine! App works perfectly without AI

---

## 💡 Tips

- **Cost**: ~$0.01-$0.05 per AI import (free $5 credit for new accounts)
- **Optional**: AI is a helper, not required - local parsers work great
- **Security**: Your API key stays on your machine only
- **Monitor**: Check usage at https://platform.openai.com/usage

---

## 🆘 Troubleshooting

### "AI is not configured" error
1. Did you select the **AI launch config** (with 🤖)?
2. Did you **restart VS Code** after adding the key?
3. Run the test script: `.\test-ai-config.ps1`

### Test script fails
1. Check the key is pasted correctly in settings.json
2. Make sure there are no extra spaces
3. Verify the JSON syntax is correct (no missing commas)

### Still not working?
See the full guide: **SETUP_AI.md**

---

## 📚 Next Steps

1. ✅ Set up your API key (see above)
2. ✅ Run with AI config
3. ✅ Test with an exam score import
4. 📖 Read `AI_INTEGRATION_GUIDE.md` for advanced usage

**That's it!** You're all set up for AI-powered imports 🎉
