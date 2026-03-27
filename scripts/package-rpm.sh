#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

VERSION="${VORTEX_VERSION:-1.0.0}"
ARCH="x86_64"
INSTALL_DIR="/opt/Vortex"
APP_UNPACKED="$REPO_ROOT/dist/linux-unpacked"
RPM_OUTPUT="$REPO_ROOT/dist"
ICON_SOURCE="$REPO_ROOT/assets/images/vortex.png"

# Build everything
echo "==> Building Vortex..."
pnpm run dist:all

# Prepare dist package and install its dependencies
echo "==> Preparing dist package..."
cd src/main
node ./prepare-dist-package.mjs
pnpm install --dir=./dist

# Package as unpacked dir using linux-specific config
echo "==> Building unpacked Linux app..."
pnpm electron-builder \
  --config ./electron-builder.linux.json \
  --linux dir \
  --publish never

cd "$REPO_ROOT"

if [[ ! -d "$APP_UNPACKED" ]]; then
  echo "ERROR: Unpacked app not found at $APP_UNPACKED"
  exit 1
fi

# Build RPM with rpmbuild directly (bypasses FPM which is incompatible with RPM 6)
echo "==> Building RPM with rpmbuild..."

RPM_TOPDIR="$(mktemp -d)"
trap 'rm -rf "$RPM_TOPDIR"' EXIT

mkdir -p "$RPM_TOPDIR"/{BUILD,RPMS,SPECS,SOURCES}

cat > "$RPM_TOPDIR/SPECS/vortex.spec" << 'SPEC'
%define _build_id_links none
%define debug_package %{nil}
%define __strip /bin/true

Name:           vortex
Version:        %{_vortex_version}
Release:        1%{?dist}
Summary:        Mod Manager
License:        GPL-3.0
URL:            https://www.nexusmods.com/about/vortex/
Vendor:         Black Tree Gaming Ltd.

Requires:       dotnet-runtime-9.0

AutoReqProv:    no

%description
The elegant, powerful, and open-source mod manager from Nexus Mods.

%install
mkdir -p %{buildroot}/opt/Vortex
cp -a %{_vortex_unpacked}/. %{buildroot}/opt/Vortex/

mkdir -p %{buildroot}/usr/share/icons/hicolor/512x512/apps
cp %{_vortex_icon} %{buildroot}/usr/share/icons/hicolor/512x512/apps/vortex.png

mkdir -p %{buildroot}/usr/share/applications
cat > %{buildroot}/usr/share/applications/vortex.desktop << 'DESKTOP'
[Desktop Entry]
Name=Vortex
GenericName=Mod Manager
Comment=Mod manager for PC games from Nexus Mods
Exec=/opt/Vortex/vortex %U
Icon=vortex
Terminal=false
Type=Application
Categories=Game;Utility;
MimeType=x-scheme-handler/nxm;
StartupWMClass=Vortex
Keywords=mod;mods;modding;nexus;games;
DESKTOP

%post
if type update-alternatives 2>/dev/null >&1; then
    if [ -L '/usr/bin/vortex' -a -e '/usr/bin/vortex' -a "$(readlink '/usr/bin/vortex')" != '/etc/alternatives/vortex' ]; then
        rm -f '/usr/bin/vortex'
    fi
    update-alternatives --install '/usr/bin/vortex' 'vortex' '/opt/Vortex/vortex' 100 || ln -sf '/opt/Vortex/vortex' '/usr/bin/vortex'
else
    ln -sf '/opt/Vortex/vortex' '/usr/bin/vortex'
fi
chmod 4755 '/opt/Vortex/chrome-sandbox' || true
if hash update-mime-database 2>/dev/null; then
    update-mime-database /usr/share/mime || true
fi
if hash update-desktop-database 2>/dev/null; then
    update-desktop-database /usr/share/applications || true
fi

%postun
if [ "$1" -eq 0 ]; then
    if type update-alternatives >/dev/null 2>&1; then
        update-alternatives --remove 'vortex' '/usr/bin/vortex'
    else
        rm -f '/usr/bin/vortex'
    fi
fi

%files
%defattr(-,root,root,-)
/opt/Vortex
/usr/share/icons/hicolor/512x512/apps/vortex.png
/usr/share/applications/vortex.desktop
SPEC

rpmbuild -bb \
  --define "_topdir $RPM_TOPDIR" \
  --define "_rpmdir $RPM_OUTPUT" \
  --define "_vortex_version $VERSION" \
  --define "_vortex_unpacked $APP_UNPACKED" \
  --define "_vortex_icon $ICON_SOURCE" \
  "$RPM_TOPDIR/SPECS/vortex.spec"

# Find the built RPM
RPM_FILE=$(find "$RPM_OUTPUT" -name '*.rpm' -print -quit)
if [[ -z "$RPM_FILE" ]]; then
  echo "ERROR: No RPM file found in $RPM_OUTPUT/"
  exit 1
fi

echo ""
echo "==> Built: $RPM_FILE"
echo ""
echo "To install/upgrade:"
echo "  sudo dnf install --assumeyes $RPM_FILE"
