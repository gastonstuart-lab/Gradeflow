# Deployment Guide - GradeFlow

This guide covers deploying GradeFlow to various platforms.

---

## 📦 Pre-Deployment Checklist

Before deploying to any platform:

- [ ] Test thoroughly in development mode
- [ ] Update version in `pubspec.yaml`
- [ ] Update `CHANGELOG.md`
- [ ] Run `flutter analyze` (ensure no errors)
- [ ] Test light and dark themes
- [ ] Test on target platform (web/mobile)
- [ ] Commit all changes to version control

---

## 🌐 Web Deployment

### Option 1: Firebase Hosting (Recommended)

**Advantages**: Free tier, CDN, SSL, custom domains, easy rollbacks

#### First-Time Setup

1. **Install Firebase CLI**
   ```powershell
   npm install -g firebase-tools
   ```

2. **Login to Firebase**
   ```powershell
   firebase login
   ```

3. **Initialize Firebase**
   ```powershell
   firebase init hosting
   ```
   
   Select:
   - ✅ Hosting
   - Public directory: `build/web`
   - Configure as SPA: `Yes`
   - Set up automatic builds: `No` (we'll build manually)

4. **Update firebase.json** (already configured in project)

#### Deploy

```powershell
# 1. Build for production
.\scripts\build-web.ps1

# 2. Test locally (optional)
firebase serve

# 3. Deploy
firebase deploy

# Your app will be live at:
# https://your-project.web.app
```

#### Custom Domain

1. Go to Firebase Console → Hosting
2. Click "Add custom domain"
3. Follow DNS configuration instructions
4. Wait for SSL certificate (15 minutes - 24 hours)

---

### Option 2: Netlify

**Advantages**: Simple drag-and-drop, automatic builds from Git, free tier

#### Manual Deploy

1. **Build**
   ```powershell
   .\scripts\build-web.ps1
   ```

2. **Install Netlify CLI**
   ```powershell
   npm install -g netlify-cli
   ```

3. **Login**
   ```powershell
   netlify login
   ```

4. **Deploy**
   ```powershell
   netlify deploy --prod --dir=build/web
   ```

#### Git-Based Deploy

1. Push code to GitHub/GitLab/Bitbucket
2. Connect repository in Netlify dashboard
3. Configure build:
   - Build command: `flutter build web --release`
   - Publish directory: `build/web`
4. Deploy automatically on every push

---

### Option 3: GitHub Pages

**Advantages**: Free, simple for public repositories

1. **Build**
   ```powershell
   flutter build web --release --base-href "/gradeflow/"
   ```

2. **Copy to gh-pages branch**
   ```powershell
   git checkout --orphan gh-pages
   git rm -rf .
   Copy-Item -Path build/web/* -Destination . -Recurse
   git add .
   git commit -m "Deploy to GitHub Pages"
   git push origin gh-pages --force
   git checkout main
   ```

3. **Enable in Settings**
   - Go to repository → Settings → Pages
   - Source: Deploy from branch `gh-pages`
   - Your app: `https://yourusername.github.io/gradeflow/`

---

### Option 4: Vercel

1. **Install Vercel CLI**
   ```powershell
   npm install -g vercel
   ```

2. **Build**
   ```powershell
   .\scripts\build-web.ps1
   ```

3. **Deploy**
   ```powershell
   vercel --prod build/web
   ```

---

## 🤖 Android Deployment

### Option 1: Direct APK Distribution

**Use case**: Internal testing, beta users, side-loading

1. **Build APK**
   ```powershell
   .\scripts\build-android.ps1
   ```

2. **Locate APK**
   ```
   build/app/outputs/flutter-apk/
   ├── app-armeabi-v7a-release.apk  (32-bit ARM)
   ├── app-arm64-v8a-release.apk    (64-bit ARM, most common)
   └── app-x86_64-release.apk       (x86 64-bit)
   ```

3. **Distribute**
   - Email to users
   - Upload to cloud storage
   - Host on your website

4. **Installation** (users must enable "Unknown Sources")
   ```
   Settings → Security → Unknown Sources → Enable
   ```

---

### Option 2: Google Play Store

**Use case**: Public distribution, updates, monetization

#### Prerequisites

1. **Create Google Play Developer Account** ($25 one-time fee)
   - Go to [Google Play Console](https://play.google.com/console)

2. **Generate Signing Key**
   ```powershell
   # Create keystore
   keytool -genkey -v -keystore c:\Dev\gradeflow-release-key.jks `
     -keyalg RSA -keysize 2048 -validity 10000 `
     -alias gradeflow

   # Remember the passwords!
   ```

3. **Configure Signing**
   
   Create `android/key.properties`:
   ```properties
   storePassword=<your-store-password>
   keyPassword=<your-key-password>
   keyAlias=gradeflow
   storeFile=c:/Dev/gradeflow-release-key.jks
   ```

   ⚠️ **Add to .gitignore** (already configured)

4. **Build AAB (App Bundle)**
   ```powershell
   flutter build appbundle --release
   ```

5. **Output**: `build/app/outputs/bundle/release/app-release.aab`

#### Upload to Play Store

1. **Create App in Play Console**
   - App name: GradeFlow
   - Category: Education
   - Content rating: Complete questionnaire

2. **Production Track**
   - Upload `app-release.aab`
   - Add release notes
   - Set version name/code

3. **Store Listing**
   - App description (use from README)
   - Screenshots (minimum 2)
   - Feature graphic (1024x500)
   - App icon (512x512)

4. **Content Rating & Pricing**
   - Complete content rating questionnaire
   - Set pricing (Free or Paid)

5. **Review & Publish**
   - Review takes 1-7 days
   - App goes live automatically after approval

---

## 🍎 iOS Deployment

### Prerequisites

1. **Apple Developer Account** ($99/year)
2. **Mac with Xcode** (required for iOS builds)
3. **iOS Device** (for testing)

### Build & Deploy

1. **Open Project in Xcode**
   ```bash
   cd ios
   open Runner.xcworkspace
   ```

2. **Configure Signing**
   - Select Runner target
   - Signing & Capabilities tab
   - Select your team
   - Change Bundle Identifier: `com.gradeflow.app`

3. **Update Version**
   - General tab
   - Version: `1.0.0`
   - Build: `1`

4. **Build Archive**
   ```bash
   flutter build ios --release
   ```
   
   Or in Xcode:
   - Product → Archive
   - Wait for archive to complete

5. **Distribute**
   - Window → Organizer
   - Select archive
   - Click "Distribute App"
   - Choose:
     - **App Store Connect** (public release)
     - **Ad Hoc** (beta testing, up to 100 devices)
     - **Development** (internal testing)

6. **Upload to App Store**
   - Follow Xcode wizard
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Create new app
   - Fill in metadata
   - Submit for review

### TestFlight (Beta Testing)

1. Upload build to App Store Connect
2. TestFlight tab
3. Add external testers (up to 10,000)
4. Testers install via TestFlight app

---

## 🖥️ Desktop Deployment (Experimental)

### Windows

```powershell
flutter build windows --release
```

Output: `build/windows/runner/Release/`

Create installer with [Inno Setup](https://jrsoftware.org/isinfo.php)

### macOS

```bash
flutter build macos --release
```

Output: `build/macos/Build/Products/Release/gradeflow.app`

Create DMG installer

### Linux

```bash
flutter build linux --release
```

Output: `build/linux/x64/release/bundle/`

Create AppImage or Snap package

---

## 🔄 Continuous Deployment

### GitHub Actions (Web)

Create `.github/workflows/deploy-web.yml`:

```yaml
name: Deploy Web

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.32.8'
      
      - run: flutter pub get
      - run: flutter build web --release
      
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          channelId: live
          projectId: your-firebase-project
```

---

## 🧪 Staging vs Production

### Staging Environment

1. Create separate Firebase project: `gradeflow-staging`
2. Build with staging config:
   ```powershell
   flutter build web --release --dart-define=ENV=staging
   ```
3. Deploy: `firebase deploy --project gradeflow-staging`

### Production Environment

1. Use main Firebase project: `gradeflow-prod`
2. Build: `flutter build web --release`
3. Deploy: `firebase deploy --project gradeflow-prod`

---

## 📊 Post-Deployment

### Monitor

- **Firebase**: Analytics, Performance, Crashlytics
- **Play Console**: Crashes, ANRs, ratings
- **App Store Connect**: Crashes, reviews

### Update Strategy

1. **Minor Updates** (bug fixes): Deploy immediately
2. **Major Updates** (features): Test on staging first
3. **Breaking Changes**: Inform users, provide migration guide

### Rollback

- **Firebase**: `firebase hosting:rollback`
- **Play Store**: Promote previous version
- **App Store**: Request expedited review of fixed version

---

## ✅ Deployment Verification

After deploying, verify:

- [ ] App loads correctly
- [ ] Login works (demo mode)
- [ ] Create class
- [ ] Import students
- [ ] Enter grades
- [ ] Export works
- [ ] Theme switching works
- [ ] Responsive on different screen sizes
- [ ] No console errors
- [ ] Performance is acceptable

---

## 🆘 Troubleshooting

### "Failed to load resource" errors

**Solution**: Check `base-href` in build command:
```powershell
flutter build web --release --base-href "/"
```

### White screen on load

**Solution**: 
1. Check browser console for errors
2. Verify `index.html` loads correctly
3. Clear browser cache
4. Check CORS if loading external resources

### App crashes on startup

**Solution**:
1. Check for initialization errors in `main.dart`
2. Verify all services initialize correctly
3. Test on physical device, not just emulator

---

**Happy Deploying! 🚀**

For questions, refer to platform-specific documentation:
- [Firebase Hosting](https://firebase.google.com/docs/hosting)
- [Google Play Console](https://support.google.com/googleplay/android-developer)
- [App Store Connect](https://developer.apple.com/app-store-connect/)
