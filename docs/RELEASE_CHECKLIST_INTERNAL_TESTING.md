# Ludo Friends — Play Store Internal Testing Release Checklist

Branch: **`claude-fb`** (current multiplayer / friends / matchmaking build).
Rollback branch: **`claude-3d`**.
Android package: **`com.arifurrahman.ludofriends`**.
Production API: **https://db.ludogame.dronescan.pro/api/v1**.
Legal site: **https://db.ludogame.dronescan.pro**

---

## 0. Production values (single source of truth)

| Key | Value |
|-----|-------|
| Reverb server port | **8081** (not 8080) |
| `REVERB_HOST` | `ws.ludogame.dronescan.pro` |
| `REVERB_APP_KEY` | `ludo-prod-key-2026` |
| Flutter `WS_HOST` | `ws.ludogame.dronescan.pro` |
| Flutter `WS_PORT` | `443` |
| Flutter `WS_TLS` | `true` |
| Flutter `WS_KEY` | `ludo-prod-key-2026` |

Server `.env` (Reverb section) must read:

```
REVERB_HOST=ws.ludogame.dronescan.pro
REVERB_APP_KEY=ludo-prod-key-2026
REVERB_PORT=443
REVERB_SCHEME=https
REVERB_SERVER_HOST=127.0.0.1
REVERB_SERVER_PORT=8081
```

> The client connects to `wss://ws.ludogame.dronescan.pro:443`; Nginx terminates
> TLS and proxies to the local Reverb process on **8081**.

---

## 1. Backend deploy (VPS)

```bash
ssh arif@87.106.236.129
cd /var/www/ludofriends
git fetch origin
git switch claude-fb
git pull --ff-only origin claude-fb
cd backend
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan optimize:clear
php artisan config:cache
php artisan route:cache
php artisan event:cache
sudo supervisorctl restart ludo-queue:* ludo-reverb
sudo systemctl reload nginx
```

`php artisan migrate --force` will apply the new
`create_account_deletion_requests` migration (additive; safe).

### After editing the server `.env` (e.g. adding Google keys)

```bash
php artisan optimize:clear
php artisan config:cache
php artisan route:cache
php artisan event:cache
sudo supervisorctl restart ludo-queue:* ludo-reverb
```

### Required `.env` additions for Google Sign-In

```
GOOGLE_LOGIN_ENABLED=true
GOOGLE_CLIENT_ID_WEB=PASTE_WEB_CLIENT_ID
GOOGLE_CLIENT_ID_ANDROID=PASTE_ANDROID_CLIENT_ID
GOOGLE_CLIENT_ID_IOS=
```

Facebook (already configured, verify present):

```
FACEBOOK_LOGIN_ENABLED=true
FACEBOOK_APP_ID=2582636912564874
FACEBOOK_APP_SECRET=***set on server only***
FACEBOOK_GRAPH_VERSION=v19.0
```

---

## 2. Release signing — REQUIRED before building the AAB

Google Play **rejects debug-signed** uploads. `android/app/build.gradle.kts`
currently signs release with the debug key (fine for `flutter run`, not for
Play). Create an upload keystore once:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```

Create `app/android/key.properties` (DO NOT COMMIT — add to .gitignore):

```
storePassword=********
keyPassword=********
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

Wire it in `app/android/app/build.gradle.kts` (release `signingConfig`):

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else signingConfigs.getByName("debug")
        }
    }
}
```

Keep the keystore + passwords safe and backed up. Losing the upload key means
you must request an upload-key reset from Google (Play App Signing keeps signing
end users, so the app can still update).

> Bump `version:` in `app/pubspec.yaml` for every Play upload
> (`1.0.0+1` → `1.0.0+2` → …). Play requires a unique `versionCode`.

---

## 3. Flutter debug run (USB device)

```bash
cd C:\Arifur-File\ROEL\ludofriend\LudoFriend\app
flutter clean
flutter pub get
flutter run --dart-define=APP_ENV=prod --dart-define=API_BASE_URL=https://db.ludogame.dronescan.pro/api/v1 --dart-define=WS_HOST=ws.ludogame.dronescan.pro --dart-define=WS_PORT=443 --dart-define=WS_TLS=true --dart-define=WS_KEY=ludo-prod-key-2026 --dart-define=FACEBOOK_ENABLED=true --dart-define=GOOGLE_ENABLED=true
```

> ⚠ **Google Sign-In also needs the Web client id** passed as
> `GOOGLE_SERVER_CLIENT_ID`, or Android will not return an ID token for the
> backend and login will fail with "Google did not return an ID token".
> Add this define to both the run and build commands:
>
> `--dart-define=GOOGLE_SERVER_CLIENT_ID=PASTE_WEB_CLIENT_ID`
>
> (iOS later: `--dart-define=GOOGLE_IOS_CLIENT_ID=PASTE_IOS_CLIENT_ID`.)
> `GOOGLE_CLIENT_ID_WEB` on the server and `GOOGLE_SERVER_CLIENT_ID` in the app
> must be the **same Web OAuth client id** (that's the token audience the
> backend verifies).

Full command with Google working:

```bash
flutter run --dart-define=APP_ENV=prod --dart-define=API_BASE_URL=https://db.ludogame.dronescan.pro/api/v1 --dart-define=WS_HOST=ws.ludogame.dronescan.pro --dart-define=WS_PORT=443 --dart-define=WS_TLS=true --dart-define=WS_KEY=ludo-prod-key-2026 --dart-define=FACEBOOK_ENABLED=true --dart-define=GOOGLE_ENABLED=true --dart-define=GOOGLE_SERVER_CLIENT_ID=PASTE_WEB_CLIENT_ID
```

---

## 4. Flutter Play Store AAB build

```bash
flutter clean
flutter pub get
flutter build appbundle --release --dart-define=APP_ENV=prod --dart-define=API_BASE_URL=https://db.ludogame.dronescan.pro/api/v1 --dart-define=WS_HOST=ws.ludogame.dronescan.pro --dart-define=WS_PORT=443 --dart-define=WS_TLS=true --dart-define=WS_KEY=ludo-prod-key-2026 --dart-define=FACEBOOK_ENABLED=true --dart-define=GOOGLE_ENABLED=true --dart-define=GOOGLE_SERVER_CLIENT_ID=PASTE_WEB_CLIENT_ID
```

AAB output:

```
app/build/app/outputs/bundle/release/app-release.aab
```

---

## 5. On-device testing checklist

- [ ] Facebook login
- [ ] Google login (shows account picker → returns to Home)
- [ ] Guest login
- [ ] Home screen — no overflow
- [ ] Board shows player name + photo
- [ ] Create private room
- [ ] Join room by code
- [ ] Start shared match
- [ ] Dice / move sync between two devices
- [ ] Chat / emoji sync
- [ ] Friends list persists after a match
- [ ] Invite a friend from the friends list
- [ ] Invited user sees "Play with {name}?"
- [ ] Random matchmaking
- [ ] Bot fallback when no opponents
- [ ] Leaderboard / profile basics
- [ ] No 404 on `/friends`, `/rooms`, `/matchmaking` routes
- [ ] Reverb running (WS connects, live updates)
- [ ] Queue workers running
- [ ] Scheduler running
- [ ] Settings → Legal → Privacy / Terms / Data deletion open in browser

---

## 6. Play Console checklist

- [ ] Create an **Internal testing** release
- [ ] Upload `app-release.aab`
- [ ] Add tester Google/Gmail account addresses
- [ ] Copy the opt-in link and share with testers
- [ ] Complete the **Data safety** section accurately (see mapping below)
- [ ] Add privacy policy URL: `https://db.ludogame.dronescan.pro/privacy`
- [ ] App category: **Game / Board**
- [ ] Content rating questionnaire
- [ ] Store listing: `docs/store-assets/play_icon_512.png`,
      `docs/store-assets/feature_graphic_1024x500.png`, screenshots
- [ ] Contact email: `hatbazar627@gmail.com`
- [ ] App integrity → App signing → copy the **SHA-1**
- [ ] Add that **Play App Signing SHA-1** to the Google Cloud **Android OAuth
      client** (required for Google Sign-In on Play builds)
- [ ] Convert the Play App Signing SHA-1 to a **Facebook key hash** and add it in
      the Meta dashboard
- [ ] Keep the **debug** key hashes too (for USB testing)

**Data safety mapping** (what the app actually collects):
Name; Email (optional, via Google); User IDs (Google/Facebook profile id);
Photos (profile avatar URL); App activity (gameplay, friends, matches);
App info & performance (crash/diagnostics). Data is **encrypted in transit
(HTTPS)** and users can **request deletion** (in-app + web). Not collected:
location, contacts, mic/camera, Gmail/Drive.

---

## 7. Meta / Facebook checklist

- [ ] App mode: **Development** (add testers in App Roles) or **Live**
- [ ] Android platform → package `com.arifurrahman.ludofriends`
- [ ] Class: `com.arifurrahman.ludofriends.MainActivity`
- [ ] Key hashes: Windows debug, Mac debug (if used), and **Play App Signing** hash
- [ ] Privacy URL: `https://db.ludogame.dronescan.pro/privacy`
- [ ] Terms URL: `https://db.ludogame.dronescan.pro/terms`
- [ ] User Data Deletion URL: `https://db.ludogame.dronescan.pro/data-deletion`
- [ ] Login permissions: **public_profile only**
- [ ] Do **not** request `user_friends` until approved by Meta App Review

Generate a Facebook key hash from a keystore SHA-1 (or directly):

```bash
keytool -exportcert -alias upload -keystore upload-keystore.jks \
  | openssl sha1 -binary | openssl base64
```

---

## 8. Google (Cloud Console) checklist

- [ ] Project created/selected for Ludo Friends
- [ ] OAuth consent screen configured (App name **Ludo Friends**; support +
      developer email `hatbazar627@gmail.com`)
- [ ] Privacy URL `https://db.ludogame.dronescan.pro/privacy` + Terms URL
      `https://db.ludogame.dronescan.pro/terms` added
- [ ] App domain: `db.ludogame.dronescan.pro`
- [ ] Test users added if the OAuth app is in **Testing** mode
- [ ] **Android OAuth client**: package `com.arifurrahman.ludofriends` +
      SHA-1 (Windows debug, Mac debug if used, **Play App Signing**)
- [ ] **Web OAuth client** created (used as the token audience)
- [ ] `GOOGLE_CLIENT_ID_WEB` + `GOOGLE_CLIENT_ID_ANDROID` in server `.env`
- [ ] Server config cache rebuilt (`php artisan config:cache`)
- [ ] App built with `GOOGLE_SERVER_CLIENT_ID=<Web client id>`
- [ ] Google login tested from USB debug **and** from the Play internal build
- [ ] No Gmail API enabled (sign-in only — no mailbox/Drive/Contacts scopes)

---

## 9. Common failures → fixes

| Symptom | Cause / fix |
|---------|-------------|
| `401` on a protected route | Expected when unauthenticated — not a bug |
| `404` on `/friends`, `/rooms`, `/matchmaking` | Branch not deployed — deploy `claude-fb` |
| WebSocket won't connect | `WS_HOST`/`WS_KEY`/Reverb port (8081)/Nginx mismatch |
| FB "invalid key hash" | Add debug + Play App Signing key hashes in Meta |
| FB "invalid scope" | `user_friends` requested — keep `public_profile` only |
| Google `ApiException: 10` | Wrong package/SHA-1/OAuth client, or missing `GOOGLE_SERVER_CLIENT_ID` |
| Google "issued for a different app" | Web client id ≠ `GOOGLE_CLIENT_ID_WEB` on server |
| Play rejects AAB "signed in debug mode" | Set up the release/upload keystore (section 2) |
