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
source "$CI_TOOLS_PATH/helper/container.sh.inc"
source "$CI_TOOLS_PATH/helper/container-alpine.sh.inc"
source "$CI_TOOLS_PATH/helper/git.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

echo + "CONTAINER=\"\$(buildah from $(quote "$BASE_IMAGE"))\"" >&2
CONTAINER="$(buildah from "$BASE_IMAGE")"

echo + "MOUNT=\"\$(buildah mount $(quote "$CONTAINER"))\"" >&2
MOUNT="$(buildah mount "$CONTAINER")"

echo + "rsync -v -rl --exclude .gitignore ./src/ …/" >&2
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

pkg_install "$CONTAINER" --virtual .run-deps \
    python3

pkg_install "$CONTAINER" --virtual .fetch-deps@community \
    py3-pip

pkg_install "$CONTAINER" --virtual .build-deps \
    python3-dev \
    musl-dev \
    gcc \
    krb5-dev \
    make

git_clone "$GIT_REPO" "$GIT_REF" \
    "$MOUNT/usr/src/offlineimap" "…/usr/src/offlineimap"

echo + "HASH=\"\$(git -C …/usr/src/offlineimap rev-parse HEAD)\"" >&2
HASH="$(git -C "$MOUNT/usr/src/offlineimap" rev-parse HEAD)"

echo + "[ \"\$GIT_COMMIT\" == \"\$HASH\" ]" >&2
if [ "$GIT_COMMIT" != "$HASH" ]; then
    echo "Failed to verify source code integrity of OfflineIMAP $VERSION:" \
        "Expecting Git commit '$GIT_COMMIT', got '$HASH'" >&2
    exit 1
fi

git_ungit "$MOUNT/usr/src/offlineimap" "…/usr/src/offlineimap"

cmd buildah config \
    --env PYTHONUSERBASE="/usr/local" \
    "$CONTAINER"

cmd buildah run  "$CONTAINER" -- \
    pip config set global.root-user-action ignore

cmd buildah run  "$CONTAINER" -- \
    pip config set global.break-system-packages true

cmd buildah run  "$CONTAINER" -- \
    pip install --user -r "/usr/src/offlineimap/requirements.txt"

cmd buildah run  "$CONTAINER" -- \
    pip install --user "/usr/src/offlineimap/"

echo + "cp …/usr/src/offlineimap/requirements.txt …/usr/share/offlineimap/requirements.txt" >&2
cp "$MOUNT/usr/src/offlineimap/requirements.txt" "$MOUNT/usr/share/offlineimap/requirements.txt"

echo + "rm -rf …/usr/src/offlineimap" >&2
rm -rf "$MOUNT/usr/src/offlineimap"

user_add "$CONTAINER" offlineimap 65536 "/var/lib/offlineimap"

cmd buildah run "$CONTAINER" -- \
    chown offlineimap:offlineimap \
        "/var/lib/offlineimap" \
        "/var/cache/offlineimap" \
        "/var/vmail"

cmd buildah run "$CONTAINER" -- \
    /bin/sh -c "printf '%s=%s\n' \"\$@\" > /usr/share/offlineimap/version_info" -- \
        VERSION "$VERSION" \
        HASH "$HASH"

pkg_remove "$CONTAINER" \
    .build-deps

pkg_remove "$CONTAINER" \
    .fetch-deps

echo + "rm -rf …/root/.cache/pip" >&2
rm -rf "$MOUNT/root/.cache/pip"

cleanup "$CONTAINER"

cmd buildah config \
    --env OFFLINEIMAP_VERSION="$VERSION" \
    --env OFFLINEIMAP_HASH="$HASH" \
    "$CONTAINER"

cmd buildah config \
    --volume "/etc/offlineimap" \
    --volume "/var/cache/offlineimap" \
    --volume "/var/vmail" \
    "$CONTAINER"

cmd buildah config \
    --workingdir "/var/vmail" \
    --entrypoint '[ "/entrypoint.sh" ]' \
    --cmd '[ "crond" ]' \
    "$CONTAINER"

cmd buildah config \
    --annotation org.opencontainers.image.title="OfflineIMAP" \
    --annotation org.opencontainers.image.description="A container running OfflineIMAP, a open-source IMAP synchronization tool." \
    --annotation org.opencontainers.image.version="$VERSION" \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/offlineimap" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    "$CONTAINER"

con_commit "$CONTAINER" "$IMAGE" "${TAGS[@]}"
