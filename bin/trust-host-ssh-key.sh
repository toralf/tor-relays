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

  if [[ -z ${left} ]]; then
    echo -e "\n OK"
    break
  fi

  if ((attempts < 6)); then
    sleep 8
  fi
  echo -en "\n    $(wc -w <<<${left}) left ..."
  ssh-keyscan -q -4 -t ed25519 ${left} | sort | tee -a ~/.ssh/known_hosts >/dev/null
done

if [[ -n ${left} ]]; then
  echo -e " NOT ok,  left:     $(xargs <<<${left})\n"
  exit 1
fi
