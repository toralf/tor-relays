#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

# file-locking of ssh doesn't work
jobs=1

echo -e "\n trusting $(wc -w <<<$*) ssh host key/s ..."

while ! xargs -r -P ${jobs} -I '{}' ssh -4 -n -o StrictHostKeyChecking=accept-new -o ConnectTimeout=2 {} ":" 1>/dev/null < <(
  xargs -n 1 <<<$* |
    while read -r name; do
      grep -q -m 1 "^${name} " ~/.ssh/known_hosts || echo ${name}
    done
); do
  echo -en " waiting ..."
  sleep 5
  echo
done

echo -e " Done."
