# Building Vortex as a Native RPM

Build and install Vortex directly on Fedora/RHEL without Flatpak.

## Prerequisites

Install build tooling and runtime dependencies:

```bash
sudo dnf install rpm-build dotnet-runtime-9.0
```

Install Node 22, Yarn, and pnpm via asdf:

```bash
asdf plugin add nodejs
asdf plugin add yarn
asdf plugin add pnpm
asdf install nodejs 22.22.0
asdf install yarn 1.22.19
asdf install pnpm 10.33.0
asdf set nodejs 22.22.0
asdf set yarn 1.22.19
asdf set pnpm 10.33.0
```

Then install project dependencies:

```bash
pnpm install
```

## Build the RPM

From the repository root:

```bash
pnpm run package:rpm
```

This runs the full pipeline: typecheck, production build, extension build, asset compilation, and electron-builder RPM packaging. The output RPM lands in `dist/`.

Alternatively, use the helper script:

```bash
./scripts/package-rpm.sh
```

## Install / Upgrade

```bash
sudo dnf install --assumeyes dist/*.rpm
```

`dnf install` handles both fresh installs and upgrades. The RPM installs to `/opt/Vortex/` with a `/usr/bin/vortex` symlink, desktop file, icon, and `nxm://` protocol handler.

## Updating from Git

```bash
git pull
pnpm install          # only needed if dependencies changed
pnpm run package:rpm
sudo dnf install --assumeyes dist/*.rpm
```

## What the RPM Includes

- Application installed to `/opt/Vortex/`
- Desktop entry at `/usr/share/applications/` (appears in app launchers)
- Icon at `/usr/share/icons/hicolor/`
- `nxm://` MIME type handler for Nexus Mods links
- Dependency on `dotnet-runtime-9.0` (required by FOMOD installer)

## Configuration

The Linux-specific electron-builder config lives at `src/main/electron-builder.linux.json`. It extends the base `electron-builder.config.json` and overrides:

- Target: `rpm` instead of `zip`
- Strips Windows-only extra resources (VC++ Redistributable, .NET Desktop Runtime installer, NSIS scripts)
- Adds RPM dependency on `dotnet-runtime-9.0`
- Configures desktop entry fields and `nxm://` protocol handler

## Uninstall

```bash
sudo dnf remove vortex
```
