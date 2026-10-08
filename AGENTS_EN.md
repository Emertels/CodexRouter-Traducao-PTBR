# Maintenance guidelines — Codex Router PT-BR

## Scope

This repository maintains translations and scripts to build and install a Brazilian Portuguese package for Codex Router Control Center on Windows. The application and its package belong to their respective owners; do not claim official affiliation.

## Source and build

- Keep catalog translations in `translations/pt-BR.json` and literal translations outside the catalog in `translations/inline-pt-BR.json`; catalog keys are stable bundle identifiers.
- Build `app-pt.asar` with `node tools/build-translated-asar.cjs app.asar app-pt.asar` or `npm run build`.
- The input ASAR must come from the installed version being translated. Never modify the original package.
- The builder verifies SHA-256 hashes, bounds, and offsets, updates the modified file's integrity metadata, and validates the output.
- Do not edit `app.asar` or `app-pt.asar` manually; change the catalog and rebuild the artifact.

## Safety and installation

- Never overwrite an existing `_backup/app.asar`. Validate it before relying on it.
- Per user instruction, force-close only processes whose executable path exactly matches the selected installation before replacing or restoring files.
- Stage files on the same volume and validate hashes and structure before replacement.
- Preserve a backup of the executable before modifying any Electron Fuse. Restore the original executable when a backup is available.
- Do not install the translation during development. Use a test installation and visually verify the running interface before publishing.

## Terminology

- Prefer **aplicativo**, **tokens**, **ativar/desativar**, and **Painel de Controle** in Portuguese UI copy.
- Preserve brands, model and provider names, commands, variables, paths, identifiers, and technical units.
- Use natural Brazilian Portuguese and keep placeholders such as `{name}`, `{hours}`, and `{tokens}` unchanged.

## Releases

- Update `CHANGELOG.md`, `README.md`, and `README_EN.md` for every release.
- Do not commit local ASAR files, backups, executables, or user data.
- Do not claim the entire UI is translated without auditing the bundle and reviewing the running interface.
