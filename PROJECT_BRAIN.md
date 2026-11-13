# PaidiX — Project Brain (canonical agent context)

**Read this file first.** It is the source of truth for architecture, routing, Gradle, domain rules, and file locations. Do **not** recursively scan `lib/`, `android/`, or `build/` unless a task requires editing a specific file listed here.

- **Maintained as of:** 2026-11-11
- **App version:** `1.0.1+2` (`pubspec.yaml`)
- **Flutter package name:** `paidix`
- **Product:** Global invoice / incoming-payment / spending platform. Tagline: *Move Money. Build Trust.*
- **Current stage:** Production-grade Flutter application with zero hardcoded demo data. Full backend and authentication integration ready (`ApiClient`, `AuthRepository`, `KycRepository`, secure storage token persistence, and isolated test fixtures in `test/test_fixtures.dart`).

When you change behavior, **update this file in the same change** (routes, formulas, Gradle, new features, invariants).

---

## 0. How agents should work

1. Answer from this brain. Open source files only for the files you will edit.
2. Flutter app root is **`PaidiX/`** (nested). Workspace root is the parent folder that also contains `.agents/` and `.idea/`.
3. Ignore generated trees: `build/`, `.dart_tool/`, `android/.gradle/`, `*/ephemeral/`.
4. Default theme is **light** (with toggle in profile menu dialog and Appearance settings). Sidebar chrome is **never inverted** (`AppColors.sidebar*`).
5. Prefer `AppColors.of(context)` in widgets; static `AppColors.*` getters follow `themeModeNotifier` (default `ThemeMode.light`).
6. Empty money values render as **`—`** (`AppFormatters`). Do not invent demo transactions.
7. After UI/logic changes: `flutter test` from `PaidiX/`. Theme token tests live in `test/theme_test.dart`.

---

## 1. Repository layout

```
<workspace>/                          Cursor workspace
├── AGENTS.md                         Pointer: read this brain
├── .cursor/rules/paidix-project-brain.mdc
├── .agents/skills/                   Gravitas skills (not app code)
└── PaidiX/                           FLUTTER APP ROOT  ← dart/gradle live here
    ├── pubspec.yaml
    ├── analysis_options.yaml         lints: package:lints/recommended.yaml
    ├── PROJECT_BRAIN.md              THIS FILE
    ├── README.md                     Marketing/UI summary (can lag this file)
    ├── CHANGELOG.md                  "1.0.0 Initial version"
    ├── lib/                          All Dart application code (~57 files)
    ├── test/                         24 test files (23 test suites + test_fixtures.dart)
    ├── android/                      Gradle + Kotlin host
    ├── ios/  web/  windows/ macos/ linux/   Flutter platform shells
```

**No** `assets/` in `pubspec.yaml`. **No** `lib/features/auth/data/`. **No** Riverpod / Bloc / GetX / Dio.

---

## 2. Stack & dependencies

| Layer | Choice |
| :--- | :--- |
| UI | Flutter Material 3 via standalone `material_ui` `^1.11.0`, `MaterialApp.router` |
| Routing | `go_router` `^18.1.4` |
| State | Widget local `setState` + one shared `ValueNotifier` on payments |
| Network & HTTP | `http` `^1.2.2`, `ApiClient` (`lib/core/network/api_client.dart`) with Bearer auth token injection & multipart upload |
| Secure Storage | `flutter_secure_storage` `^10.3.4` for JWT session token persistence; v10 is the required data migration step before any v11 upgrade |
| Config | `AppConfig` (`lib/core/config/app_config.dart`) via compile-time `--dart-define` |
| Images | `image_picker` `^1.2.4` (KYC only) |
| Permissions | `permission_handler` `^13.0.2` |
| Notifications | `flutter_local_notifications` `^23.0.1` (Android channel `paidix_kyc_channel`) |
| Icons | `cupertino_icons` `^2.0.0` |
| Fonts | `google_fonts` `^9.0.0` |
| SDK | Dart `>=3.13.0 <4.0.0`, Flutter `>=3.47.0` (required by standalone `material_ui`) |
| Lint | `flutter_lints` `^6.0.0` via `package:lints/recommended.yaml` |
| Analyzer excludes | `build/**`, `android/**`, `ios/**`, `web/**`, `windows/**`, `macos/**`, `linux/**` |

---

## 3. Android / Gradle (exact)

All paths relative to `PaidiX/android/`.

### 3.1 `settings.gradle.kts`

- Resolves Flutter SDK from `local.properties` → `flutter.sdk` (required).
- `includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")`
- Plugins: `dev.flutter.flutter-plugin-loader` **1.0.0**, `com.android.application` **9.5.1** (apply false), `org.jetbrains.kotlin.android` **2.4.0** (apply false)
- Single module: `:app`

### 3.2 Root `build.gradle.kts`

- Repos: `google()`, `mavenCentral()`
- Redirects Gradle `buildDirectory` to **`PaidiX/build`** (`../../build` from `android/`)
- Subprojects evaluate after `:app`
- `clean` deletes that redirected build dir

### 3.3 `app/build.gradle.kts`

| Key | Value |
| :--- | :--- |
| namespace / applicationId | `com.paidix.paidix` |
| compileSdk | **37** |
| ndkVersion | `flutter.ndkVersion` |
| minSdk / targetSdk | `flutter.minSdkVersion` / `flutter.targetSdkVersion` |
| versionCode / versionName | from Flutter (`pubspec`) |
| Java | **17** source/target |
| Kotlin jvmTarget | **JVM_17** |
| Core library desugaring | **enabled** — `com.android.tools:desugar_jdk_libs:2.1.4` (needed by notifications) |
| Release signing | **debug keys** (TODO in file: add real signing) |
| Flutter source | `../..` (the `PaidiX/` Flutter root) |

### 3.4 `gradle.properties`

```
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m ...
android.useAndroidX=true
android.suppressUnsupportedCompileSdk=37.0
android.newDsl=false
android.builtInKotlin=false
# Multi-drive Windows Kotlin incremental compilation fix (C:\ pub cache vs D:\ project)
kotlin.incremental=false
kotlin.incremental.android=false
kotlin.incremental.jvm=false
```

### 3.5 Wrapper

`gradle-wrapper.properties` → **Gradle 9.6.0-bin**. `DEFAULT_JVM_OPTS` in `gradlew.bat` and `gradlew` sets `--enable-native-access=ALL-UNNAMED` to eliminate Java 25+ JEP 472 restricted method (`System.load`) warnings from `net.rubygrapefruit.platform`.

### 3.6 Manifests & host

**`app/src/main/AndroidManifest.xml`**

- Permissions: `CAMERA`, `READ_EXTERNAL_STORAGE` (maxSdk 32), `WRITE_EXTERNAL_STORAGE` (maxSdk 32), `READ_MEDIA_IMAGES`, `POST_NOTIFICATIONS`
- Label: `PaidiX`, icon `@mipmap/ic_launcher`, roundIcon `@mipmap/ic_launcher_round`
- Adaptive Icons: `mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_round.xml` with `@color/ic_launcher_background` (`#022F32`) and centered safe-zone `@mipmap/ic_launcher_foreground`
- Activity: `.MainActivity`, `singleTop`, `adjustResize`, Flutter embedding **2**
- **Impeller:** Explicitly disabled via `<meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false" />` in `AndroidManifest.xml` to prevent fatal Mali/Kirin ion driver failures (`ioctl c0044901 failed with code -1`, `Gralloc3 allocator 3.x is not supported`, and `OpenGLRenderer Davey!` 10s hangs) on Huawei EMUI 10.1 / HarmonyOS devices, using Skia OpenGLES for 100% stable hardware rendering.
- `<queries>`: `PROCESS_TEXT`, `VIEW https`, plus package-visibility intents for the image picker / camera (`GET_CONTENT image/*`, `PICK image/*`, `IMAGE_CAPTURE`) so OEM builds (Huawei EMUI/HarmonyOS) don't hide the gallery/camera app from `image_picker`

**`MainActivity.kt`** (`com.paidix.paidix`): `FlutterActivity` uses `RenderMode.surface` (`SurfaceView`) so Android's WindowManager and `SurfaceFlinger` allocate and manage hardware surfaces directly, bypassing TextureView/Gralloc3 ion allocator failures. It re-arms SurfaceView attachments on resume/focus, verifies Dart post-frame rendering via the `com.paidix.paidix/lifecycle` channel (`verifyFrameRendered`), and recovers from detached surfaces. The render watchdog does not restart a cold debug launch before its first frame, allowing IDE launches with `--start-paused` to resume. Picker returns receive a 12-second render grace plus two 5-second recovery checks before the existing restart fallback, and a restart blocked by cooldown is rechecked after the cooldown instead of being abandoned. Android may reclaim the activity while an external picker is open; KYC lost-result recovery therefore runs in `main()` (bounded by startup timeouts alongside `ApiClient.initSession()` and `UserProfileRepository.init()`) before the initial route, independent of the current screen. A persisted target (`avatar`, `selfie`, `cnic_front`, or `cnic_back`) identifies the correct field; KYC and profile lost-result readers use `KycMediaRecovery` so concurrent screens cannot consume or misroute one result. Startup recovery only reads Android's shared lost-result slot when a KYC/profile picker target was recorded, preserving results owned by other features. Recovered KYC images update the profile cache and the active wizard state. Huawei image downscaling requests a bounded codec frame directly instead of decoding full-resolution images to inspect dimensions. KYC picker requests cap dimensions at 1600px and quality 88; settings avatar/document picks retain their separate 1024x1024, quality-80 constraints.

**Debug/profile manifests:** include `INTERNET` for hot reload. The main manifest
also declares `INTERNET`, which is required by release APKs for HTTPS API access.

**Splash & Brand Colors:** light `#EFF3F0`, night `#031415`, icon background `#022F32` (`values/colors.xml`, `values-night/colors.xml`). Launch drawables exist for both.

**Android Release APK:** `release/PaidiX.apk` is the tracked universal release artifact (version `1.0.1+2`; latest build approximately 56.7 MB). `.github/workflows/build_android.yml` pins Flutter 3.47.8, builds the APK on pushes to `main`, uploads it as a workflow artifact, and publishes it as a GitHub Release asset. Release builds currently use the debug signing key and are not production-signing-ready. The iOS project source remains in `ios/`; automated iOS IPA publishing is disabled.

**TODOs still in Gradle:** unique applicationId comment (ID is already `com.paidix.paidix`); release signing config.

---

## 4. Other platforms

| Platform | Status |
| :--- | :--- |
| **iOS** | Flutter template. Display name `Paidix`. **Info.plist has no `NSCameraUsageDescription` / photo-library usage strings.** Camera/gallery KYC will fail App Store / iOS permission prompts until added. |
| **Web / Windows / macOS / Linux** | Stock Flutter shells. App is designed around Android + responsive tablet widths (`>= 768`). |

---

## 5. Architecture

Feature-first, thin domain:

```
lib/
├── main.dart                 Binding + global async error print; runApp(PaidiXApp)
├── app/
│   ├── app.dart              MaterialApp.router + ThemeMode listener
│   ├── router.dart           go_router + sharedPaymentsRepository
│   └── theme/                colors, theme, typography, spacing, motion
├── core/
│   ├── config/app_config.dart (API Base URL, client API keys via compile-time --dart-define)
│   ├── network/api_client.dart (Resilient HTTP client, Bearer JWT injection, multipart streaming, timeouts)
│   ├── services/notification_service.dart
│   ├── utils/                formatters, payment validators, CNIC
│   └── widgets/              shell, app_back_navigation.dart, buttons, fields, badges, nav
└── features/
    ├── auth/                 domain models, AuthRepository (live API & offline fallback), validators, sign in/up pages
    ├── kyc/                  models, KycRepository (multipart KYC upload & offline fallback), image processor, 4-step UI
    ├── dashboard/            models + impl wrapping payments repo + page
    ├── payments/             models, abstract repo, in-memory impl, list + new form
    └── settings/             Account Settings (Profile, Security, Bank Accounts, Payments PIN, Appearance)
```

**Dependency direction:** `dashboard` → `payments` repository. Pages under `/app/*` receive `PaymentsRepositoryImpl` (concrete) so they can listen to `paymentsListenable`.

**Shared singleton (process memory, not DI):**

```dart
// lib/app/router.dart
final sharedPaymentsRepository = PaymentsRepositoryImpl();
final appRouter = createAppRouter(initialLocation: '/signin');
```

Tests that need a clean router should call `createAppRouter(...)` with a fresh location; production uses `appRouter`.

**Backend & Authentication Integration:**

- Any valid configured API base URL, including staging, is live. KYC upload code may simulate progress only in tests or when explicitly overridden; staging must not silently update the local profile without making an HTTP request.
PaidiX supports both live server communication and offline persistent state with zero hardcoded demo data:
- **Live Mode:** Configured with default base URL `https://201.79.42.93.nip.io/api/v1` in `lib/core/config/app_config.dart` (or via `--dart-define=API_BASE_URL=...`); the default is compiled into ordinary builds, so a Flutter `.env` file is not required. `CLIENT_API_KEY` is optional and omitted when empty (`clientApiKey.isEmpty ? null : clientApiKey`). `ApiClient` manages automatic double-token storage (`paidix_auth_jwt_token` for 60-minute access token and `paidix_auth_refresh_token` for 7-day refresh token in `FlutterSecureStorage`), with silent refresh on 401 `token_not_valid` (`POST /auth/refresh/`). Concurrent expired requests share one refresh, successful refresh may rotate both tokens, and each original request is retried at most once. Session generations prevent delayed responses or refreshes from a previous login from replaying with or invalidating a newer user's session. A rejected refresh (401), or a protected endpoint returning an explicit account unavailable code (`account_not_found`, account/user deleted or inactive codes), clears tokens and emits a session invalidation event; the app clears active profile/payment state, routes to `/signin`, and explains the session loss. Network/timeouts/server errors and unrelated permission failures preserve the session. The existing 5-second `GET /accounts/profile/` poll surfaces explicit server review changes while the app is open. Account deletion is detected only when the server rejects a protected request or refresh; without a push channel or a server rejection, the mobile app cannot observe the deletion immediately. Public auth endpoints use `includeAuth: false` (preventing stale Bearer tokens from causing `401 token_not_valid` on `/auth/email/resend/`), and Django REST framework errors support `{detail, code}`, `{error, message}` or nested `{error: {code, message}}`, snake_case error codes, and field error dictionaries. The single-token setter clears any refresh token left by a previous user.
- **Authentication Endpoints:**
  - `POST /auth/signup/request-otp/` & `POST /auth/email/verify/` & `POST /auth/email/resend/`: Registration, 6-digit OTP verification dialog, and code resend.
  - `POST /auth/login/`: SimpleJWT authentication returning `access` and `refresh` tokens, profile completeness, and KYC status (`approved`, `pending`, `draft`, `rejected`).
  - `POST /auth/logout/`: Revokes active refresh token and cleans local storage.
  - `GET /auth/me/` & `PATCH /auth/me/`: Current profile retrieval and live profile updates (with multipart `profile_picture` avatar upload using `PATCH` + `POST` 405/501 fallback, clear support, and realtime `avatarUrl` sync across `UserProfileRepository`, `AccountSettingsPage`, and `AppShell`).
  - `POST /auth/forgot-password/request-otp/` & `POST /auth/forgot-password/reset/`: Password recovery flow.
  - `POST /auth/change-password/`: Authenticated user password update.
  - `GET /auth/payments-pin/`, `POST /auth/payments-pin/`, `DELETE /auth/payments-pin/`, `POST /auth/payments-pin/verify/`, `POST /auth/payments-pin/forgot/`: Payments PIN lifecycle, verification, and authenticated email recovery. Forgot-PIN body is `{"email":"..."}`; the email must match the current authenticated account, success returns `detail`, and the API rate-limits reset attempts (429). Before PIN operations, the app confirms `email_verified` from `GET /auth/me/`; the backend must enforce the same policy. Never route PIN recovery through password-reset APIs.
  - `GET /accounts/cnic-available/?cnic=...`: Live real-time CNIC availability check during KYC Step 2.
  - `POST /accounts/process-img/`: Server-side enhancement & auto-crop for regulatory documents.
  - `GET /banking/banks/pk/`: Real Pakistani bank directory lookup.
  - `POST /accounts/profile/`: Multipart initial KYC document bundle submission (`cnic_front`, `cnic_back`, `selfie`, max 5 MB each).
  - `PATCH /accounts/profile/`: Multipart KYC resubmission (`full_name`, `phone` E.164, `cnic_number` `#####-#######-#`, `city`, `address`, `cnic_front`, `cnic_back`, `selfie`, max 5 MB JPEG/PNG/WebP each; omits `kyc_status` and `is_resubmission` so the backend automatically transitions status to `"resubmitted"`).
  - `GET /banking/banks/pk/`, `GET /banking/bank-accounts/`, `POST /banking/bank-accounts/`, `POST /banking/bank-accounts/<id>/make_primary/` (with `PATCH /banking/bank-accounts/<id>/` fallback), `PATCH /banking/bank-accounts/<id>/`, `DELETE /banking/bank-accounts/<id>/`: Fetches live Pakistani bank IDs + KYC/settings payout bank accounts (displayed immediately on Account Settings Bank Accounts); creates/edits accounts using integer `bank` ID, letters-only `holder_name` (max 150), digits-only `account_number` (6–50), optional `PK` `iban` (max 50), and `is_primary`; promotes primary accounts; and enforces primary-account deletion protection (additional accounts removable only).
  - `GET /auth/onboarding-step/` & `PATCH /auth/onboarding-step/`: Multi-step onboarding state restoration and draft autosave.
  - `GET /accounts/profile/`: Real-time KYC approval status verification.
- **Local Persistence & Clean Slate:** Retains local disk storage via `UserProfileRepository` (`paidix_users/<email>/profile.json`) with zero pre-seeded demo users or mock cards. Production code in `lib/` contains 0 fake transactions and 0 hardcoded accounts. Automated test suites run against isolated test fixtures in `test/test_fixtures.dart`, maintaining 100% test pass rate across all 164 tests.

---

## 6. Routing & user journeys

Defined in `lib/app/router.dart`. Transitions: fade (most), slide+fade for `/app/payments/new`.

| Path | Shell? | Page | Notes |
| :--- | :---: | :--- | :--- |
| `/signin` | no | `SignInPage` | **Default initialLocation** |
| `/signup` | no | `SignUpPage` | Accessible via "Create an account" link |
| `/kyc` | no | `KycPage` | 4 steps, no app chrome |
| `/server-error` | no | `ServerErrorPage` | Full-screen server/gateway outage fallback with retry & diagnostic drawer |
| `/app/dashboard` | **AppShell** | `DashboardPage` | In live backend mode, AppShell checks the authenticated user's email verification and Payments PIN status before rendering dashboard data. If a PIN is set, the dashboard and My Payments share one unlock for the current app session: the first visit to either page requires `POST /auth/payments-pin/verify/`, and success unlocks both until either lock icon re-locks them. A failed status request fails closed until retry. “Forgot your PIN?” opens the shared responsive recovery dialog in place and uses authenticated `POST /auth/payments-pin/forgot/`. The main scroll view keeps pull-to-refresh and uses shared `PaidiXSmoothScrollPhysics`; recent-activity rows animate as they enter and leave the viewport in both scroll directions. |
| `/app/onboarding` | **AppShell** | `OnboardingProfilePage` | Dynamic user profile & KYC review |
| `/app/settings` | AppShell | `AccountSettingsPage` | 5-tab settings: Profile (read/edit name, phone with single +92 prefix without duplication, CNIC, city, address, camera badge avatar with auto-crop & enhance, responsive update/remove avatar dialog with dual-theme color management [clean white surface with soft border in light mode & sunken dark teal in dark mode; soft rose `#FFF1F3` background with crimson `#BE123C` title in light mode & midnight ruby `#261217` in dark mode for destructive action], and high-fidelity 3-card saved documents section for Selfie, CNIC Front, CNIC Back featuring emerald preview banner, header row with `✓ Enhanced` badges, 155px container with floating zoom lens overlay, tap-to-inspect `DocumentViewerDialog`, and spongy `Replace` flow), Security (password update via `POST /auth/change-password/`, 3 eye-toggle fields), Bank Accounts (responsive cards matching desktop/mobile specifications: gold ACCOUNTS eyebrow, security audit notice, PKR RECEIVING (PAKISTAN) + Add account pill, cards with uppercase bank headers, ☆ Primary badge / Set as primary toggle, prominent holder title, •••• •••• 2786 masked number, divider, Edit and Remove actions with confirmation dialog; Edit/Add Pakistani bank account modal with audit notice, 39-institution authoritative banking & digital wallet directory with clean bank account names, standard semantic outline icons, real-time search, BankSelectorSheet, letters-only / digits-only validation, optional IBAN, persistent storage via UserProfileRepository in paidix_users/<email>/bank_accounts.json, and zero overflow on 320px–1200px), Payments PIN (server-authoritative 4–8 digit status, set/update/remove/verify via documented `/auth/payments-pin/` routes, authenticated email recovery via `POST /auth/payments-pin/forgot/`, email-verification check via `/auth/me/`, no client-side PIN cache), Appearance (Dark/Light/System theme cards + Financial Display & Privacy Preferences Studio featuring Stealth Privacy Mode for balance masking, tap-to-reveal on Dashboard Customer Score card, Compact Currency Notation formatting, live preview, persistent storage in paidix_fx_display_prefs.json, and zero overflow on 320px–1200px screens). `?section=bank-accounts` and `?section=payments-pin` open their respective settings tabs directly. Slide-in/slide-out page transition. On mobile viewports, `AppShell` automatically hides its global `AppBar` and `PaidiXBottomNavBar` on `/app/settings`, eliminating double headers and stacked navigation bars. Tapping the back button (`_buildMobileTopBar` and `_buildSideNav`) navigates directly to `/app/dashboard` with spongy haptic feedback and smooth easeOutCubic slide+fade transition. Responsive wide breakpoint requires `width >= 768 && height >= 520` so tilted/landscape mobile phones (740x360, 800x360, 850x390, 896x414) automatically render the mobile layout with the 48px horizontal tab bar and full-width content, completely eliminating the 223px sidebar flex overflow; sidebar navigation and modal dialogs are wrapped in `SingleChildScrollView` to guarantee zero pixel overflow on any phone orientation. |
| `/app/payments` | AppShell | `PaymentsPage` | Shares the session-level Payments PIN unlock with Dashboard. If locked, the first visit requires server verification; unlocking either page grants access to both for the current app session. A lock icon beside the “My payments” heading re-locks both pages. Uses the shared lock screen and forgot-PIN recovery dialog. The main scroll view retains pull-to-refresh and uses `PaidiXSmoothScrollPhysics`; horizontal filter, pagination, actions, and table scroll areas share the same controlled fling profile. Mobile payment rows use `SmoothAnimatedListItem` for staggered fade/pop-in on first visibility, bidirectional viewport-aware fade/pop transitions while scrolling, and a subtle face-front tilt; card taps retain `SpongyTap` press rebound plus clipped ink ripple while opening payment details immediately. Dashboard recent-activity rows use the same viewport animation. Search, interactive `PaginationControls` (Showing range, interactive Rows selector chips 10/20/30/50/100/Custom, Page navigation with direct jump dialog), and collapsible `PaymentsFilterBar` (closed by default, animated expand/collapse, horizontal slider for side-by-side Range/Currency/Status chips with popup menus). Bulk Add option and connectivity are commented out. |
| `/app/payments/new` | AppShell | `NewPaymentPage` | nested under payments; the form is shown only after a recognized server KYC approval, otherwise the route presents a locked state (including pending/rejected feedback) |
| `/app/payments/:id` | AppShell | `PaymentDetailPage` | Nested server-backed payment detail. Receives the selected row for immediate first paint, then fetches `GET /transactions/payments/{id}/` and refreshes every five seconds while visible or on manual refresh. Displays API timestamps in the device's local timezone to match the website, with payment and submission dates on separate lines. Shows the server fee/FX breakdown, sender fields, proof and transfer documents, payment progress, and PKR receipt confirmation. The route remains under the shared Payments PIN guard; back returns to the retained list. |

**Android back navigation:** `AppBackButtonHandler` and `AppShell` provide route-aware hardware back behavior. Payment details return to the payments list; New Payment keeps its unsaved-form confirmation and allows the date picker/dialog to close first; app tabs return to the previous app destination; Settings returns to the destination it was opened from; KYC backs through its steps and then to its originating flow; Sign Up and server-error routes return to Sign In. Back from a root page asks before closing the app. Existing on-screen navigation remains available.

**Auth Flow:**

- Sign up: Calls `POST /auth/signup/request-otp/` (`includeAuth: false`) -> Opens 6-digit OTP verification dialog (`POST /auth/email/verify/`) with 60s resend timer (`POST /auth/email/resend/`) -> Automatically authenticates user via `POST /auth/login/` -> Saves JWT tokens to secure storage -> Routes to `/kyc` for initial onboarding.
- Sign in: Calls `POST /auth/login/` (`includeAuth: false`) -> Admin roles/flags returned by the backend are rejected before any access or refresh token is stored; explicit backend admin-web-only errors are preserved and show a link to `https://paidix.com/login`. The backend remains the authorization authority and must deny mobile sessions for admin accounts. Each live sign-in refreshes `GET /accounts/profile/` for KYC review status; only an explicit server approval status or KYC-specific verified flag maps to `KycReviewStatus.verified`. `is_profile_complete` is not KYC approval. If the status endpoint is unavailable or lacks a recognized status, onboarding remains visible; same-email saved identity data and documents are merged back without trusting a cached verified status. KYC document URL fields from the account profile response are retained per user and rendered with same-origin authenticated media requests, while local bytes/files remain the offline fallback. Verified users route to `/app/dashboard`; submitted/unverified users retain the Onboarding navigation tab, while users who have not submitted KYC route to `/kyc`. If server returns `401 EMAIL_UNVERIFIED`, automatically dispatches a fresh OTP via `POST /auth/email/resend/`: if resend reports `"already verified"`, retries `/auth/login/` directly without opening the OTP dialog; if resend sends a fresh OTP (or returns 429 rate-limit notice), opens `EmailOtpDialog` truthfully reflecting dispatch status. On Resend tap inside dialog, if server reports `"already verified"`, throws `EmailAlreadyVerifiedException`, closes dialog, and signs in directly instead of faking OTP delivery.
- Authenticated KYC review polling: `AppShell` refreshes `GET /accounts/profile/` every 5 seconds while the app is open and immediately on resume, pausing the timer while backgrounded. Status parsing accepts prefixed states such as `KYC_PENDING`, `KYC_RESUBMITTED`, `KYC_AWAITING_CUSTOMER`, `KYC_APPROVED`, and `KYC_REJECTED`. A server rejection or objection updates the profile status, review time, reviewer reason (`kyc_notes` / `kyc_rejection_reason`), and field-specific objections (`kyc_objections` or supported objection fields), announces the change, and routes app pages to `/app/onboarding` except the dashboard, locked new-payment page, and settings route. Dashboard keeps the rejection or requested-update banner and its `Go to profile` action visible; settings remains available for bank-account actions. Objection details are parsed from structured records or field-to-reason maps and shown as requested updates; generic rejection copy is not displayed as a reviewer reason. The rejected/awaiting-customer onboarding `Fix & resubmit` flow and Edit Profile `Save & resubmit` both send multipart fields (`full_name`, `phone`, `cnic_number`, `city`, `address`) plus validated JPEG/PNG/WebP images (max 5 MB each) via `PATCH /accounts/profile/` (with the existing `/kyc/submit` 404 fallback), omitting `kyc_status` and `is_resubmission` so the backend transitions the status to `"resubmitted"`. Once the server confirms `"resubmitted"`, the profile persists the resubmission marker and server `kyc_last_resubmit_at` timestamp + document URLs, clears stale rejection/objection feedback, and immediately shows the blue awaiting-review banner and `Resubmitted` pill. Pending server polls retain this state; approval or a newer rejection/objection clears the marker. A poll started before upload completion or carrying review metadata older than the latest resubmission cannot overwrite its accepted state; the server transition also produces a single resubmission toast.
- Pull-to-refresh is available on authenticated server-backed screens: Dashboard refreshes payment records/summary and the authenticated score/KYC profile; My Payments refreshes payment records/summary; onboarding refreshes profile/KYC; New Payment refreshes the server KYC gate without resetting form inputs; Account Settings refreshes only the active remote section (profile, bank accounts, or Payments PIN). Local filters, pagination, and form values remain intact. Payment snapshot requests are coalesced by `PaymentsRepositoryImpl`, and KYC profile status requests share the in-flight request in `AuthRepository`, including with the existing five-second poll. All refresh requests use `ApiClient`, which remains the single owner of access-token injection, refresh-token rotation, one-time request replay, and session invalidation; page refresh code does not manage tokens directly.
- New payment KYC gate: `AuthRepository` tracks server-confirmed KYC verification status per active signed-in session (`serverKycStatusNotifier` / `isServerKycVerifiedFor`, updated on `signIn()` and `refreshKycReviewStatus()`, cleared on logout/session reset). Once the backend confirms KYC approval in runtime, `/app/payments/new` unlocks immediately in real time and opens directly into the payment form with zero lock-screen flash or reload wait, running a silent background `GET /accounts/profile/` verification check (only locking again if the server explicitly returns a non-verified status; transient errors preserve verified UI). Unverified, pending, and rejected sessions show the locked state (with `Go to profile` and `Bank accounts` actions) and unlock automatically on screen as soon as runtime backend verification succeeds. Submission still verifies KYC status before accepting the form action. `AppShell` refreshes KYC status on route changes when pending and continues redirecting rejected users to onboarding from other app routes while keeping `/app/payments/new` and `/app/settings` accessible.
- Forgot password: Opens live dialog requesting 6-digit email OTP (`POST /auth/forgot-password/request-otp/`) and verifies new password (`POST /auth/forgot-password/reset/`).
- Sign-up SMS consent is a checkbox; phone is optional.
- **Active Session Inactivity Timeout (5 Minutes Idle Security):** Monitored automatically via `SessionTimeoutService.instance` and transparent `Listener` + `Focus` hooks in `AppShell`. Every pointer touch, scroll, drag, gesture, keystroke, and tab switch resets the 5-minute timer. If the user leaves the application idle with 0 interaction for 5 continuous minutes while in an authenticated session, the active session locks and displays `SessionTimeoutDialog` (non-dismissible modal with `PopScope(canPop: false)`, illuminated gold timer halo, eyebrow badge `SESSION EXPIRED • 5 MIN INACTIVITY`, and financial reassurance copy). Tapping **"Log In Again"** executes immediate logout, clears local repository states, navigates cleanly to `/signin`, and displays a top PaidiX warning notification (`Session expired due to 5 minutes of inactivity. Please sign in again.`).

**KYC Flow:**

- Resubmission success requires backend confirmation: `PATCH /accounts/profile/` (or its existing 404 fallback) sends updated profile fields (`full_name`, E.164 `phone`, `cnic_number`, `city`, `address`) and replacement multipart documents (`cnic_front`, `cnic_back`, `selfie`, JPEG/PNG/WebP max 5 MB each) without sending `kyc_status` or `is_resubmission` — the backend automatically transitions the status to `"resubmitted"` and returns `kyc_last_resubmit_at`, `kyc_last_resubmit_changes`, and document URLs. Re-read `GET /accounts/profile/` up to five times over about five seconds when the write response does not contain a matching `resubmitted` status. When an email is returned, it must match the signed-in account. Clients must not fabricate audit values. Parse profile responses wrapped in lists and standard API envelopes, including status metadata on an envelope around the record.

- Header can `go('/signin')`
- Auto-draft sync: On Step 1-3 changes, automatically saves progress to `PATCH /auth/onboarding-step/` (`goto: 'stepN'`).
- Live CNIC validation: Calls `GET /accounts/cnic-available/?cnic=...` as user types.
- Image processing: Enhances regulatory photos (`POST /accounts/process-img/`).
- Bank Accounts: Fetches live directory (`GET /banking/banks/pk/`).
- Submit KYC: Submits multipart identity bundle (`POST /accounts/profile/`), creates primary bank account (`POST /banking/bank-accounts/`), sets step 4 complete, saves KYC details, sets `hasCompletedKyc: true` -> `KycSuccessDialog` (non-dismissible) -> **Go to Dashboard** -> `/app/dashboard`. Zero push notifications during document/selfie enhancement.
- Rejected or objected KYC: The authenticated app polls `/accounts/profile/` for server review status. Rejected and `awaiting_customer` responses show reviewer notes, structured field objections, and review time in Onboarding and Dashboard, with `Fix & resubmit` routing into the existing 4-step form with saved profile data. The Edit Profile `Save & resubmit` action also sends edited identity/contact/address fields plus all three required replacement documents to the same multipart endpoint. Only a successful server response clears stale rejection/objection details and changes the client status back to pending review. A separate persisted `hasResubmittedKyc` marker presents the server's `KYC_RESUBMITTED` state as `Resubmitted` and shows the awaiting-review notice in Onboarding and Dashboard while keeping payment authorization pending; server approval or a subsequent rejection/objection replaces that state.

- Header can `go('/signin')`
- Submit last step: saves all KYC details permanently, sets `hasCompletedKyc: true` → `KycSuccessDialog` (non-dismissible) → **Go to Dashboard** → `/app/dashboard`. Zero push notifications during document/selfie enhancement.

**AppShell nav (wide ≥768 && height ≥520 sidebar; else bottom bar):**

0. Dashboard `/app/dashboard`
1. Onboarding `/app/onboarding`
2. My Payments `/app/payments`
3. New Payment `/app/payments/new`

Bottom navigation bar (`PaidiXBottomNavBar`) provides fully responsive adaptive horizontal spacing (320px–480px+), zero text truncation via auto-fitting typography (`FittedBox(fit: BoxFit.scaleDown)`), 0ms raw pointer touch compression (`Curves.easeInOutCubic`), bouncy spring release (`Curves.easeOutBack` on scale), animated icon scaling & color transitions, active pill illumination, and fluid micro-indicator accent lines with strictly monotonic easing (`Curves.easeOutCubic`) to guarantee non-negative `BoxShadow` blur radii during backward and forward tab transitions.

Dynamic user profile state via `UserProfileRepository.instance`. Default unauthenticated state: `UserProfile.empty()`. Dashboard greeting: **Hello, ${profile.firstName.isNotEmpty ? profile.firstName : 'User'}.** Edit Profile & Account Settings provide real-time updates, single clean `PK +92` phone prefix without duplication, elevated camera badge avatar (76px/88px diameter, clean circular teal border without background shadow, high-contrast floating badge, centered face alignment `Alignment(0.0, -0.22)`), interactive update/remove avatar modal restoring initial letter "U", and responsive 3-card saved documents section (Selfie, CNIC Front, CNIC Back). For Selfie: dedicated biometric portrait presentation with atmospheric frosted blurred backdrop, centered 118x144 emerald-framed portrait preview targeting human face/eyes without vertical squishing (background radial guide ring removed for a clean focused look), `PORTRAIT BIOMETRIC` badge, tap-to-inspect `DocumentViewerDialog`, and spongy `Replace` action with zero overflow across 320px–1200px screens. User profile details, custom avatars, and regulatory documents are persisted to local device storage and restored automatically upon re-login. Avatar updates are synchronized across `AppShell` mobile header and desktop sidebar. Dedicated test profiles and aliases are isolated exclusively in `test/test_fixtures.dart`.

---

## 7. Domain rules (money, status, KYC)

### 7.1 Payments — `PaymentsRepositoryImpl`

Offline/test simulation constants (must stay in sync with repository tests):

- Fee estimate: **12%** of USD amount; live fee is returned by the server
- FX estimate: **1 USD = 273 PKR**; live exchange rate is returned by the server
- Offline/test repository submissions retain the legacy local reference (`PBX-2026-00` + counter), `pay_<epochMs>` ID, 12% fee, 273 PKR rate, and completed status. This path is used only when the custom backend is disabled.
- Live `submitPayment` posts authenticated `multipart/form-data` to `POST /transactions/payments/` (API base already includes `/api/v1`). It sends `payment_method`, decimal-string `amount`, `sender_company`, and `currency`; non-empty `sender_name` / `external_transaction_id`, a selected `occurred_on` date, and the optional `screenshot_transaction` image are included when present. Existing UI method IDs `cashapp_1` and `zelle_1` are mapped to server method codes `cashapp` and `zelle`.
- The API client's multipart request carries the active Bearer access token and can refresh/replay on token expiry. The 201 Payment response is the source of truth for ID, reference, status, amount, currency, fee percentage, exchange rate, net PKR, and timestamps. The returned item is inserted newest-first; live submissions are never locally marked completed or assigned fabricated IDs/references/totals.
- Contract-defined optional fields (sender name, external transaction ID, occurred date, and screenshot) remain optional in the form. Server validation errors, including duplicate external transaction IDs and unapproved payment methods, are shown to the user.
- `sharedPaymentsRepository` in `router.dart` starts with an empty in-memory list. Dashboard and My Payments acquire a shared authenticated refresh lease while visible; the repository polls `GET /transactions/payments/?page=N&page_size=100&ordering=-created_at` and `GET /transactions/payments/summary/` every five seconds, follows paginated results without forwarding server-provided URLs, and atomically replaces the local list only after a successful list response. Failed refreshes preserve the last good values. The shared request is coalesced across screens and pauses when both screens leave the foreground.
- Payment badges, amounts, references, dates, transaction counts, PKR received, and transferred totals use the refreshed server records and summary. Pending review counts include `submitted` and `under_review`; awaiting PKR counts include `verified` and the compatible `awaiting_pkr` status, while `pkr_sent` is excluded because PKR has already been sent. The dashboard's Awaiting Verification total uses the server summary's `pending` aggregate when present, with the list-derived pending/awaiting count as fallback. Status changes refresh through the shared five-second poll.

Selecting a payment from the My Payments list opens `/app/payments/{id}` with the existing `PaymentItem` for immediate rendering. `PaymentDetailPage` loads the authoritative record from `GET /transactions/payments/{id}/`, refreshes that detail every five seconds while foregrounded, and updates the shared payment list from the server response. It displays server fee/foreign net/PKR values, sender and confirmation fields, transaction and submission times, screenshots, team documents, transfer metadata and receipts, and chronological status history. Private images use `ApiClient.imageHeadersFor`, which only attaches credentials for same-origin media URLs.

For `pkr_sent`, the customer can confirm funds received. The app calls `POST /transactions/payments/{id}/customer-confirm/` with `{ "note": "" }` or the entered note (maximum 500 characters), then reloads the detail record so status and timestamps remain server authoritative. Detail refresh and confirmation use the shared `ApiClient`; the client does not fabricate status transitions.

Formula:

```
feeAmount = amount * 12 / 100
netUsd    = amount - feeAmount
netPkr    = netUsd * 273
```

Example locked by `test/payments_repository_test.dart`: `$171` → fee `20.52` → net PKR `41081.04`.

**Payment methods (hardcoded):**

| id | name | iconKey |
| :--- | :--- | :--- |
| `cashapp_1` | Freight Flow Cashapp | `cashapp` |
| `zelle_1` | UB Zelle | `zelle` |

**`filterPayments`:** search on reference, sender, company, amount string; status enum (`all`, `submitted`, `underReview`, `verified`, `pkrSent`, `completed`, `onHold`, `rejected`); date range on `transactionDate`; Bitnex settlement week filter (`isBitnexWeek`: Monday 00:00:00 through Sunday 23:59:59).  
**Currency filter is UI-only today** — `CurrencyFilter` is stored on `PaymentFilter` and counted in `activeFilterCount` but **not applied** in the repository.

**Duplicate confirmation codes:** not enforced in the repository (README mentions duplicate prevention; code does not).

**New payment proof & submission:** Native `ImagePicker` (`ImageSource.gallery`) with memory bounding (`maxWidth: 2400`, `maxHeight: 2400`, `imageQuality: 88`) and Android/Huawei activity lifecycle recovery via `_picker.retrieveLostData()` in `initState()`. Selected proofs are validated as JPEG/PNG and at most 5 MB; screenshots are optional per the customer payment API. The authenticated live submission endpoint is `POST /transactions/payments/` using multipart fields and `screenshot_transaction` (see repository invariants above). On successful server response, the UI uses the server-created payment, not local generated data, then fires the existing local notification, success toast, and routes to `/app/payments`. The processing fee banner is generic in live mode because this contract has no fee-quote endpoint; the server response supplies the applied fee and net PKR.

**Bulk Add Payments Dialog (`BulkAddPaymentsDialog`):** (Commented out) Complete Bulk Add dialog, spreadsheet table/card grid, duplicate/delete/add row toolbar, batch payment submission, and connectivity are commented out across the project.

**Interactive Pagination Controls (`PaginationControls`):** Interactive "Showing X–Y of Z", "Rows: 10, 20, 30, 50, 100, Custom", and "Page X of N" navigation with first (`«`), previous (`< Prev`), page jump dialog, next (`Next >`), and last (`»`) controls. Mobile layout wraps `pageNavControls` in a horizontal scroll view to guarantee zero overflow even on ultra-compact 320px screen widths.

### 7.2 Status enum — `PaymentStatusType` (`status_badge.dart`)

`PaymentStatusType`: `submitted` | `underReview` | `pendingReview` | `verified` | `pkrSent` | `awaitingPkr` | `completed` | `onHold` | `rejected`. `StatusFilterOption` keeps legacy aliases `pendingReview` to `underReview` and `awaitingPkr` to `pkrSent` for exact-status filter compatibility. Dashboard aggregate filters use `PaymentStatusGroup`: Pending Review includes `submitted`, `underReview`, and `pendingReview`; Awaiting PKR includes `verified` and `awaitingPkr`, excluding `pkrSent`. Metric counts and dashboard group filtering share the same `PaymentStatusType` membership helpers. Each exact status has designated badge styling and colors. Filter dropdown displays all 8 selectable statuses with animated checkmarks. Header includes `Bitnex week` quick-filter toggle button beside accordion chevron.

### 7.3 Dashboard — `DashboardRepositoryImpl`

**Live backend:** The customer score card reads the authenticated `GET /accounts/score/` response through `ApiClient`. It displays the server's score, grade, tier, completed count, completion rate, and lifetime PKR volume without recomputing those values on-device. The dashboard fetches on open, app resume, pull-to-refresh, and every five seconds while active; failed polls retain the last successful score, and account changes clear the previous account's score. The score card uses the server score for its palette: below 40 red for High Risk, 40–69 blue for Standard, and 70+ deep teal for Trusted. While the first live response is pending or unavailable, it shows the existing neutral updating state. The profile endpoint's score fields remain available as profile metadata but are not used as the live card source.

Financial totals and the Awaiting Verification aggregate use `GET /transactions/payments/summary/`; Pending Review, Awaiting PKR, Completed, and recent activity use the live payment list. Dashboard counts and tile filters share membership rules: Pending Review includes submitted/review records, and Awaiting PKR includes verified or awaiting-PKR records. `pkr_sent` is excluded from Awaiting PKR because its payout has already been sent. A loading state is shown until the first successful list response. Temporary network errors retain the last successful snapshot. The documented summary has no awaiting amount, so the Awaiting Verification card shows its in-progress payment count instead of inventing a PKR amount.

**Offline/test mode:** Existing local score calculation, starter score, local payment simulation, and fee/FX estimates remain enabled when the custom backend is disabled.
### 7.4 Auth models

`SignUpRequest`, `SignInRequest`, `AuthResponse` (+ `fromJson`) exist for a future API. Pages do not call them.

Validators (`AuthValidators`): name ≥2, email regex `^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$`, password ≥8, optional phone ≥6 if present.

### 7.5 KYC

Steps (`KycStep`): **personal → identity → photo → bank**

| Model | Valid when |
| :--- | :--- |
| `PersonalInfo` | name ≥3, `smsConsent == true`. Valid phone for selected country: PK (`+92` / `PK +92`) 10 digits, US (`+1` / `US +1`) 10 digits NANP (area code ≥2). Real-time auto-spaced formatting `(XXX) XXX-XXXX` (US) and `XXX XXXXXXX` (PK). |
| `IdentityDocInfo` | CNIC non-empty **and** both sides have file/path/bytes |
| `PhotoDocInfo` | any of fileName / path / bytes |
| `BankInfo` | bank non-empty, title ≥3, IBAN ≥**14** (`isValid`). UI continue uses IBAN ≥**10** — mismatch |
| Default bank in model | `'Meezan Bank'` vs dropdown `'Meezan Bank Limited'` — mismatch |

**CNIC:** 13 digits, hyphens at 5 and 12 (`35202-0450461-5`). Province first digit **1–8**.  
Simulated registry (`CnicValidator.checkAvailability`, 320ms):

- empty / incomplete / invalidFormat
- alreadyRegistered: `1111111111111` or `3520200000000`
- else `available`

**Image “enhancement”** (`KycImageProcessor.enhanceDocument`): timed progress stages (~280ms each), returns original bytes (or 64-byte stub), fake ~62% size reduction. Not real CV.

**Gallery / camera pick hardening** (`kyc/presentation/widgets/kyc_media_access.dart`, `kyc/data/kyc_image_validation.dart`, and `kyc/data/kyc_media_recovery.dart`):

- `KycMediaAccess.ensureGalleryAccess(context)` requests native OS photo access when unavailable (Android 13+ photos, older Android storage, iOS photos), without an app-specific permission dialog. It still opens the platform picker if broad access is denied because the system picker grants access to the selected image.
- KYC picker calls request `maxWidth/maxHeight = 1600`, `imageQuality = 88`; returned bytes are checked for non-empty, max 5 MB size (`KycImageValidation.maxFileSizeBytes = 5 * 1024 * 1024`), decodability, and recognized JPEG/PNG/WebP signatures before entering state or upload, preserving the plugin's encoded format. The 5 MB max limit is also enforced across `EditProfileDialog`, `AccountSettingsPage` (avatar & KYC replacement), `NewPaymentPage` payment proofs, and `KycRepository` / `AuthRepository` multipart uploads.
- The pending target (`cnic_front`, `cnic_back`, or `selfie`) and active step are persisted before opening the external picker. `main()` calls `KycMediaRecovery.recoverAfterAndroidRestart()` after restoring the profile and before `runApp`, as Android can reclaim MainActivity while an external picker is open. Step 2 and Step 3 also serialize in-session recovery with active picker calls.
- Replacement picks clear the prior enhanced-byte buffer so the newly selected image is the one submitted.
- Live KYC submission requires non-empty bytes for all three images and sends each once under the multipart fields `cnic_front`, `cnic_back`, and `selfie`. Endpoint fallback retries rebuild multipart streams.
- Every `Image.memory` / `Image.file` that shows KYC documents has an `errorBuilder` falling back to the placeholder (step 2 CNIC card, step 3 avatar, `document_viewer_dialog`), because an undecodable image (incl. the 64-byte stub from the failed-pick fallback) would otherwise render a blank/grey `ErrorWidget` in release.
- `UserProfileRepository._persistUser` coalesces overlapping writes (latest state wins, never concurrent) and skips rewriting image files whose exact `Uint8List` was already written (`_persistedBytes`), instead of rewriting selfie/CNIC/avatar with `flush: true` on every `syncFromKyc`.
- Known limit: if the OS kills the whole process while the gallery is open, app state is in-memory only (auth is a timer, `activeKycStep` is not persisted) so the user restarts at `/signin`; `retrieveLostData` only recovers the image once step 2/3 is shown again.

**Notifications:** KYC pick/enhance paths call `NotificationService` (Android). Init uses `@mipmap/ic_launcher`. Permission request failures are swallowed (`return true` in catch).

**Pakistani banks list** (step 4): Meezan, HBL, ABL, MCB, UBL, Alfalah, SCB, Faysal, Askari, BOP, EasyPaisa, JazzCash, SadaPay, NayaPay.

---

## 8. Design system

Files: `lib/app/theme/app_colors.dart`, `app_theme.dart`, `app_typography.dart`, `app_spacing.dart`, `app_motion.dart`.

- `AppTheme.themeModeNotifier` default **`ThemeMode.dark`**. Toggle: `AppTheme.toggleTheme()`.
- `PaidiXColorsExtension` on `ThemeData`. Discrete lerp (midpoint switch).
- **Sidebar constants never follow light/dark invert:** `#022F32` base, gold active indicator `#E5B35A`, green active `#56A240`.

**Dark (html.dark-inspired):** bg `#031415`, card `#0A3134`, aqua `#5FCFC9`, gold `#EFC479`.  
**Light (:root-inspired):** bg `#EFF3F0`, card `#FFFFFF`, aqua `#0E7C7B`, gold `#E5B35A`.

`test/theme_test.dart` locks many of these hex values — **change tokens and tests together**.

**Typography & Universal Font System:**
- Reactive dynamic font selection via `AppTheme.fontFamilyNotifier` (`ValueNotifier<String>`, default `'Inter'` — institutional tier-1 fintech standard).
- 10 supported font families: Inter (default universal standard), Roboto, Poppins, Lato, Nunito, Open Sans, DM Sans, Source Sans 3, IBM Plex Sans, System default (via `google_fonts: ^9.0.0` with offline test fallback `GoogleFonts.config.allowRuntimeFetching = false`).
- Text scale reactivity via `AppTheme.textScaleNotifier` (`ValueNotifier<double>`, range 80%–140%, default 100%).
- Persistent preferences in local storage (`paidix_appearance.json`).
- `AppTypography` dynamically connects every typography style to `AppTheme.activeFontFamily`, while the root `PaidiXApp` injects `MediaQuery.copyWith(textScaler: TextScaler.linear(scale))` wrapped in a multi-listenable builder.
- Account Settings `Appearance` tab font picker: responsive 2-column grid (`childAspectRatio: 2.2`) with tiles auto-scaled via `FittedBox(fit: BoxFit.scaleDown)` to guarantee zero pixel overflows across all phone widths (320px–480px+) and text scales, preview box ("Send USD, receive PKR.") rendered in the active font, interactive slider, and "Reset to defaults" action.

**Spacing:** xs 4 … xxxl 32; radii 6 / 10 / 14 / 18 / pill 999.  
**Motion:** fast 120 / normal 220 / medium 320 / slow 450; button press scale **0.96** (`AppMotion`); `AppButton` uses **0.945** over 110ms + 260ms `easeOutBack`.  
**Breakpoints used in UI:** ~360 narrow phone, ~380 auth/KYC, **768** tablet shell/table vs cards, ~850 dashboard finance row.

Typography Invariant: Institutional balanced scale ("not too bold, not too thin" — 0 instances of w800/w900 across codebase):
- Bold (`FontWeight.w700`): Headings, financial stat values (e.g. `Rs. 789,985.47`), score numerals (`845`), brand mark (`PX`). Crisp and proportional without OEM synthetic stroke blooming or heavy ink blobs.
- SemiBold (`FontWeight.w600`): Eyebrow headers, section labels, card titles, table headers, buttons, active bottom nav items. Clean character spacing (`letterSpacing: 1.0–1.2`) avoiding letter fusion.
- Medium (`FontWeight.w500`): Inactive nav labels, inputs, tabular data cells, badges.
- Regular (`FontWeight.w400`): Helper text, subtitles, placeholders, legal disclaimers.

---

## 9. Core widgets (reuse these; do not fork)

| File | Role |
| :--- | :--- |
| `app_shell.dart` | Responsive chrome (brand logo + profile avatar) |
| `profile_menu_dialog.dart` | Compact profile dialog with user info, Account Settings, Theme Changer toggle, and Logout |
| `paidi_x_bottom_nav_bar.dart` | Custom bottom nav (not `NavigationBar`) |
| `brand_logo.dart` | PX mark (P white, X gold) + “PaidiX” + tagline |
| `app_button.dart` | Variants: primary, secondary, outline, text, success |
| `spongy_tap.dart` | Press squash + ripple wrapper |
| `app_text_field.dart` / `auth_text_field.dart` | Dark-themed inputs |
| `auth_primary_button.dart` / `auth_header.dart` | Auth card chrome |
| `status_badge.dart` | Status pills |
| `paidix_toast.dart` | Top-positioned auto-dismissing alerts & toasts (Success, Warning, Error, ServerError, Info) with curved slide-down entrance, swipe-up/close dismiss, zero-queue lag, inline action callbacks, and responsive max-width bounds |
| `bank_logo_widget.dart` | Premium authentic vector brand logo & monogram renderer for all 39 Pakistani banking & payment institutions (`BankLogoWidget`, `BankCategoryPill`) |
| `bank_selector_sheet.dart` | Searchable modal bottom sheet with category tabs, live search, and logo badges for all 39 banks (`BankSelectorSheet`) |
| `server_error_page.dart` | Fullscreen server outage fallback view (`ServerErrorPage`) & in-flow modal dialog (`ServerErrorDialog`) |
| `selectable_tile.dart` | Payment method tiles |
| `info_banner.dart` | Fee notice on new payment |
| `empty_state.dart` | Empty lists + CTA |

Feature widgets stay under `features/*/presentation/widgets/`.

---

## 10. Complete Dart file index

### App

- `lib/main.dart`
- `lib/app/app.dart`
- `lib/app/router.dart`
- `lib/app/theme/app_colors.dart`
- `lib/app/theme/app_theme.dart`
- `lib/app/theme/app_typography.dart`
- `lib/app/theme/app_spacing.dart`
- `lib/app/theme/app_motion.dart`

### Core

- `lib/core/services/notification_service.dart`
- `lib/core/utils/formatters.dart` — USD `$ 1,234.00`, PKR `Rs 1,234.00`, `%`, `MMM d, yyyy`, `mm / dd / yyyy`
- `lib/core/utils/validators.dart` — `PaymentValidators`
- `lib/core/utils/cnic_formatter.dart`
- `lib/core/utils/phone_formatter.dart` — `CountryCodeOption`, `PhoneFormatter`, `PhoneInputFormatter`, `PhoneValidator`
- `lib/core/widgets/` — files listed in §9 plus those same names

### Auth

- `lib/features/auth/domain/auth_models.dart`
- `lib/features/auth/domain/auth_validators.dart`
- `lib/features/auth/presentation/pages/sign_in_page.dart`
- `lib/features/auth/presentation/pages/sign_up_page.dart`

### KYC

- `lib/features/kyc/domain/kyc_models.dart`
- `lib/features/kyc/data/kyc_image_processor.dart`
- `lib/features/kyc/data/kyc_image_validation.dart`
- `lib/features/kyc/data/kyc_media_recovery.dart`
- `lib/features/kyc/presentation/pages/kyc_page.dart`
- widgets: `kyc_header`, `kyc_stepper`, `kyc_success_dialog`, `kyc_permission_dialog`, `kyc_media_access`, `kyc_file_picker_tile`, `step1_personal_view`, `step2_identity_view`, `step3_photo_view`, `step4_bank_view`

### Profile & Onboarding

- `lib/features/profile/domain/user_profile.dart`
- `lib/features/profile/data/user_profile_repository.dart`
- `lib/features/profile/presentation/pages/onboarding_profile_page.dart`
- widgets: `profile_info_card.dart`, `kyc_review_card.dart`, `document_preview_tile.dart`, `document_viewer_dialog.dart`, `edit_profile_dialog.dart`, `profile_picture_crop_dialog.dart`

### Dashboard

- `lib/features/dashboard/domain/dashboard_models.dart`
- `lib/features/dashboard/domain/dashboard_repository.dart`
- `lib/features/dashboard/data/dashboard_repository_impl.dart`
- `lib/features/dashboard/presentation/pages/dashboard_page.dart`
- widgets: `customer_score_card`, `financial_stat_card`, `status_metric_card`

### Payments

- `lib/features/payments/domain/payment_models.dart`
- `lib/features/payments/domain/payments_repository.dart`
- `lib/features/payments/data/payments_repository_impl.dart`
- pages: `payments_page.dart`, `payment_detail_page.dart`, `new_payment_page.dart`
- widgets: `payments_table`, `payments_filter_bar`, `payment_card`, `pagination_controls` (page sizes 10/20/30/50/100, default 20), `bulk_add_payments_dialog` (commented out)

### Settings

- `lib/features/settings/domain/fx_display_preferences.dart`
- `lib/features/settings/presentation/pages/account_settings_page.dart`
- widgets: `fx_converter_studio.dart`

---

## 11. Tests (`PaidiX/test/`)

| File | Covers |
| :--- | :--- |
| `widget_test.dart` | Default route is Sign Up copy |
| `auth_validators_test.dart` | Auth validators |
| `payment_validators_test.dart` | Payment validators |
| `app_formatters_test.dart` | Currency/date/em dash |
| `payments_repository_test.dart` | Empty start, fee/FX, search filter |
| `payments_page_test.dart` | Payments UI, accordion filters, side-by-side chips slider, status dropdown, interactive pagination controls, and multi-width responsiveness (360px mobile, 1024px desktop) with zero pixel overflow (Bulk Add tests commented out) |
| `new_payment_page_test.dart` | New payment form |
| `onboarding_profile_test.dart` | Profile sync, real-time edit dialog, KYC document viewer, 320px narrow zero-overflow |
| `dashboard_page_test.dart` | Dashboard empty/reactive |
| `theme_test.dart` | Color tokens, theme toggle, badges, nav |
| `kyc_test.dart` | CNIC, KYC models, processor, some widgets |
| `profile_picture_crop_dialog_test.dart` | Profile picture cropper & alignment dialog: centered 1:1 portrait/landscape default crop, interactive drag & zoom framing matching 512x512 PNG output, clean Save/Cancel confirmation modal across phone sizes without AI badges |

Run from **`PaidiX/`**: `flutter test` then `flutter analyze`.

---

## 12. Agent playbook — “I need to change X”

| Task | Open first |
| :--- | :--- |
| New screen / URL | `lib/app/router.dart`, maybe `app_shell.dart` nav items |
| Theme / hex / light-dark | `app_colors.dart` + `test/theme_test.dart` + `app_theme.dart` |
| Fee, FX, methods, filters | `payments_repository_impl.dart` + `payment_models.dart` + repo tests |
| Dashboard metrics meaning | `dashboard_repository_impl.dart` (see §7.3 zeros) |
| Auth copy / validation | `sign_*_page.dart`, `auth_validators.dart` |
| KYC steps / CNIC | `kyc_models.dart`, `step*_view.dart`, `cnic_formatter.dart` |
| Android id, SDK, signing | `android/app/build.gradle.kts`, `settings.gradle.kts` |
| Permissions | `AndroidManifest.xml` + iOS `Info.plist` + `permission_handler` calls |
| Notifications | `notification_service.dart` + desugaring in app Gradle |
| Shared payments instance | **only** `router.dart` `sharedPaymentsRepository` — do not construct a second impl in pages |
| Buttons / motion feel | `app_button.dart`, `spongy_tap.dart`, `app_motion.dart` |

---

## 13. Invariants & known gaps (do not “clean up” blindly)

**Invariants**

1. No seeded fake payment rows on launch.
2. Unavailable numbers → `—`, not `0` unless the field is a real zero count.
3. One in-memory payments list shared by dashboard + payments + new payment.
4. Design tokens stay aligned with `theme_test.dart`.
5. App starts at **`/signin`**.
6. Explicitly disable Impeller via `AndroidManifest.xml` and use `RenderMode.surface` (`SurfaceView`) with proactive surface re-attachment; preserve the `MainActivity` resume render watchdog and its allowance for debugger-paused cold starts.
7. Sign-Up & KYC country selector supports PK (+92) and US (+1) with synchronized country code, dynamic phone mask/placeholder, and end-to-end repository sync (`UserProfileRepository.syncFromSignUp`).
8. KYC Step 2 CNIC verification validates format (1-8 province code, 13 digits) and verifies uniqueness against existing registered users in `UserProfileRepository` (`isCnicAlreadyRegistered`). Displays institutional status pills (`Available` + `Unique CNIC • Unregistered`) or duplicate error (`This CNIC is already registered to an existing account. Please sign in.`), omitting fabricated external registry claims.
9. KYC Step 4 Bank Linking & Settings Bank Accounts use separate text sections for Account Number (Required, MUST) and IBAN (Optional). `BankAccountValidator` detects unique account number lengths and rules across Pakistani commercial banks, Islamic banks, and digital wallets (JazzCash, EasyPaisa, SadaPay, NayaPay, Meezan, HBL, UBL, Alfalah, etc.) with real-time validation and length counters. IBAN is optional and validates 24-character `PK` standard when provided.
10. KYC Step 1 pre-populates the phone number and country code from the registered user's profile (`UserProfileRepository.instance.profile.phoneNumber`) or server onboarding draft (`/auth/onboarding-step/` or `/auth/me/`) via `PhoneFormatter.parse`. KYC gallery picking uses native OS photo permission prompts when required and the system's per-image grant; Edit Profile document browsing opens the platform picker without an app-branded gallery rationale, while retaining native permission and permanently-denied settings handling. Step 3 camera capture uses `PermissionHelper`. KYC picker requests cap dimensions at 1600px and quality 88. The pending image target is persisted before launching the picker, and lost results are recovered at app startup before routing, covering Android activity reclamation across OEM devices.

**Gaps / traps**

- No backend, no secure storage, passwords stay in memory of the form only.
- Auth “success” is a timer.
- KYC enhancement and CNIC registry are simulated.
- iOS privacy usage strings configured in Info.plist (`NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`); no automated iOS IPA release workflow is active.
- Release APK signed with debug keystore.
- `CurrencyFilter` unused in `filterPayments`.
- In live mode, Dashboard PKR received / transferred use the payments summary endpoint; offline/test mode derives them from its in-memory completed payments.
- In live mode, customer score, tier, grade, completed count, completion rate, and volume come from authenticated `GET /accounts/score/` and are refreshed every five seconds while Dashboard is active. If the backend omits score data, the card shows an updating state. The local score calculation remains an offline/test fallback.
- Live payment records keep the status returned by the API. Offline/test submissions retain the legacy `completed` simulation status.
- Sidebar user is hardcoded, not from sign-up.
- README architecture section omits KYC and is slightly stale vs this brain.
- `NotificationService` Android-only init settings (no iOS Darwin settings).

---

## 14. Gradle / Android file catalog (source of truth only)

```
android/settings.gradle.kts
android/build.gradle.kts
android/gradle.properties
android/gradle/wrapper/gradle-wrapper.properties
android/local.properties              machine-local Flutter SDK path — do not commit secrets
android/app/build.gradle.kts
android/app/src/main/AndroidManifest.xml
android/app/src/debug/AndroidManifest.xml
android/app/src/profile/AndroidManifest.xml
android/app/src/main/kotlin/com/paidix/paidix/MainActivity.kt
android/app/src/main/res/values/styles.xml
android/app/src/main/res/values/colors.xml
android/app/src/main/res/values-night/styles.xml
android/app/src/main/res/values-night/colors.xml
android/app/src/main/res/drawable/launch_background.xml
android/app/src/main/res/drawable-v21/launch_background.xml
android/app/src/main/res/mipmap-*/     launcher icons
```

---

## 15. Product copy anchors

- Brand: **PaidiX** / mark **PX**
- Auth signup title: **Start sending.**
- Auth sign-in: **Welcome back.**
- KYC success: **Account Setup Complete!**
- Dashboard: **YOUR MONEY, AT A GLANCE**, **RECENT ACTIVITY**
- Cards: **PKR RECEIVED**, **TOTAL TRANSFERRED TO YOU**, awaiting verification uses em dash when null
- Plan badges: "BASIC PLAN" text and hardcoded badges removed across all headers, drawer, and dashboard greetings.
- Customer Score Card: Volume metric displays in single line formatted as `Rs. 1,169,570.67` with responsive flex (3:2:5) and `FittedBox` scale-down safeguard.
- Sign Up Phone: Defaults to `+92` country code prefix (`🇵🇰 +92 |`) so users don't type it manually; backend normalization strips duplicate prefixes.
- KYC Stepper: Prominent horizontal connecting lines (1-2-3-4). Completed steps are solid filled with checkmarks, connected by thick 3.2px prominent lines; active step circle is hollow with 3px border for user to fill first; inactive steps/lines remain subtle.
- CNIC Hint: Fake sample placeholder `42101-1234567-1` rendered in normal font weight (w400) without bold styling.
- KYC Success Dialog: Redesigned into a compact square layout (maxWidth: 320px) with springy scale and fade entrance (Curves.easeOutBack), elastic checkmark pop-in (Curves.elasticOut), concise copy ('Account Setup Complete!', 'Your identity & bank details have been securely submitted.', 'Submitted & Under Review' badge), and spongy haptic 'Go to Dashboard' button navigating to /app/dashboard with zero overflow safeguard.
- Customer Score Card Verification Shield: Steady institutional verification shield (`Icons.verified_user_outlined`) enclosed in a subtle bordered circular badge, replacing consumer/AI-sparkle animations with bank-grade stability and zero unnecessary battery draw.
- Customer Score Card Layout & Spacing: Generous 10px vertical gap separating COMPLETED, RATE, and VOLUME labels from their values, with uppercase letter-spaced headings, bold 16.5px numeric values, and 10px column spacing with left-aligned FittedBox scale-down safeguards.
- Mobile Settings Full-Screen Navigation: When navigating to /app/settings on mobile devices, AppShell cleanly suppresses the global top bar and bottom navigation bar, granting focused full-screen presentation to Account Settings and eliminating stacked double navigation bars while preserving back navigation to Dashboard.
- Filters Bar Header Reset: 'Bitnex week' removed completely from filter bars. 'Reset' option moved into its header position beside the toggle chevron across both Dashboard and Payments pages, with illuminated active styling and spongy one-tap reset logic restoring all applied filters (Range, Currency, Status, From, To) to defaults in real time.
- Theme Changer: Relocated from mobile top bar to profile popup dialog (`ProfileMenuDialog`), featuring an animated rotating sun/moon icon, live 'Dark Mode' / 'Light Mode' label, animated pill switch, and smooth 350ms global theme transition with `Curves.easeInOutCubic` across `MaterialApp.router`.
- Account Settings Tabs: Shifted 'Bank Accounts' tab between 'Security' and 'Payments PIN' (Profile · Security · Bank Accounts · Payments PIN · Appearance) across both mobile horizontal tab bar and responsive desktop/tablet side nav, preserving all existing banking lifecycle and validation logic.
- Payments PIN Settings Startup: Opening the Payments PIN tab is immediate and does not wait for the outgoing tab animation. The page shows an inline status loader while `GET /auth/me/` email verification and `GET /auth/payments-pin/` run concurrently; PIN forms remain gated on both server responses.
- Appearance Tab Financial Display & Privacy Studio: Removed Live FX & Payout Estimator section and kept Financial Display & Privacy. Features Stealth Privacy Mode (masks sensitive balance totals to "Rs. ••••••••••" with real-time reactivity in Dashboard Customer Score card and financial cards, plus tap-to-reveal toggle), Compact Currency Notation (e.g. "Rs. 1.17M"), live preview card with institutional helper text ("Tap any masked balance on the dashboard to reveal temporarily." without decorative emojis), and one-tap defaults reset, with persistent local storage and zero overflow across 320px–1200px screens.
- Bulk Add: Commented out across the complete project (button in PaymentsPage, dialog widget, batch submission logic, and connectivity commented out as requested).
- Synchronized Balance Reveal: When Stealth Mode is enabled, tapping the eye icon next to Customer Score VOLUME or tapping any financial card immediately and simultaneously unmasks/masks all financial balances across the Dashboard (Customer Score VOLUME, PKR RECEIVED, TOTAL TRANSFERRED TO YOU, and AWAITING VERIFICATION) in real time.
- Status Summary Grid Interactive Filtering & Spongy Animations: StatusMetricCards on Dashboard (TRANSACTIONS, PENDING REVIEW, AWAITING PKR, COMPLETED) are fully interactive with spongy tap physics (SpongyTap, pressScale: 0.94, haptic feedback), illuminated status borders, subtle card glow tint, glowing active indicator dots, and 'ACTIVE' chips. Tapping any card reactively filters the RECENT ACTIVITY payments list to only show matching payments with smooth AnimatedSwitcher slide-and-fade cross-transitions, renders an active filter banner ('Showing [Status] payments (N)') with one-tap Clear, contextual empty states if no items match, and toggles back to all transactions upon tapping TRANSACTIONS or tapping the active card again.
- Full Multi-Status Filter Support: Complete filtering and presentation coverage across all 7 payment statuses (Submitted, Under Review / Pending Review, Verified, PKR Sent / Awaiting PKR, Completed, On Hold, Rejected). Selecting any status via the interactive status summary grid or the header Filters dropdown reactively updates the active filter banner with status-designated brand colors and dot indicators, renders matching items with dedicated status badge styles, and provides instant one-tap Reset/Clear across both Dashboard and My Payments pages. Authentic empty states are displayed when no transactions exist.
- Profile Picture Cropper & Alignment Dialog (`ProfilePictureCropDialog`): Centered 1:1 default crop (`cropY = (H - W) / 2.0` for portraits, `(W - H) / 2.0` for landscapes; removes the top-heavy `0.20` vertical offset that cut off lower/centered faces) combined with interactive drag-to-position, pinch/slider zoom (`1.0x`–`3.0x`), and one-tap `Reset` framing inside a clean circular preview (`Preview before saving`), rendering a matching 512×512 PNG without empty gaps or distortion. `_safeDownscaleBytes` in `AccountSettingsPage` scales down only when longest side exceeds `maxDimension` (preventing portrait upscaling) and `_buildAvatarImageOrInitial` fills the inner circular border uniformly via `SizedBox.expand`. Regulatory KYC documents (Selfie, CNIC Front, CNIC Back) continue utilizing their separate compliance enhancement pipeline.
- Dynamic Onboarding Navigation & Server Verification Retirement: The "Onboarding" navigation tab is displayed for every KYC status except `KycReviewStatus.verified`. Sign-in refreshes KYC status from `GET /accounts/profile/`; `is_profile_complete` and cached local verification do not retire onboarding. If server status cannot be confirmed, the local state falls back to unverified/pending so the tab remains visible. While the app is open, `AppShell` polls the same endpoint every 5 seconds and on resume. A server transition to `rejected` announces the decision, updates the dashboard rejection banner while retaining its `Go to profile` link, and presents resubmission; an accepted resubmission announces that updated documents await review and shows the blue notice plus `Resubmitted` status pill; a transition to `approved`/`verified` announces approval, updates profile state, removes onboarding from navigation, exposes approved payment actions, and routes `/app/onboarding` to `/app/dashboard`.
- Institutional KYC Compliance & Document Preview: Replaced consumer AI-slop image-filter bragging in regulatory KYC flows with bank-grade compliance standards. Omitted algorithmic brag badges (✓ Auto-Aligned, ✓ Glare Suppressed, ✓ Contrast Boosted) and replaced auto_awesome sparkle glyphs with steady institutional shield icons (Icons.shield_outlined). Primary KYC action buttons cleanly read 'Continue' rather than 'Enhance & Continue'. Document preview cards and account settings status badges cleanly indicate 'Uploaded' or 'Verified' rather than 'Enhanced', with regulatory SBP KYC compliance copy.
- Bank-Grade Unslop Verification & Vocabulary: Replaced all remaining AI prototype jargon, beauty filter glyphs, and brag copy throughout identity capture and settings. Replaced `Icons.face_retouching_natural_rounded` with `Icons.face_rounded` across biometric previews, document inspectors, and account settings. Elevated processing titles, stages, and badges to institutional banking standards ("Processing Identity Documents...", "Processing Biometric Photo...", "Boundary Detection • Lighting Balance • Format Verification", "Format Verification • Lighting Balance • Quality Check"). Replaced synthetic card brag badges ("AUTO-ALIGNED & GLARE SUPPRESSED" → "STATE BANK COMPLIANT"), replaced casual modal buttons ("Looks Good, Close" → "Close Preview"), and streamlined user toasts ("Profile photo updated successfully.").
- Approved Profile Lock: Account Settings derives the verified/locked profile state from the server-synchronized `KycReviewStatus.verified`. Approved profiles show the green verified-and-locked notice, keep avatar/name/phone editable, and hide editable CNIC, city, address, and KYC document replacement controls. Name and phone saves use authenticated `PATCH /auth/me/`; avatar upload/removal continues through the same endpoint. For KYC statuses that are not approved, the existing identity editing and document correction flow remains available.


