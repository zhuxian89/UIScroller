#!/bin/bash
set -euo pipefail

for packaging_scheme in "" rootless roothide; do
    printf '\nBuilding %s package...\n' "${packaging_scheme:-rootful}"
    make clean THEOS_PACKAGE_SCHEME="$packaging_scheme"
    make package "$@" THEOS_PACKAGE_SCHEME="$packaging_scheme"
done

printf '\nAll three packages built successfully. See packages/.\n'
