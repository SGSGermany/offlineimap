#!/bin/bash
# OfflineIMAP
# A container running OfflineIMAP, a open-source IMAP synchronization tool.
#
# Copyright (c) 2023  SGS Serious Gaming & Simulations GmbH
#
# This work is licensed under the terms of the MIT license.
# For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
#
# SPDX-License-Identifier: MIT
# License-Filename: LICENSE

set -eu -o pipefail
export LC_ALL=C.UTF-8

[ -v CI_TOOLS ] && [ "$CI_TOOLS" == "SGSGermany" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS' not set or invalid" >&2; exit 1; }

[ -v CI_TOOLS_PATH ] && [ -d "$CI_TOOLS_PATH" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS_PATH' not set or invalid" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"
source "$CI_TOOLS_PATH/helper/git.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

# request latest version from OfflineIMAP Git repo
# if the latest version isn't our current version we bail and require a manual update
echo + "CURRENT_VERSION=\"\$VERSION\"" >&2
CURRENT_VERSION="$VERSION"

VERSION="$(git_latest "$GIT_REPO" "v*.*")"

if [ -z "$VERSION" ]; then
    echo "Unable to determine latest OfflineIMAP version" >&2
    exit 1
fi

VERSION="${VERSION#v}"

echo + "[ $(quote "$CURRENT_VERSION") == $(quote "$VERSION") ]" >&2
if [ "$CURRENT_VERSION" == "$VERSION" ]; then
    echo "OfflineIMAP $CURRENT_VERSION is the latest version and thus still supported"
else
    echo "OfflineIMAP $CURRENT_VERSION has reached its end of life"
    echo "The latest version $VERSION supersedes version $CURRENT_VERSION"
    exit 1
fi
