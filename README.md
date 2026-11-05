# PaidiX — Global Invoice, Payout & Cross-Border Settlement Platform

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A53.10.0-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%E2%89%A53.0.0-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Material Design](https://img.shields.io/badge/Material%203-Abyssal%20Teal-0A3134?logo=materialdesign&logoColor=white)](https://m3.material.io)
[![Tests](https://img.shields.io/badge/Tests-120%2F120%20Passing-brightgreen?logo=checkmarx&logoColor=white)]()
[![Code Quality](https://img.shields.io/badge/flutter%20analyze-0%20issues-brightgreen?logo=dart&logoColor=white)]()
[![Release APK](https://img.shields.io/badge/Android%20APK-v1.0.0%20Ready-0E7C7B?logo=android&logoColor=white)](PaidiX.apk)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)]()

### **Move Money. Build Trust.**
*The high-velocity financial bridge empowering international freelancers, remote contractors, agencies, and cross-border businesses to settle USD & foreign revenues directly into Pakistani bank accounts with bank-grade security, zero hidden deductions, and 1-LINK instant transfers.*

[📥 Download Release APK (PaidiX.apk)](PaidiX.apk) • [📖 Key Features](#-key-features) • [📐 Architecture & Invariants](#-domain-formulas--invariants) • [🧪 Test Verification](#-quality-assurance--testing)

</div>

---

## 🌟 About PaidiX

**PaidiX** is a production-grade cross-border remittance, invoice clearance, and merchant payout application built with Flutter & Dart. It bridges the financial divide between global clients paying via US/international payment rails (such as **Cash App**, **Zelle**, and direct wires) and Pakistani beneficiaries who require fast, reliable settlement into local commercial bank accounts and microfinance wallets (**Meezan Bank, HBL, UBL, Standard Chartered, Bank Alfalah, SadaPay, NayaPay, JazzCash, EasyPaisa**).

### 💡 The Problem
Pakistani digital creators, software engineers, exporters, and remote contractors collectively earn billions in foreign revenue annually, yet face persistent hurdles:
- **Exorbitant Intermediary Deductions:** Traditional banking corridors drain 8%–18% in cumulative hidden wire fees, unexpected correspondent bank charges, and predatory forex markups.
- **Settlement Lag & Friction:** Clearing foreign checks and standard SWIFT wires frequently takes 4 to 10 business days.
- **Opaque Compliance Delays:** Regulatory compliance often flags incoming transfers without clear status tracking, leaving payees stranded.
- **Privacy Exposure:** Displaying gross revenue figures in public or shared working spaces exposes users to unwanted financial visibility.

### 🛡️ The PaidiX Solution
PaidiX eliminates cross-border financial friction with a transparent, developer-first architecture:
1. **Guaranteed 12% Flat Settlement:** Fully disclosed platform fee with zero surprise deductions—every cent is mathematically verifiable.
2. **Fixed SBP Interbank Baseline FX:** Direct real-time conversion at **1 USD = 273.00 PKR**, backed by State Bank of Pakistan 1-LINK and PRISM routing.
3. **Dynamic Customer Trust Scoring:** An intelligent credit grading engine (`A+` to `D`) that evaluates payment history, volume milestones, and completion rates to reward consistent users.
4. **Stealth Financial Privacy Studio:** Synchronized one-tap privacy masking (`Rs. •••••••••`) that obscures sensitive balances across the Dashboard and executive summaries.
5. **One-Time Biometric & CNIC KYC:** Rapid 4-step regulatory identity verification with persistent encrypted on-device caching, automatic returning-user dashboard routing, and interactive document inspection.
6. **Bank-Grade Payments PIN Security:** 4–8 digit PIN architecture with previous-PIN verification, email recovery, and brute-force mitigation.
7. **Pixel-Perfect Responsive Engine:** Built upon an **Abyssal Teal** Material 3 design system, guaranteeing zero `RenderFlex` overflow across viewports from ultra-compact 320px phones to 1200px+ desktop workstations.

---

## 🚀 Key Features

### 1. Executive Financial Dashboard & Analytics
- **Customer Trust Score Hero Card:** Ambient mint-teal card (`#80EEDC`) featuring real-time trust grading (`84 A TRUSTED`), dynamic completion rate (e.g., 75%–100%), volume tracking, and interactive status routing.
- **Synchronized Stealth Privacy Mode:** One-tap toggle via the eye icon on Customer Score VOLUME instantly masks/unmasks balances across **PKR Received**, **Total Transferred to You**, and volume summaries simultaneously.
- **Interactive Status Metrics Grid:** Kinetic count cards tracking **Transactions**, **Pending Review**, **Awaiting PKR**, and **Completed** with bouncy `SpongyTap` physics, glowing border illumination, and real-time filtered list transitions.
- **Financial Metric Cards:** Clear, reactive balance representations for lifetime transferred volume and net deposited PKR with graceful em dash (`—`) empty states.

### 2. Multi-Status Payments & Settlement Engine
- **Comprehensive Lifecycle Tracking:** Full support for 7 authoritative regulatory payment statuses:
  - `Submitted` — Transaction initiated with proof attached.
  - `Under Review` / `Pending Review` — Under regulatory compliance inspection.
  - `Verified` — Sender confirmation code and proof validated.
  - `PKR Sent` / `Awaiting PKR` — SBP 1-LINK local interbank transfer initiated.
  - `Completed` — Net PKR credited to recipient's bank account.
  - `On Hold` — Requires beneficiary or document clarification.
  - `Rejected` — Invalid reference code or fraudulent submission.
- **Expandable Accordion Filter Bar:** Collapsed by default; expands with smooth hardware-accelerated transitions featuring side-by-side chips for **Range**, **Currency**, and **Status**.
- **Interactive Pagination Controls:** Full page navigation ("Showing X–Y of Z", direct page jump dialog, and interactive Rows selector: 10, 20, 30, 50, 100, Custom) with zero horizontal overflow on 320px devices.
- **Live Search Engine:** Real-time multi-field substring queries against reference code, sender name, company, and transaction amount.

### 3. Account Settings & Security Suite
A comprehensive 5-tab settings management interface:
- **Profile Tab:** View and update full name, verified Pakistani phone (`PK +92`), CNIC number, city, and residential address with persistent local device storage. Features a 76px/88px camera-badge avatar with auto-crop and fallback initial letter icon.
- **Regulatory Document Gallery:** High-fidelity 3-card saved documents showcase for **Biometric Selfie**, **CNIC Front**, and **CNIC Back** featuring emerald preview banners, `✓ Enhanced` badges, floating zoom lens overlays, and tap-to-inspect `DocumentViewerDialog`.
- **Security Tab:** Password update module with real-time validation and 3 independent eye-toggle visibility fields.
- **Bank Accounts Tab:** Responsive Pakistani bank account management matching State Bank of Pakistan standards. Includes 18-bank catalog picker (Meezan, HBL, UBL, Alfalah, SadaPay, etc.), primary account toggles (`☆ Primary`), masked account numbers (`•••• •••• 2786`), and audit-ready IBAN validators.
- **Payments PIN Tab:** 4–8 digit transaction security lock with previous PIN verification, email recovery mechanism, and destructive removal safeguards.
- **Appearance & Privacy Studio:** Material 3 Dark/Light/System theme toggles, 10 dynamic Google Fonts typographies (Inter, Roboto, Poppins, Lato, Nunito, DM Sans, etc.), text scaling slider (80%–140%), and Stealth Privacy preferences.

### 4. Regulatory KYC & Bank Onboarding
- **4-Step Regulatory Onboarding Flow:**
  - **Step 1 — Personal Info:** Full name, residential address, city, and responsive phone selector with real-time formatting (`XXX XXXXXXX` for PK, `(XXX) XXX-XXXX` for US).
  - **Step 2 — Identity Documents:** Front and back national identity (CNIC) capture with format validation (`35202-XXXXXXX-X`).
  - **Step 3 — Biometric Liveness:** High-resolution selfie capture with biometric face-alignment framing and ambient frosted backdrop.
  - **Step 4 — Pakistani Bank Clearance:** Real-time routing against 18 Pakistani commercial banks and SBP 1-LINK directories.
- **One-Time Verification & Smart Routing:** Once KYC is completed, identity data is persisted locally and returning users are automatically routed directly to the Dashboard upon login.

### 5. Kinesthetic Touch & Responsive Design
- **SpongyTap Physics:** High-frequency 0ms raw pointer touch compression (`0.945` scale) with bouncy `Curves.easeOutBack` spring-back release.
- **Adaptive Screen Transitions:** Smooth slide-and-fade page transitions with responsive wide breakpoints (`width >= 768 && height >= 520`) preventing sidebar flex overflows on rotated or landscape mobile screens.
- **Zero Pixel Overflow Guarantee:** Rigorously engineered and verified across 320px, 360px, 414px, 768px, 1024px, and 1200px viewports with zero `RenderFlex` exceptions.

---

## 🎨 Design System & Visual Tokens

PaidiX is built on an **Abyssal Dark Teal** financial aesthetic inspired by deep-sea tranquility and Swiss fintech precision:

| Design Token | Hex Code | Visual Role |
| :--- | :--- | :--- |
| **App Background** | `#031415` | Abyssal teal deep canvas |
| **Navigation Surface** | `#022F32` | Dark teal navigation bar and fixed desktop sidebar |
| **Card / Panel Surface**| `#0A3134` | Elevated content panels and modal dialogs |
| **Card Highlight** | `#0E3D41` | Elevated chip backgrounds and interactive items |
| **Panel Border** | `#13474B` | Subtle panel structural outlines |
| **Primary Accent (Aqua)**| `#5FCFC9` | Primary action buttons, active borders, illuminated icons |
| **Light Aqua** | `#95DFDB` | Highlights, focused indicators, and link labels |
| **Mint Hero Surface** | `#80EEDC` | Customer score hero card container |
| **Brand Gold** | `#EFC479` | "Build Trust." logo accent, pending status badge |
| **Status Emerald** | `#10B981` | Completed / verified state indicators |
| **Status Amber** | `#F59E0B` | Under review / pending state indicators |
| **Status Rose** | `#E11D48` | Rejected / error state indicators |

---

## 📐 Domain Formulas & Invariants

### Transparent Fee & Net Payout Formula
All incoming payment submissions calculate fees and net proceeds according to the verified platform formula:

$$\text{feeAmount} = \frac{\text{amount} \times 12.0}{100.0}$$

$$\text{netUSD} = \text{amount} - \text{feeAmount}$$

$$\text{netPKR} = \text{netUSD} \times 273.0$$

- **Platform Processing Fee:** Authoritative **12.0%** transparent deduction.
- **Exchange Baseline Rate:** Authoritative **1 USD = 273.00 PKR** interbank rate.
- **Standard Benchmark:** A gross transfer of **\$171.00 USD** yields exactly **\$20.52 USD** platform fee and **Rs. 41,081.04 net PKR** deposited directly to the recipient's bank account.
- **Reference Code Sequencing:** Standard prefix `PBX-2026-00` with incrementing counter starting at `1334`.

---

## 📂 Architecture & Directory Structure

PaidiX follows clean, feature-first modular architecture with unidirectional state flow:

```
lib/
├── main.dart                          # Application entry point & global error handling
├── app/
│   ├── app.dart                       # MaterialApp.router with reactive ThemeMode
│   ├── router.dart                    # go_router declarative routes & transition curves
│   └── theme/
│       ├── app_colors.dart            # Complete design system color tokens
│       ├── app_theme.dart             # Material 3 dark & light theme definitions
│       ├── app_typography.dart        # Inter & dynamic Google Fonts typographic scale
│       ├── app_spacing.dart           # Responsive border radii & layout insets
│       └── app_motion.dart            # Spring bounce animation curves & durations
├── core/
│   ├── services/
│   │   └── notification_service.dart  # System notification dispatch & permission handler
│   ├── utils/
│   │   ├── formatters.dart            # USD ($), PKR (Rs), %, and date formatters
│   │   ├── validators.dart            # Payment & transaction validators
│   │   ├── cnic_formatter.dart        # 13-digit Pakistani CNIC mask (XXXXX-XXXXXXX-X)
│   │   └── phone_formatter.dart       # PK (+92) and US (+1) real-time phone formatters
│   └── widgets/
│       ├── app_button.dart            # Tactile spongy primary, secondary & ghost buttons
│       ├── app_text_field.dart        # Themed text field with label & validation
│       ├── app_shell.dart             # Responsive shell with adaptive top bar & nav
│       ├── paidi_x_bottom_nav_bar.dart# Responsive zero-overflow bottom navigation
│       ├── spongy_tap.dart            # Kinetic spring tap physics wrapper
│       ├── status_badge.dart          # 7-state regulatory payment status pill badges
│       ├── brand_logo.dart            # "PX" PaidiX mark and tagline
│       └── empty_state.dart           # Illustrated empty states with actionable buttons
└── features/
    ├── auth/                          # Sign In / Sign Up domain models, validators & pages
    ├── dashboard/                     # Executive metrics, customer trust score & repository
    ├── kyc/                           # 4-step onboarding, camera/gallery & image processor
    ├── settings/                      # 5-tab settings: Profile, Security, PIN, Bank, Appearance
    └── payments/                      # Repository, filtering engine, pagination & payment forms
```

---

## 🧪 Quality Assurance & Testing

PaidiX enforces strict quality gates with comprehensive test coverage:

```bash
flutter test
flutter analyze
```

### Verification Highlights:
- **Total Tests Passing:** **120 / 120** (100% pass rate across 17 test suites)
- **Static Analysis:** **0 warnings, 0 errors, 0 lints** (`flutter analyze`)
- **Viewport Stress Testing:** Verified at 320px, 360px, 414px, 768px, 1024px, and 1200px widths with **0 `RenderFlex` exceptions**.

| Test Suite | Verifications & Coverage Scope |
| :--- | :--- |
| `pakistani_banks_test.dart` | Complete 39-institution banking catalog, code & alias resolver (`findPakistaniBank`), vector brand logos (`BankLogoWidget`), and interactive modal search (`BankSelectorSheet`) |
| `paidix_toast_and_server_error_test.dart` | Top-positioned themed toasts (Success, Warning, Error, ServerError, Info), auto-dismiss timers, swipe-up dismiss, ServerErrorPage diagnostics, and ServerErrorDialog retry |
| `account_settings_page_test.dart` | 5 settings tabs, profile editing, phone formatting, 3-card KYC gallery, PIN setup/removal, bank catalog, and 320px–1200px responsiveness |
| `payments_page_test.dart` | Payments page rendering, accordion filters, side-by-side chips, status dropdown, 32 mock items, recycler animation, and pagination |
| `payments_repository_test.dart` | 12% fee formula, 273 PKR/USD conversion, multi-term query filters, and status filtering |
| `dashboard_page_test.dart` | Customer score card metrics (`84 A TRUSTED`), financial overview cards, status metrics grid, and synchronized balance masking |
| `kyc_auth_routing_test.dart` | One-time KYC verification routing, local persistence, and automatic dashboard forwarding for returning users |
| `kyc_test.dart` | 4-step KYC wizard, multi-stage image enhancement, CNIC / phone mask formatters, and bank account linking |
| `new_payment_page_test.dart` | 12% fee banner calculations, CashApp/Zelle method selector, form validation, date picker, and proof uploads |
| `theme_test.dart` | Material 3 light/dark tokens, fixed sidebar non-inverting colors, and theme toggle reactivity |
| `bottom_nav_bar_navigation_test.dart`| Smooth navigation transitions, strictly monotonic blur radii, and zero shadow blur assertion crashes |
| `spongy_button_test.dart` | Kinetic spring compression scales (`0.94`–`0.96`), release bounce physics, and touch event handling |
| `app_formatters_test.dart` | Currency formatters (USD `$`, PKR `Rs`), percentages, and formatted date representations |
| `auth_validators_test.dart` | Email regex, password length, and international phone validation |
| `widget_test.dart` | SignIn & SignUp navigation, default `+92` country code, and form validations |

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK:** Version `>=3.10.0` (Recommended: `3.27.0+`)
- **Dart SDK:** Version `>=3.0.0 <4.0.0`
- **Android Studio** / **VS Code** with Flutter extensions installed
- **Android SDK:** API level 34 (`compileSdk = 37`, `minSdk = 24`, `targetSdk = 34`)

### Installation & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/AbdullahAzeem12/PaidiX.git
   cd PaidiX
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify code quality:**
   ```bash
   flutter analyze
   flutter test
   ```

4. **Run on connected emulator or physical device:**
   ```bash
   flutter run
   ```

### Pre-Compiled Release Artifacts
Production-ready Android APKs are pre-built and available directly in the repository:
- **`PaidiX.apk`** (Root universal fat APK — installs on all Android devices)
- **`release/PaidiX-v1.0.0-arm64-v8a.apk`** (18.0 MB lightweight build for modern phones)
- **`release/PaidiX-v1.0.0-Universal.apk`** (51.8 MB fat APK)

---

## 📱 Platform Configuration & Native Host

- **Application ID:** `com.paidix.paidix`
- **Android Rendering Engine:** Configured with `RenderMode.texture` in `MainActivity.kt` to permanently eliminate black/blank screen freezes when resuming from external camera/gallery pickers on EMUI / HarmonyOS devices.
- **Java / Kotlin Host:** Java 17 toolchain, Kotlin JVM target 17, Gradle 9.3.1 with `--enable-native-access=ALL-UNNAMED`.
- **System Permissions:** Configured in `AndroidManifest.xml`:
  - `CAMERA` (Biometric photo & KYC document capture)
  - `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE` (Gallery document attachment)
  - `POST_NOTIFICATIONS` (Real-time KYC enhancement & payment verification alerts)

---

<div align="center">

**PaidiX Mobile Application** • Engineered with precision for global commerce  
*Move Money. Build Trust.*

Crafted by **[Abdullah Azeem](https://github.com/AbdullahAzeem12)**

</div>
