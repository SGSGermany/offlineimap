#!/bin/sh
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

set -e

if [ $# -eq 0 ] || [ "$1" == "crond" ] || [ "$1" == "offlineimap" ]; then
    # crond
    if [ $# -eq 0 ] || [ "$1" == "crond" ]; then
        exec crond -f -l 7 -L /dev/stdout
    fi

    # run offlineimap unprivileged
    if [ $# -eq 1 ]; then
        set -- offlineimap -c "/etc/offlineimap/offlineimap.conf" -u "basic"
    elif [ $# -eq 2 ] && [ -f "/etc/offlineimap/$2" ]; then
        set -- offlineimap -c "/etc/offlineimap/$2" -u "basic"
    fi

    exec su -p -s /bin/sh offlineimap -c '"$@"' -- '/bin/sh' "$@"
fi

exec "$@"
