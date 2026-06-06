# Couple App ❤️

**Couple** is a private, secure, anonymous, and modern messaging platform designed exclusively for couples. Instead of copying bloated multi-user chat platforms, **Couple** is built on an exclusive one-to-one relationship model: **exactly one conversation between two verified partners in a secure digital room**.

## 🌟 Core Pillars & Philosophy

1. **Absolute Privacy & Anonymity**: No emails, phone numbers, or real identities are collected. Authentication relies purely on Username + Password + a 16-word Recovery Phrase.
2. **Exclusive Relationship Lock**: Hard database constraints limit users to exactly one active relationship and conversation. Users cannot search, discover, or invite multiple people.
3. **Auto-Expiration (Zero-Data Footprint)**: To respect data ownership, accounts inactive for 90 consecutive days enter a deletion window and are permanently erased.
4. **Premium UX Focus**: Fluid, responsive interface adhering strictly to custom Material Design 3 (Material You) styling guidelines and motion behaviors.

## ✨ Features

- **Anonymous Authentication**: Sign up and log in using just a username and password. A secure 16-word recovery phrase is provided for account recovery.
- **Unique Partner Connection**: Generate a unique Couple Code and securely connect with your partner to establish your private room.
- **End-to-End Encrypted Messaging**: Real-time End-to-End Encrypted (E2EE) text and image messaging to ensure only you and your partner can read the messages.
- **Rich Chat Interactions**: 
  - Real-time typing indicators
  - Online/offline status
  - Read receipts (ticks)
  - Message reactions & replies
  - Message editing & soft/hard deletion
- **Couple Dissolution**: A dual-consent separation flow featuring a 24-hour cooling-off state if you ever need to disconnect.

## 🔒 Security & Privacy Architecture

- **End-to-End Encryption**: Built with Signal Protocol / double-ratchet implementation standards.
- **Zero Identity Tracking**: No personal information (PII) like emails or phone numbers are ever asked for or stored. No IP addresses are logged.
- **Account Recovery Security**: The 16-word recovery phrase is hashed securely using Argon2id. Plaintext seed values never cross the network boundary.
- **Secure Storage**: Uses encrypted Shared Preferences (Android), DPAPI (Windows), and memory-locked IndexedDB (Web) to store sensitive keys locally on the device.
- **Inactivity Deletion**: Automatic data sanitization. If an account is inactive for 90 days, it is completely purged from the servers to ensure your data isn't sitting around forever.

## 🎨 Design System (Material Design 3)

The app features a stunning dynamic palette (Material You) with custom themes:
- **Light Theme**: Warm Rose Red (`#c0005a`) & Warm backgrounds
- **Dark Theme**: Soft Rose Gold (`#ffb1c8`) & Deep warm dark burgundy backgrounds
- **Fluid Animations**: Custom ink ripple effects, spring-based interpolations, asymmetric chat bubbles, and shared axis transitions create a modern, premium feel.

## 🛠️ Prerequisites for Development

Before setting up the project, ensure you have the following installed on your system:

- **[Flutter SDK](https://docs.flutter.dev/install/manual)**
- **[Android Studio](https://developer.android.com/studio)** (Includes Android SDK Tools)
- **[Visual Studio Community](https://visualstudio.microsoft.com/vs/community/)** (Required for Windows SDK Tools & C++ development)
- **[Java 17](https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html)**
- **[Git](https://git-scm.com/downloads)**
- **[Visual Studio Code](https://code.visualstudio.com/)** (Recommended IDE)

## 🚀 Getting Started for Contributors

This project is a Flutter application. To run or contribute to this project:

1. Ensure you have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
2. Clone the repository: `git clone https://github.com/luckychawla872/CoupleApp.git`
3. Run `flutter pub get` to install dependencies.
4. Set up your Supabase project and provide the necessary environment variables in an `.env` file (ensure this is never committed to Git).
5. Run the app: `flutter run`

We welcome contributions to make this secure space for couples even better!
