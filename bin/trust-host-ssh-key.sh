#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

names=$(xargs -r -n 1 <<<$*)
echo -n " trusting $(wc -w <<<${names}) system/s ..."

attempts=7
left=${names}
while ((attempts--)); do
  left=$(
    while read -r name; do
      if ! grep -q -m 1 "^${name} " ~/.ssh/known_hosts; then
        echo ${name}
      fi
    done <<<${left}
  )

  # jump out here if work is done
  if [[ -z ${left} ]]; then
    echo -e "\n OK"
    exit 0
  fi

  echo -en "\n    $(wc -w <<<${left}) left ..."
  ssh-keyscan -q -4 -t ed25519 ${left} | sort | tee -a ~/.ssh/known_hosts >/dev/null
  sleep 8
done

echo -e " NOT ok,  left:     $(xargs <<<${left})\n"
exit 1
