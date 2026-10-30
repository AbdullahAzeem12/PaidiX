# PaidiX — Global Invoice, Payout & Settlement Mobile App

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A53.10.0-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%E2%89%A53.0.0-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Material Design](https://img.shields.io/badge/Material%203-Abyssal%20Teal-0A3134?logo=materialdesign&logoColor=white)](https://m3.material.io)
[![Tests](https://img.shields.io/badge/Tests-72%2F72%20Passing-brightgreen?logo=checkmarx&logoColor=white)]()
[![Code Quality](https://img.shields.io/badge/flutter%20analyze-0%20issues-brightgreen?logo=dart&logoColor=white)]()
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-4CAF50?logo=android&logoColor=white)]()
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)]()

### **Move Money. Build Trust.**
*High-velocity global invoice, cross-border payout, and regulatory verification platform for international businesses and freelancers.*

</div>

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Key Features](#-key-features)
  - [1. Executive Financial Dashboard](#1-executive-financial-dashboard)
  - [2. Payments & Settlement Engine](#2-payments--settlement-engine)
  - [3. Bulk Add Payments Engine](#3-bulk-add-payments-engine)
  - [4. Regulatory KYC & Bank Onboarding](#4-regulatory-kyc--bank-onboarding)
  - [5. Profile & Document Management](#5-profile--document-management)
  - [6. Responsive Bottom Navigation Bar](#6-responsive-bottom-navigation-bar)
- [Design System & Motion Physics](#-design-system--motion-physics)
- [Architecture & Directory Structure](#-architecture--directory-structure)
- [Domain Formulas & Invariants](#-domain-formulas--invariants)
- [Quality Assurance & Testing](#-quality-assurance--testing)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation & Run](#installation--run)
  - [Building Release APK](#building-release-apk)
- [Platform Configuration](#-platform-configuration)

---

## 🌟 Overview

**PaidiX** is a modern cross-border financial platform engineered with Flutter. It streamlines USD-to-PKR incoming settlements, multi-method payment verification (CashApp, Zelle), SBP 1-LINK bank routing, and regulatory Know-Your-Customer (KYC) onboarding into an ultra-responsive, dark-mode native experience with zero pixel overflow on screens ranging from narrow 320px devices to wide desktop displays.

---

## 🚀 Key Features

### 1. Executive Financial Dashboard
- **Customer Score Hero Card:** Mint surface (`#80EEDC`) featuring trust rating grade (`79 B TRUSTED`), dynamic completion rate, volume benchmarks, and new account state transitions.
- **Financial Metric Cards:** Clean, reactive balance displays for **PKR Received**, **Total Transferred to You**, and **Awaiting Verification** with em dash (`—`) empty states.
- **Status Summary Grid:** High-level count cards tracking `Transactions`, `Pending Review`, `Awaiting PKR`, and `Completed`.
- **Live Activity Feed:** Instant listing of submitted payments with reactive empty states and one-tap "+ New payment" quick actions.

### 2. Payments & Settlement Engine
- **Expandable Accordion Filter Bar (`PaymentsFilterBar`):**
  - Collapsed by default; expands with smooth hardware-accelerated transitions.
  - **Side-by-Side Chips Slider:** Horizontal scrollable chip bar for **Range**, **Currency**, and **Status**.
  - **8 Distinct Statuses:** `Submitted`, `Under Review`, `Verified`, `PKR Sent`, `Completed`, `On Hold`, `Rejected`, and `All statuses` with animated checkmarks.
  - **Settlement Week:** Built-in **"Bitnex week"** quick-filter button for Monday–Sunday settlement cycles.
  - One-click active filter count badge and **Reset** chip.
- **Live Search:** Instant multi-field substring queries against reference code, sender name, company, and transaction amount.
- **Pagination Controls:** Configurable page sizes (`10`, `20`, `30`, `50`, `100`), displaying formatted index ranges `X–Y of Z`.

### 3. Bulk Add Payments Engine (`BulkAddPaymentsDialog`)
- **Dual Adaptive Layouts:**
  - **Desktop / Tablet ($\ge 720\text{px}$):** 8-column spreadsheet grid table (`#`, `METHOD *`, `SENDER NAME *`, `SENDER COMPANY *`, `CONFIRMATION CODE *`, `DATE *`, `AMOUNT (USD) *`, `SCREENSHOT *`, duplicate & delete tools).
  - **Mobile Phone ($< 720\text{px}$):** Compact, touch-friendly card list ensuring zero horizontal overflow or truncation on narrow screens.
- **Real-Time Computation:** Live dynamic updates for row count (`Rows: X`) and gross volume (`Total amount: $ Y.YY`).
- **Row Management Toolbar:** Quick row generation with `+ Add row`, `+5 rows`, and `+10 rows`.
- **Smart Duplication:** One-tap cloning of payment method, sender, company, date, and amount while prompting for distinct transaction codes and screenshot proofs.
- **Proof Attachment:** Gallery image picker with reactive attachment badge (`Add` $\rightarrow$ `Attached` with emerald checkmark).
- **Batch Submission Pipeline:** Atomic validation ensuring each valid entry is dispatched to `PaymentsRepositoryImpl` and fires real-time push notifications.

### 4. Regulatory KYC & Bank Onboarding
- **4-Step Regulatory Onboarding Flow:**
  - **Step 1 — Personal Info:** Full name, address, city, and responsive phone number selector supporting Pakistan (`+92`) and United States (`+1`) with automatic spacing formatters.
  - **Step 2 — Identity Documents:** CNIC / National ID verification with dual front and back capture.
  - **Step 3 — Photo Verification:** Live selfie capture for liveness and biometric cross-matching.
  - **Step 4 — Pakistani Bank Routing:** Pakistani bank selection (JazzCash, Easypaisa, Meezan, HBL, etc.), beneficiary account title validation, and 24-character IBAN / account number clearance against State Bank of Pakistan 1-LINK & PRISM directory.
- **Intelligent Image Processing Pipeline:** Multi-stage simulated enhancement with edge detection, contrast normalization, and progressive compression analysis.

### 5. Profile & Document Management
- **Onboarding Profile Screen:** Complete overview of verified contact and KYC documentation.
- **Real-Time Edit Profile Modal:** Instant updates to full name, phone number, city, and address with real-time state synchronization.
- **KYC Document Re-upload:** Users can re-upload their profile picture, CNIC front, and CNIC back directly from their device gallery with live preview updates.
- **Interactive Document Viewer:** Fullscreen pinch-to-zoom document inspector with metadata pill badges.

### 6. Responsive Bottom Navigation Bar (`PaidiXBottomNavBar`)
- **Fluid Screen Adaptation:** Seamlessly adapts across narrow phone widths (320px–480px+) with zero text truncation or clipping using `FittedBox(fit: BoxFit.scaleDown)`.
- **Tactile Touch Feedback:** Raw pointer touch down squish (`Curves.easeInOutCubic`) and bouncy spring-back release (`Curves.easeOutBack`).
- **Visual Illuminations:** Active navigation tab pill illumination, color cross-fades, and glowing micro-indicator accent lines.

---

## 🎨 Design System & Motion Physics

The PaidiX visual language embodies an **Abyssal Dark Teal** financial aesthetic:

| Design Token | Hex Code | Visual Role |
| :--- | :--- | :--- |
| **App Background** | `#031415` | Abyssal teal deep canvas |
| **Navigation Surface** | `#022F32` | Dark teal navigation bar and sidebar |
| **Card / Panel Surface**| `#0A3134` | Elevated content panels and modal bodies |
| **Card Highlight** | `#0E3D41` | Elevated chip backgrounds and interactive items |
| **Panel Border** | `#13474B` | Subtle panel structural outlines |
| **Primary Accent (Aqua)**| `#5FCFC9` | Primary action buttons, active borders, icons |
| **Light Aqua** | `#95DFDB` | Highlights, focused indicators, and links |
| **Mint Hero Surface** | `#80EEDC` | Customer score hero card container |
| **Brand Gold** | `#EFC479` | "Build Trust." logo accent, pending status badge |
| **Status Emerald** | `#10B981` | Completed / verified state indicators |
| **Status Amber** | `#F59E0B` | Under review / pending state indicators |
| **Status Rose** | `#E11D48` | Rejected / error state indicators |

### Micro-Interactions & Spring Physics
- **SpongyTap (`spongy_tap.dart`):** High-frequency 0ms raw pointer touch response with `0.94`–`0.96` scale compression and bouncy `Curves.easeOutBack` spring-back.
- **Adaptive Layout:** Dynamic switches between compact mobile card layouts and multi-column desktop tables.
- **Zero Pixel Overflow Guarantee:** Rigorously guarded against `RenderFlex` overflows on viewports down to 320px width.

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
│       ├── app_typography.dart        # Inter sans-serif typographic scale
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
│       ├── paidix_bottom_nav_bar.dart # Responsive zero-overflow bottom navigation
│       ├── spongy_tap.dart            # Kinetic spring tap physics wrapper
│       ├── status_badge.dart          # 8-state regulatory payment status pill badges
│       ├── brand_logo.dart            # "PX" PaidiX mark and tagline
│       └── empty_state.dart           # Illustrated empty states with actionable buttons
└── features/
    ├── auth/                          # Sign In / Sign Up domain models, validators & pages
    ├── dashboard/                     # Executive metrics, customer trust score & repository
    ├── kyc/                           # 4-step onboarding, camera/gallery & image processor
    ├── profile/                       # User profile state, document viewer & edit dialog
    └── payments/                      # Repository, filtering engine, bulk add & payment forms
```

---

## 📐 Domain Formulas & Invariants

### Authoritative Payment Settlement (`PaymentsRepositoryImpl`)
All incoming payment submissions calculate fees and net proceeds according to the verified platform formula:

$$\text{feeAmount} = \frac{\text{amount} \times 12.0}{100.0}$$

$$\text{netUSD} = \text{amount} - \text{feeAmount}$$

$$\text{netPKR} = \text{netUSD} \times 273.0$$

- **Processing Fee:** Authoritative **12.0%** dynamic platform fee.
- **Exchange Rate:** Authoritative **1 USD = 273.0 PKR** SBP baseline rate.
- **Reference Sequencing:** Standard prefix `PBX-2026-00` with incrementing counter starting at `1334`.

---

## 🧪 Quality Assurance & Testing

PaidiX includes an extensive automated test suite covering unit models, business logic, formatting, and responsive widget layout rendering:

```bash
cd PaidiX
flutter test
```

### Test Results Summary:
- **Total Test Suites:** 9 test files
- **Total Tests Passing:** **72 / 72** (100% pass rate)
- **Static Analysis:** **0 warnings, 0 errors, 0 lints** (`flutter analyze`)
- **Viewport Stress Testing:** Verified at 320px, 360px, 414px, 768px, 1024px, and 1200px widths with 0 `RenderFlex` exceptions.

| Test File | Test Scope & Verifications |
| :--- | :--- |
| `payments_page_test.dart` | Payments page rendering, accordion filters, side-by-side chips, status dropdown, Bitnex week filter, BulkAddPaymentsDialog with real-time totals, row tools, batch submission, and multi-width responsiveness |
| `payments_repository_test.dart`| Clean empty initialization, 12% fee formula, 273 PKR/USD conversion, multi-term query filters, and status filtering |
| `onboarding_profile_test.dart` | Profile state sync, real-time edit dialog, document viewer, KYC gallery re-upload, and 320px screen zero-overflow |
| `kyc_test.dart` | 4-step KYC wizard, multi-stage image enhancement, CNIC / phone mask formatters, and bank account linking |
| `dashboard_page_test.dart` | Score card metrics (`79 B TRUSTED`), financial overview cards, status metrics grid, and reactive activity stream |
| `new_payment_page_test.dart` | 12% fee banner calculations, CashApp/Zelle method selector, form validation, date picker, and proof uploads |
| `theme_test.dart` | Material 3 light/dark reactivity, bottom navigation bar responsive full labels, and button color states |
| `spongy_button_test.dart` | Kinetic spring compression scales (`0.94`–`0.96`), release bounce physics, and touch event handling |
| `app_formatters_test.dart` | Currency formatters (USD `$`, PKR `Rs`), percentages, and formatted date representations |

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK:** Version `>=3.10.0` (Recommended: `3.27.0+`)
- **Dart SDK:** Version `>=3.0.0`
- **Android Studio** / **VS Code** with Flutter extensions installed
- **Android SDK:** API level 34 (`compileSdk = 34`, `minSdk = 24`)

### Installation & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/abdulahshahid/paidix-mobile-app.git
   cd paidix-mobile-app
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

### Building Release APK
To generate a production-ready, release-optimized Android APK:
```bash
flutter build apk --release
```
The compiled output is located at: `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📱 Platform Configuration

- **Application ID:** `com.paidix.paidix`
- **Android Rendering Mode:** High-performance texture rendering (`RenderMode.texture`) configured in `MainActivity.kt`.
- **System Permissions:** Configured in `AndroidManifest.xml`:
  - `CAMERA` (KYC document photo capture)
  - `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE` (Gallery document attachment)
  - `POST_NOTIFICATIONS` (Real-time KYC enhancement & payment verification alerts)
- **Local Notifications:** Native Android channels configured for regulatory verification alerts (`NotificationService`).

---

<div align="center">

**PaidiX Mobile Application** • Engineered with ❤️ for global commerce  
*Move Money. Build Trust.*

</div>
