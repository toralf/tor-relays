#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# set -x

set -euf
export LANG=C.utf8
export PATH=/usr/sbin:/usr/bin:/sbin/:/bin

[[ $# -ne 0 ]]

names=$(xargs -n 1 <<<$*)

attempts=8
while ((attempts)); do
  unknowns=$(
    while read -r name; do
      grep -q -m 1 "^${name} " ~/.ssh/known_hosts || echo ${name}
    done <<<${names}
  )
  if [[ -z ${unknowns} ]]; then
    echo -e " OK"
    break
  fi

  echo -en "\n $(wc -w <<<${unknowns}) system/s ..."
  if ssh-keyscan -4 -t ed25519 ${unknowns} >~/.ssh/known_hosts_tmp; then
    grep -v '#' ~/.ssh/known_hosts_tmp >>~/.ssh/known_hosts
    rm ~/.ssh/known_hosts_tmp
  else
    echo -n "  $((--attempts)) attempts left, wait 5s ... "
    sleep 5
  fi
done

if [[ -n ${unknowns} ]]; then
  echo -e "\n NOT ok"
  exit 1
fi
