#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

jobs=$(nproc)

echo -e "\n trusting $(wc -w <<<$*) ssh host key/s ..."

while ! xargs -r -P ${jobs} -I '{}' ssh -n -o StrictHostKeyChecking=accept-new -o ConnectTimeout=2 {} "uname -a" &>/dev/null < <(
  for i in $*; do
    if ! grep -q -m 1 "^$i " ~/.ssh/known_hosts; then
      echo $i
    fi
  done
); do
  echo -en " NOT yet done ..."
  sleep 5
  echo
done

echo -e " OK"
