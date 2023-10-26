#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

jobs=$((1 * $(nproc)))

for i in $*; do
  grep -q -m 1 "^$i " ~/.ssh/known_hosts || echo ${i}
done |
  xargs -r -P ${jobs} -I '{}' ssh -n -oStrictHostKeyChecking=accept-new -oConnectTimeout=2 {} "uname -a"
