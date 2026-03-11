#!/bin/bash

# Delete the link to the binary.
# update-alternatives --remove <name> <path-to-binary> (NOT the symlink path)
if type update-alternatives >/dev/null 2>&1; then
    update-alternatives --remove '${executable}' '/opt/${sanitizedProductName}/${executable}'
else
    rm -f '/usr/bin/${executable}'
fi
