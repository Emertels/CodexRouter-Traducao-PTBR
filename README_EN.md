# Codex Router Control Center — Brazilian Portuguese

![Version](https://img.shields.io/badge/version-1.3.0-blue?style=for-the-badge)
![Language](https://img.shields.io/badge/language-Portuguese%20(Brazil)-green?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-purple?style=for-the-badge)

[Português](README.md)

Scripts and a translation catalog for building and installing a Brazilian Portuguese version of Codex Router Control Center on Windows. The original application is not included in this repository; build the translated package from the `app.asar` in your own installation.

## Translated strings

The audit of the latest installed build applies **848 Brazilian Portuguese entries**: 139 catalog entries and 692 direct UI strings covering screens, states, settings, providers, models, usage, errors, dates, times, and descriptions. Number and date formats follow the selected interface language. The language selector includes Brazilian Portuguese, and a Portuguese system locale selects it on first launch. Product names and technical terms remain unchanged when used as interface terminology.

Translations are maintained in `translations/pt-BR.json` and the `translations/inline-pt-BR*.json` files. The builder recognizes the bundle structures used by previous and current versions, keeps the English catalog separate, recalculates ASAR SHA-256 integrity metadata, and validates the output. The manifest records the original and translated hashes.

## Build the package

Requirements: Windows, PowerShell, and Node.js 18 or later. The builder has no npm dependencies.

1. Copy `resources/app.asar` from the version you want to translate into this folder as `app.asar`.
2. Run this from the project directory:

   ```powershell
   npm run build
   ```

   Or, without npm:

   ```powershell
   node tools/build-translated-asar.cjs app.asar app-pt.asar
   ```

3. The command creates `app-pt.asar` and `app-pt.asar.manifest.json` locally. It stops if the input header, file offsets, or integrity hashes are invalid.

## Install

1. Run `Instalar-Traducao.bat`.
2. The installer compares the installed version with the manifest and rebuilds a compatible package automatically when the bundle still matches the available translations.
3. Before replacing files, it force-closes processes belonging to the selected installation and validates version-specific backups. An unsupported version is stopped before the installed ASAR is replaced.

When finished, `S` opens the app and closes the CMD window; `N`, `Esc`, or `Enter` close without opening it. Restore offers the same choices, including when the app is already in English and no files need restoration.

This distribution may require a reversible Electron Fuse change to accept a customized `app.asar`. The installer saves ASAR and executable backups by hash under `_backup/versions` and records their paths so restore can recover the matching version. Existing backups are never overwritten.

## Restore

Run `Restaurar-Original.bat`. The script closes processes belonging to the selected installation, validates the translated version's backup, and restores its files. If the ASAR no longer contains the recognized PT-BR translations, it says restoration is unnecessary, makes no changes, and offers the same choices to open or close the app.

## Main files

| File | Purpose |
| --- | --- |
| `translations/pt-BR.json` and `translations/inline-pt-BR*.json` | UI translations |
| `tools/build-translated-asar.cjs` | Applies translations and rebuilds the ASAR with updated integrity metadata |
| `aplicar-traducao.ps1` | Installs the package with backup and validation |
| `restaurar-original.ps1` | Restores the original backup |
| `CHANGELOG.md` | Release history |

`app.asar`, `app-pt.asar`, the generated manifest, backups, and temporary files are ignored by Git. They contain the packaged application and are generated locally for the installed version.

## License

The scripts in this project are distributed under the MIT License. Codex Router Control Center and its components remain the property of their respective owners. This project is not affiliated with or endorsed by them.

## ✍️ Credits and Authorship

* **PT-BR Translation:** Emerson Teles
* **Architecture and Engineering:** Emerson Teles
* **Localization:** Brazilian Portuguese (`pt-BR`)
* **Distribution:** Portable, autonomous, high-performance package.

*Codex Router Control Center is a registered trademark of its respective owners. This translation package is an independent customization developed by Emerson Teles.*

---

## 👤 About the Author

Developed and maintained by **Emerson Teles** (known in the community as **Emertels**).

Tech enthusiast, gamer, system maintenance professional, and translator/localizer of software and emulators to Brazilian Portuguese (PT-BR).

### 🛠️ Notable Projects & Contributions:
- **Automation Suites & Utilities on GitHub:**
  - **[Suite-Emuladores](https://github.com/Emertels/Suite-Emuladores)** — Intelligent PowerShell suite for automated downloading and updating of 56 emulators and frontends.
  - **[PSBBN-Translator](https://github.com/Emertels/PSBBN-Translator)** — Corporate-grade localization suite for the PSBBN Definitive Project on PS2 (40 languages).
  - **[AI-Chat-Vault](https://github.com/Emertels/AI-Chat-Vault)** — Portable backup and recovery of local conversations from 20 agentic AI and coding tools.
  - **[Microsoft-Photos-Fix](https://github.com/Emertels/Microsoft-Photos-Fix)** — Advanced PowerShell and C# fix for launch routing and wallpaper features in Microsoft Photos.
  - **[Roccat-Syn-Pro-Air-Fix](https://github.com/Emertels/Roccat-Syn-Pro-Air-Fix)** — Definite stabilization and audio management suite for ROCCAT Syn Pro Air wireless headset.
- **Emulation & Consoles:** Creator of **[PSBBN-Translator](https://github.com/Emertels/PSBBN-Translator)**; localization and support for **PSBBN**, **PCSX2**, **Dolphin**, **shadPS4**, **Azahar**, and **RetroArch**.
- **Software & Utilities:** 100% translation of **DSX** (DualSense X - Trusted Translator), **ASUS GPU Tweak III**, **dnGrep**, **XWidget**, and web tools.
- **Games:** Translation of **Silent Hill 5: Homecoming**, ongoing work on **Silent Hill 4: The Room**, and various other applications.

---

### 🌐 Connect & Official Communities:

<div align="left">

[![GitHub](https://img.shields.io/badge/GitHub-Emertels-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/emertels)
[![Website](https://img.shields.io/badge/Website-Emerson_Teles-0070F3?style=for-the-badge&logo=googlechrome&logoColor=white)](https://emertels.github.io)
[![Discord](https://img.shields.io/badge/Discord-Emertels%20Server-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://emertels.github.io/discord)
[![X / Twitter](https://img.shields.io/badge/X_Twitter-@emertels-000000?style=for-the-badge&logo=x&logoColor=white)](https://x.com/emertels)
[![YouTube](https://img.shields.io/badge/YouTube-Emerson_Teles-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://www.youtube.com/@emersonteles2379)
[![Telegram](https://img.shields.io/badge/Telegram-Aplicativos%20Mods-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/apksmodsandroid)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Apoiar%20Projeto-FF5E5B?style=for-the-badge&logo=kofi&logoColor=white)](https://ko-fi.com/emertels)

</div>
