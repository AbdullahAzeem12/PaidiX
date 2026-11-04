# PaidiX — Project Brain (canonical agent context)

**Read this file first.** It is the source of truth for architecture, routing, Gradle, domain rules, and file locations. Do **not** recursively scan `lib/`, `android/`, or `build/` unless a task requires editing a specific file listed here.

- **Maintained as of:** 2026-10-30
- **App version:** `1.0.0+1` (`pubspec.yaml`)
- **Flutter package name:** `paidix`
- **Product:** Global invoice / incoming-payment / spending platform. Tagline: *Move Money. Build Trust.*
- **Current stage:** Client-side Flutter UI with **in-memory repositories**. No HTTP client, no persistence, no auth backend, no Firebase.

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
    ├── test/                         10 test files
    ├── android/                      Gradle + Kotlin host
    ├── ios/  web/  windows/ macos/ linux/   Flutter platform shells
```

**No** `assets/` in `pubspec.yaml`. **No** `lib/features/auth/data/`. **No** Riverpod / Bloc / GetX / Dio.

---

## 2. Stack & dependencies

| Layer | Choice |
| :--- | :--- |
| UI | Flutter Material 3, `MaterialApp.router` |
| Routing | `go_router` `^14.8.1` |
| State | Widget local `setState` + one shared `ValueNotifier` on payments |
| Images | `image_picker` `^1.2.4` (KYC only) |
| Permissions | `permission_handler` `^13.0.2` |
| Notifications | `flutter_local_notifications` `^22.3.3` (Android channel `paidix_kyc_channel`) |
| Icons | `cupertino_icons` `^1.0.8` |
| SDK | Dart `>=3.0.0 <4.0.0`, Flutter `>=3.10.0` |
| Lint | `flutter_lints` `^5.0.0` via `package:lints/recommended.yaml` |
| Analyzer excludes | `build/**`, `android/**`, `ios/**`, `web/**`, `windows/**`, `macos/**`, `linux/**` |

---

## 3. Android / Gradle (exact)

All paths relative to `PaidiX/android/`.

### 3.1 `settings.gradle.kts`

- Resolves Flutter SDK from `local.properties` → `flutter.sdk` (required).
- `includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")`
- Plugins: `dev.flutter.flutter-plugin-loader` **1.0.0**, `com.android.application` **9.1.0** (apply false), `org.jetbrains.kotlin.android` **2.4.0** (apply false)
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

`gradle-wrapper.properties` → **Gradle 9.3.1-all**. `DEFAULT_JVM_OPTS` in `gradlew.bat` and `gradlew` sets `--enable-native-access=ALL-UNNAMED` to eliminate Java 25+ JEP 472 restricted method (`System.load`) warnings from `net.rubygrapefruit.platform`.

### 3.6 Manifests & host

**`app/src/main/AndroidManifest.xml`**

- Permissions: `CAMERA`, `READ_EXTERNAL_STORAGE` (maxSdk 32), `WRITE_EXTERNAL_STORAGE` (maxSdk 32), `READ_MEDIA_IMAGES`, `POST_NOTIFICATIONS`
- Label: `PaidiX`, icon `@mipmap/ic_launcher`, roundIcon `@mipmap/ic_launcher_round`
- Adaptive Icons: `mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_round.xml` with `@color/ic_launcher_background` (`#022F32`) and centered safe-zone `@mipmap/ic_launcher_foreground`
- Activity: `.MainActivity`, `singleTop`, `adjustResize`, Flutter embedding **2**
- **Impeller disabled:** `io.flutter.embedding.android.EnableImpeller` = `false`

**`MainActivity.kt`** (`com.paidix.paidix`): `FlutterActivity` configured with `RenderMode.texture` (`getRenderMode()` and AndroidManifest meta-data) to permanently prevent black/blank screen freezes when resuming from external Gallery/Camera activities on Huawei EMUI/HarmonyOS devices.

**Debug/profile manifests:** `INTERNET` only (hot reload).

**Splash & Brand Colors:** light `#EFF3F0`, night `#031415`, icon background `#022F32` (`values/colors.xml`, `values-night/colors.xml`). Launch drawables exist for both.

**Release APK Builds (`release/` & `build/app/outputs/flutter-apk/`):**
- **Universal Fat APK:** `PaidiX-v1.0.0-Universal.apk` (51.8 MB) — works on 100% of Android devices.
- **Arm64 Lightweight APK:** `PaidiX-v1.0.0-arm64-v8a.apk` (18.0 MB) — 65% smaller, high-performance for all modern Android phones.
- **Armeabi-v7a APK:** `PaidiX-v1.0.0-armeabi-v7a.apk` (15.7 MB) — for older 32-bit Android phones.
- **x86_64 APK:** `PaidiX-v1.0.0-x86_64.apk` (19.5 MB) — for Android emulators and ChromeOS.

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
│   ├── services/notification_service.dart
│   ├── utils/                formatters, payment validators, CNIC
│   └── widgets/              shell, buttons, fields, badges, nav
└── features/
    ├── auth/                 domain models + validators + sign in/up pages (no repository)
    ├── kyc/                  models, image processor (simulated), 4-step UI
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

There is **no** HTTP client or auth backend. User profile, KYC identity documents (Selfie, CNIC Front, CNIC Back), and avatar are stored persistently via `UserProfileRepository` in local device storage (`paidix_users/<email>/profile.json` and image files) with synchronized in-memory caching, surviving logout, re-login, and app restarts. Payments repository remains process-memory based.

---

## 6. Routing & user journeys

Defined in `lib/app/router.dart`. Transitions: fade (most), slide+fade for `/app/payments/new`.

| Path | Shell? | Page | Notes |
| :--- | :---: | :--- | :--- |
| `/signin` | no | `SignInPage` | **Default initialLocation** |
| `/signup` | no | `SignUpPage` | Accessible via "Create an account" link |
| `/kyc` | no | `KycPage` | 4 steps, no app chrome |
| `/app/dashboard` | **AppShell** | `DashboardPage` | |
| `/app/onboarding` | **AppShell** | `OnboardingProfilePage` | Dynamic user profile & KYC review |
| `/app/settings` | AppShell | `AccountSettingsPage` | 5-tab settings: Profile (read/edit name, phone with single +92 prefix without duplication, CNIC, city, address, camera badge avatar with auto-crop & enhance, responsive update/remove avatar dialog with fallback to initial letter "A", and high-fidelity 3-card saved documents section for Selfie, CNIC Front, CNIC Back featuring emerald preview banner, header row with `✓ Enhanced` badges, 155px container with floating zoom lens overlay, tap-to-inspect `DocumentViewerDialog`, and spongy `Replace` flow), Security (password update, 3 eye-toggle fields), Bank Accounts (responsive cards matching desktop/mobile specifications: gold ACCOUNTS eyebrow, security audit notice, PKR RECEIVING (PAKISTAN) + Add account pill, cards with uppercase bank headers, ☆ Primary badge / Set as primary toggle, prominent holder title, •••• •••• 2786 masked number, divider, Edit and Remove actions with confirmation dialog; Edit/Add Pakistani bank account modal with audit notice, 18-bank catalog picker, letters-only / digits-only validation, optional IBAN, persistent storage via UserProfileRepository in paidix_users/<email>/bank_accounts.json, and zero overflow on 320px–1200px), Payments PIN (4–8 digit lock, update with previous PIN verification, email recovery, and destructive remove), Appearance (Dark/Light/System theme cards + Virtual Card Studio with 4 metallic/holographic skins: Emerald Obsidian, Prismatic Hologram, Champagne Gold, Stealth Carbon, EMV microchip, holographic sheen animation, and privacy mask toggle). Slide-in/slide-out page transition. Tapping the back button (`_buildMobileTopBar` and `_buildSideNav`) navigates directly to `/app/dashboard` with spongy haptic feedback and smooth easeOutCubic slide+fade transition. Responsive wide breakpoint requires `width >= 768 && height >= 520` so tilted/landscape mobile phones (740x360, 800x360, 850x390, 896x414) automatically render the mobile layout with the 48px horizontal tab bar and full-width content, completely eliminating the 223px sidebar flex overflow; sidebar navigation and modal dialogs are wrapped in `SingleChildScrollView` to guarantee zero pixel overflow on any phone orientation. |
| `/app/payments` | AppShell | `PaymentsPage` | Payments list with `SmoothAnimatedListItem` pop-in/fade-in entrance & bouncy physics, search, interactive `PaginationControls` (Showing range, interactive Rows selector chips 10/20/30/50/100/Custom, Page navigation with direct jump dialog), bulk add dialog, and collapsible `PaymentsFilterBar` (closed by default, animated expand/collapse, horizontal slider for side-by-side Range/Currency/Status chips with popup menus) |
| `/app/payments/new` | AppShell | `NewPaymentPage` | nested under payments |

**Auth (simulated 600ms delay, no API):**

- Sign up success: registers user with `hasCompletedKyc: false` → routes to `/kyc` for initial onboarding
- Sign in: if email contains `admin` or `verified`, or account has completed KYC (`hasCompletedKyc == true`) → `/app/dashboard`; else unverified new user → `/kyc`
- Forgot password: dialog only (“instructions will be sent”)
- Sign-up SMS consent is a checkbox; phone is optional

**KYC:**

- Header can `go('/signin')`
- Submit last step: saves all KYC details permanently, sets `hasCompletedKyc: true` → `KycSuccessDialog` (non-dismissible) → **Go to Dashboard** → `/app/dashboard`. Zero push notifications during document/selfie enhancement.

**AppShell nav (wide ≥768 && height ≥520 sidebar; else bottom bar):**

0. Dashboard `/app/dashboard`
1. Onboarding `/app/onboarding`
2. My Payments `/app/payments`
3. New Payment `/app/payments/new`

Bottom navigation bar (`PaidiXBottomNavBar`) provides fully responsive adaptive horizontal spacing (320px–480px+), zero text truncation via auto-fitting typography (`FittedBox(fit: BoxFit.scaleDown)`), 0ms raw pointer touch compression (`Curves.easeInOutCubic`), bouncy spring release (`Curves.easeOutBack` on scale), animated icon scaling & color transitions, active pill illumination, and fluid micro-indicator accent lines with strictly monotonic easing (`Curves.easeOutCubic`) to guarantee non-negative `BoxShadow` blur radii during backward and forward tab transitions.

Dynamic user profile state via `UserProfileRepository.instance`. Default profile: **Abdullah Azeem** / `kheroali66@gmail.com` (with `kherool66@gmail.com` synchronized alias) / avatar **A**. Dashboard greeting: **Hello, ${profile.firstName}.** Plan badge: **BASIC PLAN**. Edit Profile & Account Settings provide real-time updates, single clean `PK +92` phone prefix without duplication, elevated camera badge avatar (76px/88px diameter, aqua ambient halo, high-contrast floating badge, centered face alignment `Alignment(0.0, -0.22)`), interactive update/remove avatar modal restoring initial letter "A", and responsive 3-card saved documents section (Selfie, CNIC Front, CNIC Back). For Selfie: dedicated biometric portrait presentation with atmospheric frosted blurred backdrop, centered 118x144 emerald-framed portrait preview targeting human face/eyes without vertical squishing (background radial guide ring removed for a clean focused look), `PORTRAIT BIOMETRIC` badge, tap-to-inspect `DocumentViewerDialog`, and spongy `Replace` action with zero overflow across 320px–1200px screens. User profile details, custom avatars, and regulatory documents are persisted to local device storage and restored automatically upon re-login. Avatar updates are synchronized across `AppShell` mobile header and desktop sidebar.

---

## 7. Domain rules (money, status, KYC)

### 7.1 Payments — `PaymentsRepositoryImpl`

Constants (must stay in sync with tests):

- Fee: **12%** of USD amount
- FX: **1 USD = 273 PKR**
- Reference prefix: `PBX-2026-00` + incrementing counter starting at **1334**
- New item `id`: `pay_<epochMs>`
- **Every `submitPayment` sets `status: PaymentStatusType.completed`**
- List is newest-first (`insert(0, ...)`)
- Default constructor `PaymentsRepositoryImpl({bool seedMockData = false})` starts **empty** by default for unit tests, while `sharedPaymentsRepository` in `router.dart` enables `seedMockData: true` so all active users immediately experience 24 realistic mock items where the top 4 exactly mirror production screenshots (`PBX-2026-001332`, `PBX-2026-001331`, `PBX-2026-001333`, `PBX-2026-001330`). Methods `seedMockData()` and `clearPayments()` are available on repository.

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

**New payment proof & submission:** Native `ImagePicker` (`ImageSource.gallery`) with memory bounding (`maxWidth: 2400`, `maxHeight: 2400`, `imageQuality: 88`) and Android/Huawei activity lifecycle recovery via `_picker.retrieveLostData()` in `initState()`. Proof attachment stores `proofFileName`, `proofFilePath`, and `proofBytes` in `PaymentItem` and `PaymentSubmission`. Features interactive file preview (24x24 thumbnail, truncated filename, clear `[X]` button, and `BROWSE` button with loading indicator). Backend submission pipeline validates fields, creates `PaymentSubmission`, invokes `paymentsRepository.submitPayment()`, fires push notification via `NotificationService.instance.showNotification(id: 17, ...)`, displays a floating emerald SnackBar, and transitions to `/app/payments`.

**Bulk Add Payments Dialog (`BulkAddPaymentsDialog`):** Built with adaptive landscape/tilt mode protection (`isLandscape = size.width > size.height && size.height < 520`). On phone tilt/landscape orientations (`740x360`, `800x360`, `850x390`, `896x414`, `640x320`), margin and padding are automatically compacted (`vertical: 3` and `6`), the multi-line instruction paragraph condenses to a single-line summary, toolbar actions wrap with minimal spacing, and the footer transitions from a stacked column to a side-by-side horizontal `Row` with compact 34px buttons and omits the multi-line browser storage disclaimer. The spreadsheet/mobile card grid is wrapped in `Expanded` inside the main dialog flex column, completely eliminating the 6.9px bottom flex overflow and guaranteeing 0 pixel overflow across all phone tilt orientations.

**Interactive Pagination Controls (`PaginationControls`):** Interactive "Showing X–Y of Z", "Rows: 10, 20, 30, 50, 100, Custom", and "Page X of N" navigation with first (`«`), previous (`< Prev`), page jump dialog, next (`Next >`), and last (`»`) controls. Mobile layout wraps `pageNavControls` in a horizontal scroll view to guarantee zero overflow even on ultra-compact 320px screen widths.

### 7.2 Status enum — `PaymentStatusType` (`status_badge.dart`)

`submitted` | `underReview` | `verified` | `pkrSent` | `completed` | `onHold` | `rejected` (with legacy aliases `pendingReview` → `underReview`, `awaitingPkr` → `pkrSent`). Each status has designated badge styling and colors. Filter dropdown displays all 8 statuses with animated checkmarks. Header includes `Bitnex week` quick-filter toggle button beside accordion chevron.

### 7.3 Dashboard — `DashboardRepositoryImpl`

**Empty list:** `CustomerScore` with `score: null`, `trustLabel: 'NEW ACCOUNT'`; `FinancialSummary.empty()` (zeros + `awaitingVerificationAmount: null` → em dash).

**Non-empty list:**

- Customer score **hardcoded** `79`, grade **`B`**, label **`TRUSTED`**
- `completedTransactions` / `completionRate` / `totalVolumePkr` computed from completed items
- Financial **hero money fields stay 0 / null**: `pkrReceived`, `paymentsCompleted`, `totalTransferred`, `awaitingVerificationAmount` are **not** summed from payments
- Status **counts** (`transactionsCount`, pending, awaiting, completed) **are** derived from the list

Do not “fix” the zero PKR cards unless the product asks — it is current implemented behavior, not an accident in empty-state only.

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

**Typography & Interactive Font System:**
- Reactive dynamic font selection via `AppTheme.fontFamilyNotifier` (`ValueNotifier<String>`, default `'System default'`).
- 10 supported font families: System default, Inter, Roboto, Poppins, Lato, Nunito, Open Sans, DM Sans, Source Sans 3, IBM Plex Sans (via `google_fonts: ^9.0.0` with offline test fallback `GoogleFonts.config.allowRuntimeFetching = false`).
- Text scale reactivity via `AppTheme.textScaleNotifier` (`ValueNotifier<double>`, range 80%–140%, default 100%).
- Persistent preferences in local storage (`paidix_appearance.json`).
- `AppTypography` dynamically connects every typography style to `AppTheme.activeFontFamily`, while the root `PaidiXApp` injects `MediaQuery.copyWith(textScaler: TextScaler.linear(scale))` wrapped in a multi-listenable builder.
- Account Settings `Appearance` tab font picker: responsive 2-column grid (`childAspectRatio: 2.2`) with tiles auto-scaled via `FittedBox(fit: BoxFit.scaleDown)` to guarantee zero pixel overflows across all phone widths (320px–480px+) and text scales, preview box ("Send USD, receive PKR.") rendered in the active font, interactive slider, and "Reset to defaults" action.

**Spacing:** xs 4 … xxxl 32; radii 6 / 10 / 14 / 18 / pill 999.  
**Motion:** fast 120 / normal 220 / medium 320 / slow 450; button press scale **0.96** (`AppMotion`); `AppButton` uses **0.945** over 110ms + 260ms `easeOutBack`.  
**Breakpoints used in UI:** ~360 narrow phone, ~380 auth/KYC, **768** tablet shell/table vs cards, ~850 dashboard finance row.

Typography: heavy headings (w800/w900), tabular-looking stats, uppercase eyebrows with letter-spacing.

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
- `lib/features/kyc/presentation/pages/kyc_page.dart`
- widgets: `kyc_header`, `kyc_stepper`, `kyc_success_dialog`, `kyc_permission_dialog`, `kyc_file_picker_tile`, `step1_personal_view`, `step2_identity_view`, `step3_photo_view`, `step4_bank_view`

### Profile & Onboarding

- `lib/features/profile/domain/user_profile.dart`
- `lib/features/profile/data/user_profile_repository.dart`
- `lib/features/profile/presentation/pages/onboarding_profile_page.dart`
- widgets: `profile_info_card.dart`, `kyc_review_card.dart`, `document_preview_tile.dart`, `document_viewer_dialog.dart`, `edit_profile_dialog.dart`

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
- pages: `payments_page.dart`, `new_payment_page.dart`
- widgets: `payments_table`, `payments_filter_bar`, `payment_card`, `pagination_controls` (page sizes 10/20/30/50/100, default 20), `bulk_add_payments_dialog` (desktop table grid + mobile responsive card mode, dynamic totals, duplicate/delete/add row toolbar, batch submission)

### Settings

- `lib/features/settings/domain/virtual_card_skin.dart`
- `lib/features/settings/presentation/pages/account_settings_page.dart`
- widgets: `virtual_card_studio.dart`

---

## 11. Tests (`PaidiX/test/`)

| File | Covers |
| :--- | :--- |
| `widget_test.dart` | Default route is Sign Up copy |
| `auth_validators_test.dart` | Auth validators |
| `payment_validators_test.dart` | Payment validators |
| `app_formatters_test.dart` | Currency/date/em dash |
| `payments_repository_test.dart` | Empty start, fee/FX, search filter |
| `payments_page_test.dart` | Payments UI, accordion filters, side-by-side chips slider, status dropdown, Bitnex settlement week filter, BulkAddPaymentsDialog with dynamic row computation, row tools (+1, +5, +10, duplicate, delete), batch payment submission, and multi-width responsiveness (360px mobile, 1024px desktop) with zero pixel overflow |
| `new_payment_page_test.dart` | New payment form |
| `onboarding_profile_test.dart` | Profile sync, real-time edit dialog, KYC document viewer, 320px narrow zero-overflow |
| `dashboard_page_test.dart` | Dashboard empty/reactive |
| `theme_test.dart` | Color tokens, theme toggle, badges, nav |
| `kyc_test.dart` | CNIC, KYC models, processor, some widgets |

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
6. Keep Impeller off + texture render mode unless explicitly changing graphics stack.

**Gaps / traps**

- No backend, no secure storage, passwords stay in memory of the form only.
- Auth “success” is a timer.
- KYC enhancement and CNIC registry are simulated.
- iOS privacy usage strings configured in Info.plist (NSCameraUsageDescription & NSPhotoLibraryUsageDescription); automated iOS IPA cloud builds via GitHub Actions (.github/workflows/build_ios.yml).
- Release APK signed with debug keystore.
- `CurrencyFilter` unused in `filterPayments`.
- Dashboard PKR received / transferred stay 0 after completed payments.
- Customer score 79/B is static once any payment exists.
- New payments always `completed`.
- Sidebar user is hardcoded, not from sign-up.
- README architecture section omits KYC and is slightly stale vs this brain.
- `BankInfo.isValid` IBAN length vs step-4 UI length differ.
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
- Customer Score Card Star Animation: Eye-catching continuous yellow blinking and breathing animation (scale 0.88-1.25x, opacity 0.55-1.0, amber-to-radiant-gold ColorTween #F59E0B -> #FFE600, with glowing radial box-shadow halo).
- Customer Score Card Layout & Spacing: Generous 10px vertical gap separating COMPLETED, RATE, and VOLUME labels from their values, with uppercase letter-spaced headings, bold 16.5px numeric values, and 10px column spacing with left-aligned FittedBox scale-down safeguards.
- Filters Bar Header Reset: 'Bitnex week' removed completely from filter bars. 'Reset' option moved into its header position beside the toggle chevron across both Dashboard and Payments pages, with illuminated active styling and spongy one-tap reset logic restoring all applied filters (Range, Currency, Status, From, To) to defaults in real time.
- Theme Changer: Relocated from mobile top bar to profile popup dialog (`ProfileMenuDialog`), featuring an animated rotating sun/moon icon, live 'Dark Mode' / 'Light Mode' label, animated pill switch, and smooth 350ms global theme transition with `Curves.easeInOutCubic` across `MaterialApp.router`.
- Account Settings Tabs: Shifted 'Bank Accounts' tab between 'Security' and 'Payments PIN' (Profile · Security · Bank Accounts · Payments PIN · Appearance) across both mobile horizontal tab bar and responsive desktop/tablet side nav, preserving all existing banking lifecycle and validation logic.
- Appearance Tab Virtual Card Studio: Replaced Typography section with Virtual Card Skins Studio. Features an interactive 3D virtual receiving card with metallic finishes, continuous holographic light sheen reflection, realistic gold EMV smart chip, cardholder details, 1-LINK PayPak insignia, number privacy mask toggle (•••• 2786 vs full 16 digits), and 4 curated luxury finishes (Emerald Obsidian, Prismatic Hologram, Champagne Gold, Stealth Carbon) with persistent storage and zero overflow across 320px–1200px screens.
