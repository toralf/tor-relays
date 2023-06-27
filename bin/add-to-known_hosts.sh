#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

jobs=$((1 * $(nproc)))

echo " add to ~/.ssh/known_hosts: "
xargs -n 1 <<<$* |
  xargs -r -P ${jobs} -I {} ssh -n -oStrictHostKeyChecking=accept-new -oConnectTimeout=2 -oConnectionAttempts=2 {} "uname -a"
echo
