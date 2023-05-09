#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

echo " adding entries to ~/.ssh/known_hosts: "
xargs -n 1 <<<$* | xargs -r -P $(nproc) -I {} ssh -oStrictHostKeyChecking=accept-new -oConnectTimeout=1 -oConnectionAttempts=6 {} "uname -a"
echo
