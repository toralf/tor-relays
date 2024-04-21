#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

jobs=$((2 * $(nproc)))

echo -e "\n adding to ~/.ssh/known_hosts ..."

for i in $*; do
  if ! grep -q -m 1 "^$i " ~/.ssh/known_hosts; then
    echo $i
  fi
done |
  xargs -r -P ${jobs} -I '{}' ssh -n -oStrictHostKeyChecking=accept-new -oConnectTimeout=2 {} "uname -a"
