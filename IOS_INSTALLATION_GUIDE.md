# 📱 PaidiX — iOS Installation Guide

This guide explains how Apple iPhone and iPad users can install and use **PaidiX** (`.ipa`).

---

## 🚀 Step 1: Download `PaidiX.ipa`

1. Go to the [PaidiX GitHub Releases](https://github.com/AbdullahAzeem12/PaidiX/releases) page.
2. Under the latest release, download **`PaidiX.ipa`**.
   *(Alternatively, download it from the GitHub Actions **Artifacts** tab).*

---

## 🛠️ Step 2: Install on Your iPhone

Because Apple does not allow direct APK-style browser installs without signing, choose any of the 3 free methods below:

### Method A: Sideloadly (Easiest — Works on Windows & Mac)
1. Download and install **Sideloadly** from [sideloadly.io](https://sideloadly.io/).
2. Connect your iPhone to your PC via a USB cable.
3. Open Sideloadly and drag & drop the **`PaidiX.ipa`** file into Sideloadly.
4. Enter your regular Apple ID email (used to sign the app for personal use).
5. Click **Start**. In 30–60 seconds, PaidiX will appear on your iPhone home screen!

### Method B: AltStore (Wireless Installation)
1. Install **AltServer** from [altstore.io](https://altstore.io/) on your computer.
2. Install **AltStore** onto your iPhone.
3. AirDrop or download `PaidiX.ipa` onto your iPhone.
4. Open the Files app on iPhone, share `PaidiX.ipa` to **AltStore**, and tap Install.

### Method C: TrollStore / Scarlet (Direct On-Device)
If your device has TrollStore or Scarlet installed, open `PaidiX.ipa` directly to install instantly with zero computer required.

---

## 🔓 Step 3: Trust Developer Certificate on iPhone

When opening the app for the first time, iOS will prompt you to trust the profile:
1. Open your iPhone **Settings**.
2. Navigate to **General > VPN & Device Management**.
3. Under **Developer App**, tap on your Apple ID email.
4. Tap **Trust "[Your Apple ID]"** and confirm.
5. Launch **PaidiX**!

---

## ⚙️ Automated iOS Cloud Builds
PaidiX includes automated cloud Mac builds via GitHub Actions:
- Located at `.github/workflows/build_ios.yml`.
- Runs automatically on every push or manual trigger under **Actions > Build iOS App (IPA) > Run workflow**.
