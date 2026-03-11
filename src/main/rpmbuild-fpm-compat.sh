#!/bin/bash
# rpmbuild compatibility shim for fpm 1.9.3 + rpmbuild 6.x
#
# RPM 6 changed %buildroot semantics: it now expands to
# BUILD/{name}-{version}-build/BUILDROOT/ instead of the raw --define value.
# fpm 1.9.3 stages files in BUILD/ and uses a no-op %install, which breaks
# on RPM 6 because files are never moved to the new BUILDROOT path.
#
# This wrapper patches the fpm-generated spec's %install section to copy the
# pre-staged files from _topdir/BUILD/ into %{buildroot}/ before rpmbuild runs.

REAL_RPMBUILD=/usr/bin/rpmbuild

# Extract spec file path from args
SPEC_FILE=""
for arg in "$@"; do
  if [[ "$arg" == *.spec ]]; then
    SPEC_FILE="$arg"
    break
  fi
done

if [[ -n "$SPEC_FILE" && -f "$SPEC_FILE" ]]; then
  NAME=$(grep -i '^Name:' "$SPEC_FILE" | head -1 | awk '{print $2}')
  VERSION=$(grep -i '^Version:' "$SPEC_FILE" | head -1 | awk '{print $2}')

  if [[ -n "$NAME" && -n "$VERSION" ]]; then
    EXCLUDE_DIR="${NAME}-${VERSION}-build"
    # Inject copy commands into the %install section.
    # Copies everything from _topdir/BUILD/ into %{buildroot}/, then removes
    # the RPM 6 build subdir to avoid a recursive staging artifact.
    INSTALL_CMD="cp -a %{_topdir}/BUILD/. %{buildroot}/ \&\& rm -rf \"%{buildroot}/${EXCLUDE_DIR}\""
    sed -i "s|^# noop$|${INSTALL_CMD}|" "$SPEC_FILE"
  fi
fi

exec "$REAL_RPMBUILD" "$@"
