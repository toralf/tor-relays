#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

jobs=$((2 * $(nproc)))

echo -e "\n trust host ssh key ..."

set +e
for i in $*; do
  if ! grep -q -m 1 "^$i " ~/.ssh/known_hosts; then
    echo $i
  fi
done |
  xargs -r -P ${jobs} -I '{}' ssh -n -o StrictHostKeyChecking=accept-new -o ConnectTimeout=2 {} "uname -a"
rc=$?
set -e

if [[ ${rc} -eq 0 ]]; then
  echo -e "\n OK\n"
else
  echo -e "\n NOT ok\n"
  exit ${rc}
fi
