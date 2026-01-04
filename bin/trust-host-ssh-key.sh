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
while ((attempts--)); do
  unknowns=$(
    while read -r name; do
      if ! grep -q -m 1 "^${name} " ~/.ssh/known_hosts; then
        echo ${name}
      fi
    done <<<${names}
  )

  echo -en "\n    $(wc -w <<<${unknowns}) unknown/s left ..."
  if [[ -z ${unknowns} ]]; then
    echo
    break
  else
    ssh-keyscan -q -4 -t ed25519 ${unknowns} | sort | tee -a ~/.ssh/known_hosts >/dev/null
    sleep 8
  fi
done

if [[ -z ${unknowns} ]]; then
  echo " OK"
else
  echo -e " NOT ok,  unknowns:     $(xargs <<<${unknowns})\n"
  exit 1
fi
