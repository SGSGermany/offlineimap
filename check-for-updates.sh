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
source "$CI_TOOLS_PATH/helper/chkupd.sh.inc"
source "$CI_TOOLS_PATH/helper/chkupd-pypi.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

TAG="${TAGS%% *}"
REQUIREMENTS_FILES=( "/usr/share/offlineimap/requirements.txt" )

# check whether the base image was updated
chkupd_baseimage "$REGISTRY/$OWNER/$IMAGE" "$TAG" || exit 0

# check whether Python package upgrades are available considering OfflineIMAP's requirements.txt
chkupd_pypi_requirements "$REGISTRY/$OWNER/$IMAGE:$TAG" "${REQUIREMENTS_FILES[@]}" || exit 0
