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
4. Default theme is **dark**. Sidebar chrome is **never inverted** (`AppColors.sidebar*`).
5. Prefer `AppColors.of(context)` in widgets; static `AppColors.*` getters follow `themeModeNotifier` (not always the widget tree).
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
```

### 3.5 Wrapper

`gradle-wrapper.properties` → **Gradle 9.3.1-all**

### 3.6 Manifests & host

**`app/src/main/AndroidManifest.xml`**

- Permissions: `CAMERA`, `READ_EXTERNAL_STORAGE` (maxSdk 32), `READ_MEDIA_IMAGES`, `POST_NOTIFICATIONS`
- Label: `PaidiX`, icon `@mipmap/ic_launcher`
- Activity: `.MainActivity`, `singleTop`, `adjustResize`, Flutter embedding **2**
- **Impeller disabled:** `io.flutter.embedding.android.EnableImpeller` = `false`

**`MainActivity.kt`** (`com.paidix.paidix`): `FlutterActivity` with **`RenderMode.texture`** (not surface). Keep this unless Impeller/surface is proven stable on target devices.

**Debug/profile manifests:** `INTERNET` only (hot reload).

**Splash:** light `#EFF3F0`, night `#031415` (`values/colors.xml`, `values-night/colors.xml`). Launch drawables exist for both.

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
    └── payments/             models, abstract repo, in-memory impl, list + new form
```

**Dependency direction:** `dashboard` → `payments` repository. Pages under `/app/*` receive `PaymentsRepositoryImpl` (concrete) so they can listen to `paymentsListenable`.

**Shared singleton (process memory, not DI):**

```dart
// lib/app/router.dart
final sharedPaymentsRepository = PaymentsRepositoryImpl();
final appRouter = createAppRouter(initialLocation: '/signup');
```

Tests that need a clean router should call `createAppRouter(...)` with a fresh location; production uses `appRouter`.

There is **no** auth session, token store, or KYC persistence. Killing the app resets payments and KYC.

---

## 6. Routing & user journeys

Defined in `lib/app/router.dart`. Transitions: fade (most), slide+fade for `/app/payments/new`.

| Path | Shell? | Page | Notes |
| :--- | :---: | :--- | :--- |
| `/signup` | no | `SignUpPage` | **Default initialLocation** |
| `/signin` | no | `SignInPage` | |
| `/kyc` | no | `KycPage` | 4 steps, no app chrome |
| `/app/dashboard` | **AppShell** | `DashboardPage` | |
| `/app/onboarding` | **AppShell** | `OnboardingProfilePage` | Dynamic user profile & KYC review |
| `/app/payments` | AppShell | `PaymentsPage` | Payments list, search, pagination, bulk add dialog, and collapsible `PaymentsFilterBar` (closed by default, animated expand/collapse, horizontal slider for side-by-side Range/Currency/Status chips with popup menus) |
| `/app/payments/new` | AppShell | `NewPaymentPage` | nested under payments |

**Auth (simulated 600ms delay, no API):**

- Sign up success → `/kyc`
- Sign in: if email contains `admin` **or** `verified` → `/app/dashboard`; else → `/kyc`
- Forgot password: dialog only (“instructions will be sent”)
- Sign-up SMS consent is a checkbox; phone is optional

**KYC:**

- Header can `go('/signin')`
- Submit last step → `KycSuccessDialog` (non-dismissible) → **Go to Dashboard** → `/app/dashboard`

**AppShell nav (wide ≥768 sidebar; else bottom bar):**

0. Dashboard `/app/dashboard`
1. Onboarding `/app/onboarding`
2. My Payments `/app/payments`
3. New Payment `/app/payments/new`

Bottom navigation bar (`PaidiXBottomNavBar`) provides fully responsive adaptive horizontal spacing (320px–480px+), zero text truncation via auto-fitting typography (`FittedBox(fit: BoxFit.scaleDown)`), 0ms raw pointer touch compression (`Curves.easeInOutCubic`), bouncy spring release (`Curves.easeOutBack`), animated icon scaling & color transitions, active pill illumination, and glowing micro-indicator accent lines.

Dynamic user profile state via `UserProfileRepository.instance`. Default profile: **Abdullah Azeem** / `kherool66@gmail.com` / avatar **A**. Dashboard greeting: **Hello, ${profile.firstName}.** Plan badge: **BASIC PLAN**. Edit Profile modal provides real-time updates, timestamp refresh, and gallery-based re-upload of KYC documents (Selfie, CNIC Front, CNIC Back) with responsive mobile & wide desktop layouts, tactile spongy click compression, and auto-wrapping responsive toast notifications.

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
- Starts **empty** (product invariant)

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

**New payment proof:** `_simulateFilePick()` assigns a fake filename; not `image_picker`.

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

**Spacing:** xs 4 … xxxl 32; radii 6 / 10 / 14 / 18 / pill 999.  
**Motion:** fast 120 / normal 220 / medium 320 / slow 450; button press scale **0.96** (`AppMotion`); `AppButton` uses **0.945** over 110ms + 260ms `easeOutBack`.  
**Breakpoints used in UI:** ~360 narrow phone, ~380 auth/KYC, **768** tablet shell/table vs cards, ~850 dashboard finance row.

Typography: heavy headings (w800/w900), tabular-looking stats, uppercase eyebrows with letter-spacing.

---

## 9. Core widgets (reuse these; do not fork)

| File | Role |
| :--- | :--- |
| `app_shell.dart` | Responsive chrome + theme toggle |
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
5. App starts at **`/signup`**.
6. Keep Impeller off + texture render mode unless explicitly changing graphics stack.

**Gaps / traps**

- No backend, no secure storage, passwords stay in memory of the form only.
- Auth “success” is a timer.
- KYC enhancement and CNIC registry are simulated.
- iOS privacy usage strings missing.
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
