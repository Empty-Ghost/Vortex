# RPM Build Target Design

**Date:** 2026-03-10
**Branch:** `rpm-build`
**Scope:** Local RPM packaging only (no CI/CD changes)

## Summary

Add an RPM packaging target to Vortex, targeting Fedora. Replaces the existing Linux `zip` output with an RPM artifact, adds Fedora-appropriate system dependency declarations, and introduces a dedicated `package:linux` script as a first-class peer to the existing Windows packaging commands.

## Changes

### 1. `src/main/electron-builder.config.json`

Replace the Linux `target` and add an `rpm` metadata block:

```json
"linux": {
  "target": "rpm",
  "category": "Network;Development;Game",
  "icon": "../../assets/images/vortex.png",
  "mimeTypes": ["x-scheme-handler/nxm"]
},
"rpm": {
  "release": "1",
  "depends": [
    "libXScrnSaver",
    "libXtst",
    "nss",
    "alsa-lib",
    "gtk3",
    "libnotify"
  ]
}
```

**Rationale for deps:** These are the Fedora RPM package names required by modern Electron at runtime. `GConf2` is omitted — deprecated in Fedora and not required by current Electron versions.

### 2. `src/main/package.json`

Add a `package:linux` script that mirrors `package:nosign` without the Windows-only `prepare:win` step:

```json
"package:linux": "node ./prepare-dist-package.mjs && pnpm install --dir=./dist && pnpm electron-builder --config ./electron-builder.config.json --publish never"
```

### 3. Root `package.json`

Add a convenience wrapper:

```json
"package:linux": "pnpm run dist:all && pnpm -F @vortex/main run package:linux"
```

## Usage

```sh
# From repo root, produces RPM in dist/
pnpm run package:linux
```

Requires `rpmbuild` to be installed on the build machine (`dnf install rpm-build` on Fedora).

## Out of Scope

- CI/CD pipeline integration (GitLab or GitHub Actions)
- GPG signing of RPM packages
- deb or AppImage targets
