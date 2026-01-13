# Google Drive Sign-In + Import (Flutter Web)

This project uses the Flutter package `google_sign_in` to authenticate on web and (optionally) download Drive-hosted files via a link.

## What Firebase does (and does not) do

- **Firebase Authentication (Google provider)** helps you sign in a user.
- **It does not automatically grant Google Drive API access.** Drive access requires requesting Drive scopes and configuring the **Google Cloud OAuth consent screen** for those scopes.

If you only want “import from a public link”, you can avoid OAuth entirely by using publicly shared links.

## Fastest path to a working dev sign-in (recommended)

1) Use a **personal Gmail** account for the first test.

If it works on Gmail but fails on a school/work account, you’re almost certainly hitting a **Google Workspace admin policy** (unverified app, restricted scopes, allowlist, etc.).

2) Ensure you are configuring the **same Google Cloud project** that owns this client ID:

- `641291373193-fuva602ciad653vruhvd69vj7pqvhdpi.apps.googleusercontent.com`

3) OAuth Consent Screen must allow your test account

In Google Cloud Console:
- **APIs & Services → OAuth consent screen**
  - If **Publishing status = Testing**:
    - Go to **Test users** and add the exact email you’re signing in with.
  - Confirm the app is **External** unless you are intentionally using a Workspace-only project.

4) Scopes

In OAuth consent screen configuration, add:
- `.../auth/userinfo.email`
- `.../auth/userinfo.profile`
- `https://www.googleapis.com/auth/drive.readonly`

Notes:
- Drive scopes are treated as sensitive/restricted depending on Google’s current classification. You can still use them in **Testing** with test users.

5) Enable the Drive API

In Google Cloud Console:
- **APIs & Services → Library**
- Enable **Google Drive API**

5b) Enable the People API (required by Google Sign-In on web)

If sign-in fails with a 403 mentioning `people.googleapis.com` / `SERVICE_DISABLED`, enable:
- **Google People API**

6) OAuth Client settings for local dev

In Google Cloud Console:
- **APIs & Services → Credentials → OAuth 2.0 Client IDs → (your Web client)**

Set:
- **Authorized JavaScript origins**:
  - `http://localhost:57054`

- **Authorized redirect URIs**:
  - For a typical SPA/Flutter web setup, this is often **not required** for Google Identity Services flows.
  - If your screen forces you to set one, use:
    - `http://localhost:57054`

### Important: do NOT add `storagerelay://...`

If the error page shows a `redirect_uri` like:
- `storagerelay://http/localhost:57054?id=...`

That is an internal relay mechanism used by Google’s web auth flow. You generally **cannot/should not** register custom schemes like `storagerelay://` as OAuth redirect URIs in Cloud Console.

When you see `403: access_denied` with Drive scopes, the most common root causes are:
- Consent screen is **Testing** and your account is **not in Test users**
- You’re using a **Workspace/school account** blocked by admin policies
- Consent screen **scopes were not actually added/saved**

## How to run GradeFlow on the expected localhost origin

```pwsh
flutter run -d chrome --web-port 57054
```

## If you still see `403 access_denied`

Check these in order:

1) **Testing → Test users**
- Add the signing-in email.

2) **Try personal Gmail**
- If Gmail works but school account fails, ask your Workspace admin to allow/approve the app (or move the project to that Workspace and use an Internal consent screen).

3) Confirm you’re using the right client ID
- `web/index.html` contains `<meta name="google-signin-client_id" ...>`
- `lib/google/google_config.dart` contains `GoogleConfig.webClientId`

4) Confirm scopes are present in the consent screen
- Drive scope must appear under the consent screen scopes.

5) Clear cached sessions
- Sign out in the app, clear site data for `localhost`, and try again.

## What to paste back if you’re stuck

Paste:
- The full 403 URL (it includes `scope=...`)
- Your OAuth consent screen: Publishing status, User type, Test users
- Your Credentials page: Authorized JavaScript origins
