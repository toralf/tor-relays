#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

echo -n " add to ~/.ssh/known_hosts ... "
# shellcheck disable=SC2261
xargs -r -n 1 -P $(nproc) ssh -q -oStrictHostKeyChecking=accept-new -oConnectTimeout=1 -oConnectionAttempts=6 </dev/null 1>/dev/null <<<$*
echo
